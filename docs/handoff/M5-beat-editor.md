# Handoff: M5 — Beat editor

Self-contained brief for an agent implementing milestone M5 of KickVolt.
Part 1 is the prompt to paste. Parts 2–11 are the spec. Verification
against §10 happens afterwards, in a separate session.

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M5 (Beat editor)** of KickVolt, a
> Flutter app in the current repository
> (`https://github.com/Dreymidroid/kickvolt`, branch `main`).
>
> Before writing any code, read these in full:
> 1. `docs/handoff/M5-beat-editor.md` (this brief — it is the spec)
> 2. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 3. `PLAN.md`, especially §3 "one timebase" (non-negotiable), §6 "M5" and
>    "M6" (the click synth you build here is reused by export), §8
>    (decisions) and §9 (what M1–M4 built, known limits)
> 4. `design/kickvolt-design/HANDOFF.md` ("Beat Editor" and "Haptics")
> 5. The code listed in §3 of the brief.
>
> Then:
> - Create a branch `m5/beat-editor` from `main`.
> - Implement §4–§7. Do **not** do anything in §9 (out of scope).
> - The only new package allowed is `shared_preferences` (see §6.1).
> - For `audio_session`, use only the APIs named in §6.3, and confirm each
>   one in your pub cache (`audio_session-0.2.4`) before using it. Do not
>   invent platform APIs. If something you need isn't there, say so in the
>   report instead of working around it natively.
> - Write the pure-Dart tests in §8 **first** (command stack, click synth,
>   preview mix, calibration maths), then make them pass. Then the cubit and
>   widget tests.
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be
>   clean/green. Run `flutter test` at least twice; a test that passes
>   only sometimes is a failure.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report in §11.
>
> If the brief is ambiguous, pick the option that keeps beats as integer
> sample indices, routes the edit through the command stack and keeps the
> click preview sample-accurate; note the decision in your report and carry
> on. Do not edit `android/`, `ios/` or `pigeons/`. Do not loosen a test
> tolerance to make it pass; if a check can't be met, say so in the report.

---

## 2. Context

KickVolt lets a user import a song, mark its beats and export a "beat pack"
(the song plus a click guide track) for CapCut/VN. Done so far (details in
`PLAN.md` §9):

- **M1** import + native decode to `projects/<id>/song.wav` (16-bit PCM,
  native sample rate, 1–2 channels).
- **M2** one `project.json` per project; Home list; editor loads/saves.
- **M3** multi-level peaks, zoom, `just_audio` playback with a smoothed
  playhead.
- **M4** pure-Dart beat detection in an isolate; Auto-detect sheet,
  "no steady beat" sheet, filter as a view.

M5 turns the editor into a real editing tool: an undo/redo command stack
that every edit goes through, the Tap, Bulk and Sections tool panels, tap
marking with latency compensation, a latency calibration screen with a
Bluetooth warning, haptics, and a sample-accurate click preview.

**Core rule:** every beat, section bound, range and offset is an `int`
sample-frame index into `song.wav`, or an `int` ms amount the user typed
that you convert with `project.msToSamples(ms)`. Never store seconds.
Beats, range handles and the playhead clamp to `[0, sampleCount - 1]`.

Environment notes:
- Windows dev machine; no Android device or emulator, and the local Android
  build is broken (corrupt Gradle download). iOS only compiles on
  Codemagic. **Nothing in M5 can be tried on a device**, so the cubit and
  widget tests are the acceptance bar. Make them thorough.
- Material comes from `package:material_ui/material_ui.dart`.
- Theme: `context.kv` (`KvColors`), fonts via `KvText`. Reuse `lib/shared/`
  widgets (`KvPrimaryButton`, `KvSecondaryButton`, `KvChip`, `KvIconButton`,
  `KvSegmented`, `KvIcon`/`KvIcons`) before writing new ones.
- On Windows an open file handle blocks deleting its folder. Anything that
  writes files in an isolate that may be cancelled must close them on every
  path (see §5.4).

Designs (`design/kickvolt-design/png/*.png` = visual truth;
`screens/*.html` = exact copy and sizes): **`EditorSelected`**,
**`EditorTap`**, **`EditorBulk`**, **`EditorPlaying`**,
**`EditorDetected`** (Edit panel summary), **`Coach1`** (Edit-panel hint
copy "Tap a marker to nudge it. Long-press to add one."). Two gaps, which
you fill with existing components in the same style:
- **No Sections panel design.** Build a compact list panel (§7.5).
- **No latency calibration design.** `Settings.png` has a Haptics row but
  no latency row (the Settings screen itself is M8). Build a plain
  full-screen page (§7.6).

## 3. Existing code you'll touch

| Path | What it is today |
|---|---|
| `lib/features/beat_editor/bloc/beat_editor_cubit.dart` (+ `beat_editor_state.dart`) | Editor cubit (~880 lines). Undo/redo are **snapshot stacks of beat lists** in the Freezed state (`undoStack`/`redoStack`, cap 50) with 1-second coalescing of nudges (`_lastNudgeAt`, `DateTime.now()`). All edits call `_commit(s, beats, ...)`. **`commitAutoDetect` and `markDropsOnly` (M4) push only beats, so undo doesn't restore bpm, beatPhaseSample, sections or detection settings** — this is the bug the command stack fixes. Saves: `_scheduleSave` (debounced by `saveDebounce`) → `_flushPendingSave` → serialized through `_saveQueue`; `close()` flushes, guarded by `_closing`. Haptics are direct `HapticFeedback.*` calls (delete uses `heavyImpact`, detect uses `mediumImpact` — both wrong per HANDOFF). `addBeatAtPlayhead` snaps to the grid when `snap` and `bpm` are set and refuses a beat within 20 ms of another. |
| same | `playhead` and `zoom` are `ValueListenable`s on the cubit, driven by `PlayheadController`. Painters repaint from them. **Don't move them into the Freezed state.** |
| same | `EditorTool { auto, tap, edit, sections, bulk }`; `EditorSheet { none, autoDetect, detectFailed }`. Only `edit` has a panel; `auto` opens the sheet. `selectedIndex` is an index into `project.beats`. `snap`, `clicks`, `speed`, `playing` are in state; `clicks` toggles a flag that does nothing yet. |
| `lib/features/beat_editor/presentation/pages/beat_editor_screen.dart` | `_contextPanel()` per tool; add Tap, Bulk, Sections panels and the playing panel. |
| `lib/features/beat_editor/presentation/widgets/` | `beat_timeline.dart` (gestures: tap-up selects via `TimelinePainter.beatAt`; `BeatInfoCard` with "snapped/off grid"; `OverviewStrip`), `timeline_painter.dart` (markers per type incl. downbeat pill, sections, playhead), `beat_inspector_panel.dart` (nudge/type/delete), `edit_panel.dart`, `editor_controls.dart` (chips + transport), `editor_top_bar.dart` (undo/redo buttons), `auto_detect_sheet.dart`, `detect_failed_sheet.dart`. |
| `lib/features/beat_detection/domain/beat_filter_view.dart` | `visibleBeatIndices(project)` — the filter view. Painter, hit testing, counts, **click preview** and (M6) export use visible beats. |
| `lib/features/projects/domain/entities/` | `Project` (`sampleRate`, `channels`, `sampleCount`, `beats`, `sections`, `bpm`, `beatPhaseSample`, `detection`, `msToSamples`, `isOnGrid`, `sectionAt`), `Beat(sample, type)`, `Section(startSample, endSample, name, colorArgb)` + `sectionPresets`. |
| `lib/features/playback/` | `AudioPlayback` interface (`open(path)`, `play`, `pause`, `seek(Duration)`, `setSpeed`, `snapshots`, `dispose`), `JustAudioPlayback` (configures `AudioSession` as music), `PlayheadController` (`sample` notifier, `seek`, `scrub`, injectable `nowUs`), `PlayheadClock` (`positionUsAt(wallUs)`). |
| `lib/core/audio_math/` | `wav_header.dart` (`readWavInfo`, `buildWavHeader`), `peaks.dart` (streaming a WAV in chunks inside an isolate — follow its bounded-memory pattern), `pcm_window_loader.dart`. |
| `lib/core/storage/project_paths.dart` | Per-project file names (`songWav`, `peaksBin`, `analysisFile`, …). |
| `lib/core/di/locator.dart` | GetIt registrations. |
| `test/fixtures/demo_project.dart`, `test/fixtures/synthetic_audio.dart`, `test/features/playback/fake_audio_playback.dart` | `FakeDemoProjectRepository`, synthetic WAV writers, `FakeAudioPlayback`. |
| `test/features/beat_editor/bloc/*_test.dart` | Cubit tests. Several wait on **real time** (`Future.delayed`) for the save debounce; see §8. There are **no widget tests** yet. |

## 4. Command stack (all edits go through it)

### 4.1 Shape

Pure Dart in `lib/features/beat_editor/domain/` (no Flutter imports).
Commands act on the editable part of a project, not on beats alone:
`beats`, `sections`, `bpm`, `beatPhaseSample`, `detection`. Each command
is a value that can **apply** to a project and **revert** from the result,
restoring that state exactly. Suggested interface (adapt names, keep the
behaviour):

```dart
abstract class EditCommand {
  Project apply(Project p);
  Project revert(Project p);
  /// Marker index to select after apply / after revert, or null.
  int? selectAfterApply(Project result);
  int? selectAfterRevert(Project result);
  /// Merge [next] into this command (nudge coalescing); null if it can't.
  EditCommand? mergeWith(EditCommand next);
}
```

`CommandStack` (pure): `execute(cmd, {required DateTime at})`, `undo()`,
`redo()`, `canUndo`, `canRedo`, capped at **100** entries (oldest
dropped), a new command clears redo. The clock is passed in (or
injected), never `DateTime.now()` inside the stack, so coalescing is
testable without waiting.

Commands (each must keep beats **sorted, unique by sample, within
`[0, sampleCount - 1]`**):

| Command | Does | Undo restores |
|---|---|---|
| `AddBeats` | Inserts one or more beats (add at playhead, long-press, a run of taps) | removes exactly those |
| `DeleteBeat` | Removes one beat | the beat, its type and its index |
| `MoveBeat` | Nudge; same beat, consecutive nudges within **1 s** merge into one | original sample |
| `SetBeatType` | Changes type | old type |
| `ShiftAll` | Moves every beat **and `beatPhaseSample`** by Δ frames; Δ is clamped so no beat leaves the range | exact old samples and phase |
| `ClearRange` | Removes every beat (hidden ones included) with `start ≤ sample ≤ end` | the removed beats with their types |
| `SnapRange` | Moves beats in a range to the nearest grid line (`bpm` + `beatPhaseSample`); if two land on the same line keep the higher-precedence type (drop > downbeat > strong > beat) | the old beats |
| `SetSections` | Replaces the section list | old list |
| `ReplaceAll` | Auto-detect commit and "Mark drops only": replaces beats, sections, bpm, beatPhaseSample and detection settings/status together | **all five fields** |

Undo of a nudge, type change or delete selects the affected marker again;
undo of anything else clears the selection.

### 4.2 Cubit integration

- Remove `undoStack`/`redoStack` from the Freezed state; keep the stack on
  the cubit and expose `canUndo`/`canRedo` booleans in state (top bar
  buttons enable/disable from them).
- Replace `_commit` with one `_execute(EditCommand)` path that applies,
  emits, schedules the save, and triggers a click-preview re-render
  (§5.3). `undo()`/`redo()` go through the same emit/save/re-render path.
- **Every** edit in the editor goes through `_execute`, including the
  existing nudge/type/delete/add, `commitAutoDetect`, `markDropsOnly`, and
  the new tap/bulk/section edits. Previews (Auto sheet slider, dragging
  range handles) are not edits and don't touch the stack.
- Keep the save machinery (debounce, `_saveQueue`, flush in `close()`
  guarded by `_closing`) as it is.
- The stack lives for the editor session only; it isn't persisted.

## 5. Click synth and preview mix

### 5.1 Click synth (shared with M6)

Pure Dart in `lib/core/audio_math/click_synth.dart`, so M6 export reuses it
unchanged. Spec from `PLAN.md` §6 M6:

- `enum ClickStyle { snap, rim, blip, kick }` (decision §8.4). Each is a
  **5–10 ms** exponentially decaying burst, rendered at the song's sample
  rate. Suggested voices: Snap = filtered noise burst; Rim = short noise +
  ~1.8 kHz tone; Blip = ~2 kHz sine; Kick = ~60→40 Hz pitch-dropping sine
  (Kick may use the full 10 ms). Noise uses a **fixed seed**: the same
  input always renders the same samples.
- Peak level **−3 dBFS** (`0.7079` of full scale), ±0.1 dB.
- **The attack is at the beat sample:** the first non-zero sample of a
  click is exactly the beat's sample index. No pre-roll, no fade-in that
  rounds to zero on the first sample.
- Overlapping clicks are summed, then clipped to int16.
- A click that starts near the end is truncated at `sampleCount`.

Expose something like `Float64List renderClick(ClickStyle, int sampleRate)`
plus a function that adds clicks for a sorted list of beat samples into a
chunk buffer `[chunkStart, chunkStart + length)` so the mixer and the M6
guide-track writer can both stream.

### 5.2 Preview mix

`PLAN.md` M5 chose a **pre-rendered preview mix**, and so does this brief:
render `song + clicks` into one WAV and play that file instead of
`song.wav`. The clicks sit at exact sample indices in the same buffer as
the music, so they are sample-accurate by construction at any speed and
whatever the device's output latency. A second player scheduling clicks
can't guarantee sample sync between two streams and drifts under
`setSpeed`. Explain this choice in a doc comment on the renderer.

- Pure-Dart streaming renderer in `lib/core/audio_math/` (e.g.
  `preview_mix.dart`): reads `song.wav` in chunks of ≤ 1 MB, adds clicks
  for the **visible** beats (`visibleBeatIndices`) in `ClickStyle.snap`
  (the default style; the setting is M8), writes a 16-bit WAV with the
  **same sample rate, channel count and frame count** as `song.wav`. Same
  click on every channel.
- Mix: `out = clip(round(song * songGain) + click)` with a fixed
  `songGain` you choose and document (some headroom so clicks stay
  audible on loud masters). Fixed, so tests can subtract the song and
  find the clicks exactly.
- Bounded memory: never hold the whole song; report the peak buffer size.

### 5.3 Running it

- `ClickPreviewRepository` (abstract + impl, in a new
  `lib/features/click_preview/` feature with its own barrel) with e.g.
  `Future<String> render(Project project, {required ClickStyle style,
  required CancelToken cancel})` → path of the finished file.
- Runs in an isolate (`Isolate.spawn` + `SendPort`, like M4's analysis
  runner) with cooperative cancel.
- **File names:** a new file per render (`preview-<n>.wav` via a new
  `ProjectPaths.previewWav(id, n)`), written as `…part` and renamed when
  complete. The player may still hold the previous file open (Windows
  can't replace or delete an open file), so delete the previous one only
  after the player has switched away from it. Delete stray `preview-*`
  files on editor load and in `close()`.
- **Cubit flow:**
  - Clicks chip **on** → render; show a small "Updating clicks…"
    indicator while rendering; when done, swap the player source to the
    preview file **at the current playhead position**, keeping
    playing/paused state and speed. "Clicks on" pill on the waveform as in
    `EditorPlaying.png`.
  - Clicks **off** → swap back to `song.wav` at the current position.
  - Any edit, undo/redo, or filter change while Clicks is on → cancel the
    in-flight render and re-render after a **300 ms** debounce; swap when
    done. The old preview keeps playing meanwhile.
  - Render failure → SnackBar, Clicks turns off, playback continues on
    `song.wav`.
- **Swapping at a position:** extend `AudioPlayback.open` with an initial
  position (e.g. `open(path, {Duration initialPosition = Duration.zero})`,
  implemented with `AudioPlayer.setFilePath(path, initialPosition: …)`,
  which exists in just_audio 0.10.6), re-apply speed, resume if it was
  playing, and re-anchor `PlayheadController` so the playhead doesn't jump.
  Update `FakeAudioPlayback` to record the path and initial position.

### 5.4 Cancellation and files (Windows)

The renderer must close both files on every path (success, error,
cancel). Cancel is cooperative: the worker checks a cancel message between
chunks, closes files in `finally`, deletes its `.part` file and exits. Only
hard-kill the isolate after a grace period (M4 uses 2 s), and tolerate a
leftover `.part` (cleaned on next load). Test: cancel mid-render, then the
project folder can be deleted immediately.

## 6. Settings, haptics, output route

### 6.1 Settings store

Add `shared_preferences: ^2.5.6` (planned in `PLAN.md` §2; confirm the
version in your pub cache). In a new `lib/features/settings/` feature:
`AppSettings` (Freezed) with at least

- `latencyOffsetMs` (`int`, default from §6.3, clamped to −100…+500),
- `latencyCalibratedOn` (`enum OutputKind { unknown, builtIn, wired,
  bluetooth }`, default `unknown` = not calibrated),
- `hapticsEnabled` (`bool`, default `true`),

and `SettingsRepository` (abstract + impl over `SharedPreferences`, keys
`UPPER_SNAKE_CASE`), registered in the locator. Store ms, not frames
(sample rates differ per song); convert per project. The Settings
**screen** is M8; nothing here adds it.

### 6.2 Haptics

`Haptics` service in `lib/core/haptics/` (interface + impl, injectable so
tests use a recording fake), reading `hapticsEnabled` (when off, nothing
fires). Map per `HANDOFF.md`, using what Flutter's `HapticFeedback`
actually has (confirm in the SDK; this Flutter has `selectionClick`,
`lightImpact`, `heavyImpact`, `successNotification`,
`warningNotification`):

| Event | Call |
|---|---|
| A marker is placed (add, long-press, each tap), snapped, or nudged | `selectionClick` |
| A strong beat (strong or downbeat) passes the playhead — only while playing **and** Clicks is on | `lightImpact` |
| A drop passes the playhead while playing | `heavyImpact` |
| Detection committed (and, in M6, export finished) | `successNotification` |
| Delete or clear range | `warningNotification` |

Replace every direct `HapticFeedback` call in the editor. Pass-the-
playhead detection is a pure function (visible beats crossed between the
previous and current playhead sample while moving forward; a jump of more
than 250 ms counts as a seek and fires nothing) so it's unit-testable.

### 6.3 Output route and latency (audio_session 0.2.4 — checked)

What `audio_session` 0.2.4 offers (confirm before use):

- `(await AudioSession.instance).getDevices(includeInputs: false)` →
  `Set<AudioDevice>` (`type: AudioDeviceType`, `isOutput`, `name`), and
  `devicesStream` for changes. Bluetooth types: `bluetoothA2dp`,
  `bluetoothLe`, `bluetoothSco`, `hearingAid`.
  - **iOS:** the outputs of the *current route* — accurate.
  - **Android:** *all connected* output devices, not the active route,
    so "a Bluetooth output is connected" is the best signal (word the UI
    that way). Android BLE-audio device types aren't mapped in 0.2.4 and
    arrive as `unknown`; note this limit.
- **iOS only:** `AVAudioSession().outputLatency` (`Future<Duration>`,
  from `package:audio_session/audio_session.dart`). **Android has no
  output-latency getter** in this package.

Wrap these in an `OutputRouteService` (interface + impl + fake) exposing
the current `OutputKind`, a stream of changes, and `Future<Duration?>
reportedOutputLatency()` (null on Android). Nothing else; no native code.

Default `latencyOffsetMs` before any calibration: the iOS reported output
latency rounded to ms if available, else 0. Once calibrated, the
calibrated value replaces it; **don't add the platform latency on top** —
calibration measures the whole chain (§7.6).

## 7. Editor UI

### 7.1 Edit tab (`EditorSelected`, `EditorDetected`, `Coach1`)

- Existing marker styles, info card and inspector stay; check them
  against `EditorSelected.png` and fix differences you find.
- Nudge −10/−1/+1/+10 ms, type Beat/Strong/Drop, Delete — all via
  commands. Nudge keeps clamping between the neighbours.
- **Long-press on the waveform adds a beat** at that position (snapped if
  Snap is on; refused within 20 ms of another beat, like
  `addBeatAtPlayhead`) and selects it. Edit-panel hint copy from
  `Coach1.html`.
- While playing, the Edit panel shows the playing panel from
  `EditorPlaying.png`: "BEAT n / N" (n = last visible beat at or before
  the playhead, N = visible count), four bar dots for the position in the
  bar (counted from the first downbeat, else beat 0), and the hint copy.
  The beat number repaints from the `playhead` listenable, not from
  state emissions.

### 7.2 Snap

Snap on (only possible with a BPM) snaps every *placement*: add at
playhead, long-press, tap-pad beats, and dragging range handles. Nudges are
never snapped (they're fine adjustments). `SnapRange` is offered in the
Bulk panel (§7.4).

### 7.3 Tap tab (`EditorTap`)

- Big tap pad: "Tap on every beat", a `+N` counter of beats added in the
  current run, "playing at .75×", "lag fix 40 ms" (the current offset).
  Tapping "lag fix" opens the calibration screen (§7.6).
- A tap while playing adds a beat at
  **`sampleNow − msToSamples(latencyOffsetMs)`**, clamped, snapped if Snap
  is on, skipped if within 20 ms of an existing beat; `selectionClick`
  each time.
- Read the position **at the moment of the pointer-down**, not the last
  painted frame: add `PlayheadController.sampleNow()` using
  `PlayheadClock.positionUsAt(nowUs())`, and handle the tap on
  pointer-down (`Listener.onPointerDown` / `onTapDown`), never `onTap`
  (fires on release). The calibration screen must use the **same** path,
  so any constant delay in it cancels out.
- While paused, the pad shows "Press play, then tap along" and ignores
  taps.
- All taps from play to pause form **one** `AddBeats` command (one undo
  removes the run). Commit it on pause, on leaving the Tap tab and in
  `close()`; show the tapped beats on the waveform as they land.
- Warning row under the pad when the output is Bluetooth and the offset
  wasn't calibrated on Bluetooth (or vice versa): "Bluetooth adds
  150–300 ms of delay. Calibrate with these headphones." with a button to
  the calibration screen.

### 7.4 Bulk tab (`EditorBulk`)

- **Range:** two red handles on the waveform, draggable (snapped if Snap
  is on), hatched red fill between them, clamped to the song and to
  `start ≤ end`. Default range when the tab opens: the middle half of the
  visible viewport. The handles and drag preview live in cubit state, not
  in the stack.
- Card: "Range · N beats" (all beats in the range) and `m:ss.mmm –
  m:ss.mmm`; **Clear range** (`ClearRange`, `warningNotification`); a
  secondary "Snap to grid" (`SnapRange`, only with a BPM).
- **Shift all beats:** − / value / + in 1 ms steps with long-press repeat
  (and ±10 ms per step after holding; your call), range ±500 ms, **Apply**
  → `ShiftAll`. The value resets to 0 after Apply.
- Footer: "Drag the red handles to change the range."

### 7.5 Sections tab (no design; build compact)

List of sections (colour dot, name, `m:ss – m:ss`), tapping one seeks to
its start. Actions, all through `SetSections`:
- **Split at playhead:** splits the section containing the playhead; the
  new boundary snaps to the nearest beat. If the project has no sections,
  first create one covering the whole song named "Song".
- **Rename** (text dialog) and **recolour** (pick from `sectionPresets`
  colours).
- **Delete:** merges into the previous section (into the next if it's the
  first). Deleting the last remaining section clears the list.

Invariants after every edit (tested): sorted, non-overlapping,
contiguous, covering `[0, sampleCount)`, or empty.

### 7.6 Latency calibration screen

New route `LatencyCalibrationRoute` in `lib/features/settings/` (cubit +
screen), reached from the Tap panel's "lag fix" and the Bluetooth warning.
M8 will also link it from Settings.

- Renders a 30 s click track at 100 BPM with the click synth to the app's
  temp directory and plays it through its own `AudioPlayback` +
  `PlayheadController`.
- The user taps along on a pad (same pointer-down + `sampleNow()` path as
  §7.3). Each tap's offset = tap sample − nearest click sample (only taps
  within half a period of a click count).
- After **≥ 16** valid taps: drop outliers (document the rule, e.g. more
  than 3 × MAD from the median), result = median of the rest, shown as
  "Your lag fix: 42 ms", with **Save** and **Try again**. Fewer than 12
  taps left after outlier removal → "Taps were too uneven, try again".
- Save stores `latencyOffsetMs` and `latencyCalibratedOn` = current
  `OutputKind`.
- Show the current output ("Phone speaker", "Wired headphones",
  "Bluetooth headphones connected") and the Bluetooth warning when
  applicable. On iOS also show "Device-reported delay: N ms" for
  reference.
- Copy: "Calibrate with the headphones you'll edit with."
- The calibration maths (matching, outliers, median, minimum count) is a
  pure function with unit tests.

## 8. Tests required

Deterministic only: **no real-time waits** (`Future.delayed`, sleeps)
for debounces or timers. Use `fakeAsync`, `tester.pump(duration)`, an
injected clock, or `close()` to flush saves. M2–M4 timing tests flaked
under full-suite load. While you're in `test/features/beat_editor/`,
convert the existing real-time waits there too.

Generated audio fades every note out (no hard cuts; a cut is a real
click that turns up as a false hit). Write WAVs to temp directories
through the real file path where the code reads files.

| Test | Must cover |
|---|---|
| `command_stack_test.dart` | Each command: apply then revert gives back an **equal** `Project` (beats, sections, bpm, phase, detection). Random sequences of ≥ 200 commands on a seeded RNG: undo all → original; redo all → final; invariants (sorted, unique, in range) after every step. Cap at 100. New command clears redo. Nudges within 1 s merge, at 1 s+ or after another command don't (injected clock). `ReplaceAll` undo restores bpm, phase, sections and detection. `ShiftAll` clamps at both ends and moves the phase. `SnapRange` merge precedence. |
| `click_synth_test.dart` | All four styles at 44.1 and 48 kHz: first non-zero sample == beat sample; non-zero length 5–10 ms; peak −3 dBFS ±0.1 dB; same output twice; two overlapping clicks are summed and clipped; click at `sampleCount - 1` truncates without error. |
| `preview_mix_test.dart` | Synthetic song (faded notes) at 44.1 kHz stereo and 48 kHz mono: output frame count, rate and channels == `song.wav` (read back from the files); for every visible beat, the first sample where `preview − round(song × songGain)` ≠ 0 is **exactly** the beat sample; beats hidden by the filter produce no click; chunked reading (peak buffer ≤ 4 MB). Cancel mid-render → no `.part` left once the future settles and the project folder deletes immediately. |
| `calibration_test.dart` | Taps at a known offset with jitter → median within 1 ms of the offset; outliers dropped; taps beyond half a period ignored; < 16 taps → not ready; too uneven → failure result. |
| `playhead_pass_test.dart` | Crossing detection: forward play fires once per crossed visible beat by type; seek/jump > 250 ms fires nothing; backwards fires nothing; Clicks off → no `lightImpact` but drops still fire. |
| `settings_repository_test.dart` | Defaults; round trip; clamping (`SharedPreferences.setMockInitialValues`). |
| Cubit tests (update + new) | All edits go through the stack (undo/redo for every action incl. Auto-detect commit and Mark drops only restoring bpm/phase/sections/status); tap run: beat at `sampleNow − offset` (fake clock + fake playback), snap, duplicate skip, one undo removes the run; Bulk clear/shift/snap; sections split/rename/recolour/delete + invariants; haptics fake records the right event per action and nothing when disabled. |
| Click preview cubit tests | Clicks on → one render, then the player opens the preview file at the current position with speed and playing state kept; an edit → one re-render after 300 ms (`fakeAsync`), in-flight render cancelled; Clicks off → back to `song.wav` at the same position; render failure → SnackBar message, Clicks off. Use a fake `ClickPreviewRepository`. |
| **Widget tests** (`test/features/beat_editor/presentation/`) | Pump the real `BeatEditorScreen` with `FakeDemoProjectRepository`, `FakeAudioPlayback` and fakes for preview/settings/haptics/route. (1) tap a marker → info card → nudge +10 → undo → redo, checking the marker sample each step; (2) delete + undo restores the same beat and type; (3) Tap tab: play, tap the pad 4 times, pause → 4 beats added at the expected samples, one undo removes all 4; (4) Bulk: Clear range + undo; Shift all −20 ms Apply + undo; (5) long-press adds a beat; (6) Sections: split + rename + undo; (7) undo/redo buttons enable/disable correctly. |

## 9. Out of scope (do not build)

- Export, guide-track files, share (M6) — only the click synth is shared.
- Guide video (M7).
- Settings screen, onboarding, coach-mark overlays (Coach1–3 overlays are
  M8; you only use Coach1's panel copy), paywall, click-style setting,
  mono guide setting (M8).
- Re-tuning detection or changing M4's analysis.
- Any native or Pigeon change; any package other than
  `shared_preferences`.
- Persisting the undo history across sessions.

## 10. Acceptance checklist (used for verification)

Commands (must pass on the pushed branch):

```powershell
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Behaviour:

- [ ] All §8 tests exist and pass on two consecutive full runs; no
      real-time waits in `test/features/beat_editor/`.
- [ ] Undo/redo is a command stack in pure Dart; snapshot stacks are gone
      from the state; **every** edit goes through it; Auto-detect commit
      and Mark drops only undo bpm, phase, sections and status too.
- [ ] Beats stay sorted, unique, integer and within `[0, sampleCount - 1]`
      after every command.
- [ ] Click synth in `lib/core/audio_math/`, pure Dart: attack exactly at
      the beat sample, −3 dBFS, 5–10 ms, summed and clipped.
- [ ] Preview mix: same rate/channels/frame count as `song.wav`; clicks at
      exact sample indices (read back from the file); visible beats only;
      chunked; rendered in an isolate with cooperative cancel; files
      closed on every path; old previews deleted after the swap.
- [ ] Swapping the player source keeps position, speed and play state.
- [ ] Tap marking uses `sampleNow()` on pointer-down minus the offset;
      calibration uses the same path; one undo per tap run.
- [ ] Calibration screen works with ≥ 16 taps, outlier rule documented;
      Bluetooth warning driven by `OutputRouteService`; only the
      `audio_session` APIs in §6.3 are used.
- [ ] Haptics via one service, mapped as in §6.2, global switch honoured.
- [ ] Tap, Bulk, Sections panels and playing panel match their designs
      (Sections and calibration: consistent with the design system).
- [ ] Playhead and zoom remain `ValueListenable`s; no 60 fps state
      emissions.
- [ ] Only `shared_preferences` added; nothing under `android/`, `ios/`,
      `pigeons/` changed.
- [ ] Every new file exported from its barrel; no layer bypasses (UI never
      touches files, isolates, repositories or `audio_session` directly).
- [ ] Branch `m5/beat-editor` pushed; not merged; no PR.

## 11. Report to hand back

End your session with:

1. Branch name and `git log --oneline main..HEAD`.
2. Tails of `flutter analyze` and both `flutter test` runs (pass counts).
3. The preview-mix check: for each test case, rate, channels, frame count
   of `song.wav` vs preview, number of clicks checked, worst position
   error in samples (should be 0); render time for a 3-minute 44.1 kHz
   stereo song and peak buffer size, and how you measured them.
4. The `audio_session` and `HapticFeedback` APIs you used, with the file
   and line in the pub cache / SDK where you confirmed each.
5. File-level summary: new, changed, deleted.
6. Decisions where this brief was ambiguous (`songGain`, outlier rule,
   default Bulk range, layout of the Sections and calibration screens,
   anything else), and why.
7. Anything in §10 you could not complete or verify, stated plainly. Say
   explicitly that nothing was run on a device.
8. Anything noticed for later milestones.
