# Handoff: M4 — Beat detection

Self-contained brief for an agent implementing milestone M4 of KickVolt.
Part 1 is the prompt to paste. Parts 2–10 are the spec. Verification
against §9 happens afterwards, in a separate session.

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M4 (Beat detection)** of KickVolt, a
> Flutter app in the current repository
> (`https://github.com/Dreymidroid/kickvolt`, branch `main`).
>
> Before writing any code, read these in full:
> 1. `docs/handoff/M4-beat-detection.md` (this brief — it is the spec)
> 2. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 3. `PLAN.md`, especially §3 "one timebase" (non-negotiable) and §9
>    (what M1–M3 built)
> 4. The code listed in §3 of the brief.
>
> Then:
> - Create a branch `m4/beat-detection` from `main`.
> - Implement §4–§7. Do **not** do anything in §8 (out of scope).
> - The only new package allowed is `fftea` (see §4.2). Check its API in
>   your pub cache before using it; do not guess method names.
> - Write the tests in §7 **first** for the pure detection code (the
>   synthetic-audio tests are the real acceptance bar), then make them pass.
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be
>   clean/green.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report in §10.
>
> If the brief is ambiguous, pick the option that keeps beats as integer
> sample indices and keeps detection off the UI isolate, note the decision
> in your report, and carry on. Do not edit `android/`, `ios/` or `pigeons/`.
> Do not tune the synthetic tests' tolerances to make them pass; if a
> tolerance can't be met, say so in the report.

---

## 2. Context

KickVolt lets a user import a song, mark its beats and export a "beat pack"
for CapCut/VN. Done so far:

- **M1** import + native decode to `projects/<id>/song.wav` (16-bit PCM,
  native sample rate, 1–2 channels).
- **M2** projects persisted as JSON; Home list; editor loads/saves real
  projects.
- **M3** waveform peaks, zoom, just_audio playback with a smoothed playhead.

M4 adds automatic beat detection: tempo, beats, strong beats, drops,
downbeats and rough sections, all in pure Dart in a background isolate,
plus the UI that runs it (Analyzing screen at import, the Auto-detect sheet,
the "no steady beat" sheet).

**Core rule:** every beat is an `int` sample-frame index into `song.wav`.
Detection works on hop frames internally, but its output is sample indices,
refined to the actual attack (see §4.4). Never store seconds.

Environment notes:
- Windows dev machine; pure-Dart tests run here. No device needed for M4.
- Material comes from `package:material_ui/material_ui.dart`.
- Theme: `context.kv` (`KvColors`), fonts via `KvText`. Reuse `lib/shared/`
  widgets (`KvPrimaryButton`, `KvSecondaryButton`, `KvChip`, `KvIconButton`,
  `KvSegmented`, `KvIcon`/`KvIcons`).
- Copy says "beats", "drops", "sections"; never "onsets"/"transients".

Designs (`design/kickvolt-design/png/*.png` = visual truth;
`screens/*.html` = exact copy and sizes): **`Analyzing`**,
**`EditorAutoDetect`**, **`EditorDetected`**, **`EditorDetectFailed`**.

## 3. Existing code you'll touch

| Path | What it is today |
|---|---|
| `lib/features/projects/domain/entities/` | `Project` (sampleRate, channels, sampleCount, `beats: List<Beat>`, `sections`, `bpm: double?`, `beatPhaseSample: int?`, `detection: DetectionSettings`), `Beat(sample, type: beat/strong/drop/downbeat)`, `Section(startSample, endSample, name, colorArgb)` + `sectionPresets`, `DetectionSettings(sensitivity = 0.5, filter: BeatFilter.every)` with `enum BeatFilter { every, strong, drops, every2nd, every4th }`. |
| `lib/features/projects/data/repositories/project_repository.dart` | `ProjectRepository`: `createFromImport`, `getProject`, `saveProject`, `getPeaks`, `songPath(id)`, etc. Writes are atomic and serialized. `ProjectPaths` (`lib/core/storage/project_paths.dart`) has the per-project file names. |
| `lib/core/audio_math/wav_header.dart` | `readWavInfo(File)` → `WavInfo` (`sampleRate`, `channels`, `dataOffset`, `frameCount`, `bytesPerFrame`). `buildWavHeader(...)`. |
| `lib/core/audio_math/peaks.dart` | Reference for streaming a WAV in chunks inside `Isolate.run` (`computePeaks`). Follow the same bounded-memory pattern. |
| `lib/features/import/bloc/import_cubit.dart` | Analyzing flow: `ImportRepository.importSong` (decode, progress 0–0.9), then `ProjectRepository.createFromImport` (0.9–1.0), then `done` → editor. Cancel via `ImportCancelToken`. |
| `lib/features/import/presentation/pages/analyzing_screen.dart` | Progress ring + 4 steps; only "Reading the audio" is live (the rest are static `pending`). |
| `lib/features/beat_editor/bloc/beat_editor_cubit.dart` | Editor cubit. Beats live in `state.project.beats`; edits go through `_commit` (undo/redo stacks of beat lists, debounced save). Playhead/zoom are `ValueListenable`s on the cubit (`playhead`, `zoom`). `EditorTool { auto, tap, edit, sections, bulk }`. |
| `lib/features/beat_editor/presentation/widgets/edit_panel.dart` | Empty/summary panel. "Auto-detect beats" currently shows a SnackBar ("Beat detection arrives in the next update") — replace it. Also has "Re-detect". |
| `lib/features/beat_editor/presentation/pages/beat_editor_screen.dart` | `_contextPanel()` per tool; only `edit` has a panel. |
| `lib/features/beat_editor/presentation/widgets/timeline_painter.dart` | Draws `project.beats` by type; `beatAt(...)` hit test. |
| `test/fixtures/demo_project.dart` | `createDemoProject`, `createDemoPeaks`, `FakeDemoProjectRepository`. |

## 4. Detection engine (pure Dart)

Put the algorithm in `lib/features/beat_detection/domain/` as pure Dart (no
Flutter imports) so it runs in an isolate and in plain tests. Split it in
two:

1. **Analysis (heavy, once per song):** audio → `BeatAnalysis` (candidate
   beats with per-beat features, tempo, confidence, per-frame low-band
   energy summary). Runs in an isolate. Cached to disk (§5.2).
2. **Classification (cheap, many times):** `BeatAnalysis` + `sensitivity`
   → `DetectionResult` (beats with types, bpm, phase, sections, or a
   failure). Pure function, fast enough (< 5 ms for 2,000 beats) to run on
   every slider move in the Auto-detect sheet.

The filter (§4.7) is a third, separate view applied to the classified
beats; it never changes stored data.

### 4.1 Input

Stream `song.wav` from `WavInfo.dataOffset` in chunks of ≤ 1 MB. Mono
mixdown = average of channels, scaled to −1..1 floats **per chunk**. Never
hold the whole song's PCM; only per-hop-frame features (a few floats per
~11 ms) are kept for the whole song.

### 4.2 Onset strength envelope

- STFT with `fftea` (`fftea: ^1.5.0`, pure Dart, both platforms; it was
  chosen in PLAN.md §2 — confirm the API in your pub cache): window 2048,
  hop 512, Hann.
- **Centered frames:** frame `t` is centered on sample `t * hop` (pad
  1024 zeros before the start). An uncentered window shifts every beat by
  ~23 ms and fails the tests. Document the convention in code.
- Log magnitude `log(1 + 1000 * |X|)` per bin; spectral flux = sum over bins
  of the positive difference from the previous frame; then subtract a
  moving average (~0.5 s) and half-wave rectify; normalise by the
  standard deviation. This is the **onset envelope** `O[t]`.
- Also keep, per frame, the **low-band energy** `L[t]` (sum of `|X|²` for
  bins below 150 Hz) for drops, downbeats and sections.

### 4.3 Tempo

- Autocorrelation of `O` over lags for 40–220 BPM.
- Weight by a log-normal prior on BPM centred on 120 with σ = 1 octave
  (`w = exp(-0.5 * (log2(bpm / 120))²)`).
- Half/double ambiguity: for the best lag `T`, also score `2T`, `T/2`,
  `3T/2` and `2T/3` (where in range) and pick the highest weighted score.
- Parabolic interpolation around the chosen lag peak for sub-frame period.
- **Confidence** = weighted peak height / mean weighted autocorrelation
  over the range (or a similar normalised measure; document it). It drives
  the "no steady beat" failure (§4.6).

### 4.4 Beat tracking and placement

- Dynamic-programming tracker (Ellis 2007): with period `P` frames,
  `C[t] = O[t] + max over τ in [t − 2P, t − P/2] of (C[τ] − α·(log((t − τ)/P))²)`,
  α = 100 (tightness). Backtrack from the best-scoring frame in the last
  period.
- Snap each tracked beat to the strongest `O` peak within ±P/8 frames.
- **Refine to the sample.** A 512 hop is 11.6 ms at 44.1 kHz, which alone
  can't meet the ±10 ms bar. For each beat, read a short window of raw
  mono PCM around the frame (e.g. ±hop samples, from the file with
  `RandomAccessFile`, not memory) and find the attack: compute a
  high-resolution energy envelope (e.g. 64-sample hop, frame energy of a
  first-difference/high-passed signal) and place the beat at the first
  sample where energy rises above the midpoint between the local floor and
  peak. Convention: **a beat's sample is where its attack starts.**
- **Final BPM** comes from the refined beats, not the autocorrelation lag:
  median inter-beat interval over the longest run of steady beats, or a
  least-squares fit of beat sample vs. index. Report to 0.1 BPM.
- `beatPhaseSample` = the first refined beat's sample modulo the grid
  period (so snap-to-grid in the editor lines up).

Each candidate beat carries: `sample`, `strength` (O at the beat,
normalised 0–1 over the song), `lowEnergy` (L averaged over the beat's
period), and its index.

### 4.5 Classification (types)

Precedence when a beat qualifies for several: **drop > downbeat > strong >
beat**. (The editor already counts "strong" as any non-`beat` type.)

- **Strong:** `strength` ≥ the song's `p`-th percentile of beat strengths,
  `p = 85 − 40 * sensitivity` (top 15 % at 0, top 55 % at 1).
- **Downbeats (heuristic — say so in a code comment):** for each phase
  φ ∈ {0,1,2,3}, sum `strength + lowEnergy` (both normalised) of beats with
  `index % 4 == φ`; the best φ's beats are downbeats.
- **Drops (heuristic — say so):** a downbeat is a drop when the mean
  low-band energy over the next 2 bars is ≥ 2× (+6 dB) the mean over the
  previous 4 bars **and** above the song's median low-band energy. Keep at
  least 8 bars between drops; keep only the strongest in any 8-bar window.
- **Sensitivity also prunes:** with `sensitivity < 0.5`, beats in quiet
  stretches (strength below the `q`-th percentile, `q = 40 * (0.5 −
  sensitivity)`, i.e. up to the bottom 20 % at 0) are removed. At ≥ 0.5
  nothing is pruned. Higher sensitivity must never yield fewer beats or
  fewer strong beats (tested).

### 4.6 Failure: "no steady beat"

Classification returns a failure (no beats, `bpm` null) when confidence is
below a threshold that **decreases** with sensitivity (more sensitive =
accepts weaker periodicity), or when fewer than 8 beats were tracked. Drops
are still reported on failure if any were found from energy alone (so the
"Mark drops only" action has something to mark); if none, that action
shows a SnackBar saying no drops were found.

### 4.7 Filter (view only)

`BeatFilter` decides which of the project's beats are **shown and
exported**; nothing is deleted:

| Filter | Shown |
|---|---|
| `every` | all |
| `strong` | type ≠ `beat` |
| `drops` | type == `drop` |
| `every2nd` | every 2nd beat counting from the first downbeat (index parity relative to it; if no downbeat, from beat 0) |
| `every4th` | every 4th beat counting the same way (so it lands on bar starts) |

Expose it as a pure helper, e.g. `List<int> visibleBeatIndices(Project)`
(indices into `project.beats`), used by the painter, hit testing, counts
and (in M6) export.

### 4.8 Sections (heuristic)

Rough sections so the editor isn't blank: split the song into 4-bar blocks
on downbeats, compute mean low-band + overall energy per block, label each
block by energy tercile, merge equal neighbours, then name runs: a run
starting at a drop is **Drop**; the 1–2 blocks of rising energy right
before a drop are **Build**; the first run is **Intro** and the last
**Outro** if they're in the lowest tercile; everything else **Verse**.
Use the colours from `sectionPresets`. Invariants (tested): sorted,
non-overlapping, contiguous, covering `[0, sampleCount)`, boundaries on beat
samples (except 0 and `sampleCount`). Skip sections entirely on failure.

### 4.9 Running it

- `BeatDetectionRepository` (abstract + impl, `data/repositories/`) with
  e.g. `Future<BeatAnalysis> analyze(String projectId, {onProgress,
  cancelToken})` and `DetectionResult classify(BeatAnalysis, double
  sensitivity)`.
- Analysis runs in its own isolate (`Isolate.spawn` with a `SendPort` for
  progress and `Isolate.kill` for cancel; `Isolate.run` can't report
  progress). Progress reports stage + fraction:
  `envelope` (reading + STFT), `tempo`, `tracking`, `sections`.
- Performance bar: a 3-minute 44.1 kHz stereo song analyses in under 10 s
  in `flutter test` on the dev machine (report the number). Peak memory
  for PCM buffers ≤ 4 MB.

## 5. Persistence

### 5.1 Model changes

Add to `DetectionSettings`:
`@Default(DetectionStatus.notRun) DetectionStatus status` with
`enum DetectionStatus { notRun, succeeded, failed }`.
Keep `schemaVersion: 1`: the new field has a default, so M2/M3 project
files still load (add a test that an M3-era `project.json` without the key
loads with `notRun`).

### 5.2 Analysis cache

Store the `BeatAnalysis` at `projects/<id>/analysis.bin` (or `.json`;
your choice — say why), versioned, written atomically through the same
serialized writer as the repository. Reading a missing/corrupt/old-version
cache means "analyze again". Add `ProjectPaths.analysisFile(id)`.

## 6. Integration and UI

### 6.1 Import (Analyzing screen)

After `createFromImport`, the import flow runs analysis + classification
with the project's default settings and saves the result into the project
(beats, bpm, beatPhaseSample, sections, `status`). Progress mapping: decode
0–0.6, project creation 0.6–0.65, analysis 0.65–1.0. The four steps on the
Analyzing screen go live: "Reading the audio" (decode), "Finding the tempo"
(envelope + tempo; show the BPM on the right once known, as in the
design), "Spotting strong beats and drops" (tracking + classification),
"Splitting into sections". Cancel still works at every stage and leaves no
project behind.

**Detection failing is not an import failure.** The project is saved with
no beats and `status: failed`, and the editor opens.

### 6.2 Editor

- **Auto tab / Auto-detect sheet** (`EditorAutoDetect.png`): opened by the
  Auto tool tab, the empty-state "Auto-detect beats" button and the
  "Re-detect" button (replacing the M2 SnackBar). Sensitivity slider with a
  label (`Fewer beats` < 0.34 ≤ `Balanced` ≤ 0.66 < `More beats`) and the
  captions "Fewer, louder beats" / "More, softer beats"; "Mark" chips for
  the five filters; the live line `Preview on the waveform ≈ N beats ·
  128 BPM` (N = visible count after filter); "Detect beats" button.
  - While the sheet is open, moving the slider or chips **previews** on the
    waveform (re-classify from the cached analysis; no isolate, no save).
  - "Detect beats" commits: the beats replace `project.beats` through the
    editor's normal commit path (so **undo** restores the previous beats),
    and bpm/phase/sections/settings/status are saved. Closing the sheet
    without committing restores what was there.
  - If there's no cached analysis yet, the sheet shows a short progress
    state while the isolate runs (with cancel), then previews.
  - Haptic success (`HapticFeedback.mediumImpact`) on commit.
- **No steady beat** (`EditorDetectFailed.png`): shown when the project's
  `status` is `failed` (e.g. on opening a freshly imported project) or
  when a commit/preview yields a failure. Actions: "Tap them in" (selects
  the Tap tool; the tap pad itself is M5), "Detect with more sensitivity"
  (re-classify with sensitivity +0.25, capped at 1, and open the Auto
  sheet on the result), "Mark drops only" (commit only the drop beats, or
  SnackBar if none).
- **Filter as a view:** the painter draws only visible beats; hidden beats
  are not drawn and not tappable; the top bar and Edit-panel counts use
  visible beats. Selection indices still refer to `project.beats`.
- Top bar shows the detected BPM (`128 BPM`) and Snap becomes available
  (it already turns on when `bpm != null`).

### 6.3 Home

Nothing new to build: saving the project after detection already updates
the card's beat count and BPM through the index. Check it does.

## 7. Tests required

Pure Dart, run with `flutter test` on Windows. Put the synthetic-audio
generator in `test/fixtures/synthetic_audio.dart` and write WAVs to temp
directories through the real file path (the detector reads files).

**Synthetic click track:** 5–10 ms decaying burst (noise × exponential
decay plus a short 1.5–3 kHz tone) starting at exact sample indices;
clicks at a known BPM with a non-zero start offset (e.g. 0.37 s); 45 s
long. "Noisy" = white noise at −20 dB relative to click peak **plus** a
110 Hz sine pad at −12 dB.

| Test | Must cover |
|---|---|
| `detector_test.dart` — accuracy | 90, 120 and 128 BPM × clean and noisy × 44.1 kHz and 48 kHz × mono and stereo: every ground-truth click matched by a detected beat within **±10 ms**, no more than 2 extra beats, BPM within **±1**. These numbers are not negotiable; report honestly if any case fails. |
| — octave handling | 128 BPM kicks with quieter 8th-note hi-hats between them (−12 dB): BPM is 128, not 256 or 64. |
| — downbeats | 120 BPM where every 4th click is +6 dB with extra low end: ≥ 90 % of detected downbeats are on the accented clicks. |
| — drops | 16 bars of quiet clicks, then 16 bars with a loud 50–80 Hz bass under the clicks: exactly one drop, within 1 beat of the change. |
| — failure | 45 s of white noise, and 45 s of a sustained chord: classification fails (no beats, bpm null). |
| `classify_test.dart` | Monotonic sensitivity (beat count and strong count never drop as sensitivity rises, over a sweep 0..1 step 0.1); type precedence; strong percentile matches the formula; classification of 2,000 candidates < 5 ms (median of 20 runs). |
| `filter_test.dart` | Each `BeatFilter` against a hand-built beat list, including `every2nd`/`every4th` counted from the first downbeat and from 0 when there is none. |
| `sections_test.dart` | Invariants in §4.8 on the drops fixture and on a song with no drops. |
| Analysis cache | Round trip; corrupt/old-version cache is ignored and rebuilt. |
| Isolate runner | Progress is monotonic per stage and ends at 1; cancel stops the isolate and the future fails with a cancel error. |
| `project_model_test.dart` (update) | Old `project.json` without `status` loads as `notRun`; `status` round-trips. |
| `import_cubit_test.dart` (update) | Detection runs after project creation; progress mapping and stage reporting; detection failure still ends in `done` with `status: failed`; cancel during analysis leaves no project. |
| Editor cubit tests | Auto sheet preview doesn't save or touch undo; commit replaces beats, is undoable, saves bpm/phase/sections/status; filter changes visible counts but not `project.beats`; "Mark drops only" and "more sensitivity" actions. |

## 8. Out of scope (do not build)

- Tap pad, latency calibration, command-stack undo, sections editing,
  click preview, haptics while playing (M5). "Tap them in" only switches the
  tool tab.
- Export (M6), guide video (M7), settings/paywall/onboarding (M8).
- The Analyzing screen's animated waveform with beats appearing (nice to
  have; skip).
- Any native or Pigeon change; any package other than `fftea`.

## 9. Acceptance checklist (used for verification)

Commands (must pass on the pushed branch):

```powershell
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Behaviour:

- [ ] All §7 tests exist and pass, including every accuracy case at ±10 ms
      and ±1 BPM with the tolerances unchanged.
- [ ] Detection reads `song.wav` in bounded chunks; no full-song PCM buffer;
      runs in an isolate with progress and working cancel.
- [ ] Frames are centered; beats are refined to the sample; output is
      integer sample indices only.
- [ ] Analysis/classification split: sensitivity and filter changes in the
      sheet preview instantly without an isolate.
- [ ] Filter never deletes beats; painter, hit testing and counts use the
      visible set.
- [ ] Downbeat and drop code is labelled as heuristic.
- [ ] Import runs detection with live Analyzing steps (BPM shown); a
      detection failure still opens the editor with the failed sheet.
- [ ] Auto sheet matches `EditorAutoDetect.png`; failed sheet matches
      `EditorDetectFailed.png`; committing is undoable.
- [ ] Old project files load (`status` defaults to `notRun`).
- [ ] Only `fftea` added to `pubspec.yaml`; nothing under `android/`,
      `ios/`, `pigeons/` changed.
- [ ] Every new file exported from its barrel; no layer bypasses (UI never
      touches files, isolates or repositories directly).
- [ ] Branch `m4/beat-detection` pushed; not merged.

## 10. Report to hand back

End your session with:

1. Branch name and `git log --oneline main..HEAD`.
2. Tails of `flutter analyze` and `flutter test` (pass counts).
3. **A table of every accuracy case**: BPM, clean/noisy, rate, channels,
   detected BPM, worst beat error in ms, extra/missed beats.
4. Analysis time for the 3-minute file and how you measured peak buffer
   memory.
5. File-level summary: new, changed, deleted.
6. Decisions where this brief was ambiguous (cache format, confidence
   measure, thresholds), and why.
7. Anything in §9 you could not complete or verify, stated plainly.
8. Anything noticed for later milestones.
