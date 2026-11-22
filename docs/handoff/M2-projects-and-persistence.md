# Handoff: M2 — Projects and persistence

This file is a self-contained brief for an agent implementing milestone M2 of
KickVolt. Part 1 is the prompt to paste. Parts 2–9 are the spec it points to.
Verification against §8 happens afterwards, in a separate session.

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M2 (Projects and persistence)** of KickVolt,
> a Flutter app in the current repository (`https://github.com/Dreymidroid/kickvolt`,
> branch `main`).
>
> Before writing any code, read these in full:
> 1. `docs/handoff/M2-projects-and-persistence.md` (this brief — it is the spec)
> 2. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 3. `PLAN.md` (overall plan; §3 "one timebase" is non-negotiable)
> 4. The code listed in §3 of the brief.
>
> Then:
> - Create a branch `m2/projects-persistence` from `main`.
> - Implement everything in §4–§6 of the brief. Do **not** do anything listed
>   in §7 (out of scope), and do not add packages.
> - Write the tests in §6.
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be clean/green.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report described in §9 of the brief.
>
> If something in the brief conflicts with the code or is ambiguous, pick the
> option that keeps beats stored as integer sample indices, note the decision
> in your report, and carry on. Do not invent platform APIs. Do not edit native
> code (`android/`, `ios/`) or `pigeons/`.

---

## 2. Context

KickVolt lets a user import a song, mark its beats, and export a "beat pack"
(the song plus a click guide track) for CapCut/VN. M1 is done: import from
Files / music library / video, native decode to `projects/<id>/song.wav`.

**Core rule (from PLAN.md §3):** every beat, section bound and range is an
`int` **sample frame index** into the decoded PCM (`song.wav`). Never store
seconds or milliseconds. Convert to time only for display or to convert a
user-facing amount (e.g. "nudge +10 ms" → `round(10 * sampleRate / 1000)`
frames).

Environment notes:
- Dev machine is Windows; you can't build iOS. Don't touch native code in M2.
- Material is imported from `package:material_ui/material_ui.dart`, **not**
  `package:flutter/material.dart` (see `.ai/rules/structure.md`).
- Theme tokens: `context.kv` (`KvColors`); fonts via `KvText`. Reuse widgets
  in `lib/shared/` (`KvPrimaryButton`, `KvSecondaryButton`, `KvIconButton`,
  `KvChip`, `KvIcon`/`KvIcons`, `KvSegmented`).
- After running `dart run pigeon`, also `dart format` the generated Dart file
  (CI checks generated code is up to date). You should not need Pigeon in M2.
- Copy says "beats", "drops", "sections"; never "transients" or "onsets".

Designs: `design/kickvolt-design/png/*.png` (visual truth, 390×844 logical at
2×) and `design/kickvolt-design/screens/*.html` (exact sizes/colours/copy).
Relevant to M2: `Home.png`, `HomeEmpty.png`, `EditorEmpty.png`,
`EditorDetected.png`. **Free-tier copy is 30, not the designs' 3**
(`AppConstants.freeExportsPerWeek`).

## 3. Existing code you'll touch

| Path | What it is today |
|---|---|
| `lib/core/storage/project_paths.dart` | `ProjectPaths(documentsDir)`: `projectDir(id)`, `sourceFile(id, ext)`, `songWav(id)`, `deleteProject(id)`. |
| `lib/core/audio_math/wav_header.dart` | `readWavInfo(File)` → `WavInfo` (`sampleRate`, `channels`, `dataOffset`, `frameCount`), `buildWavHeader`. |
| `lib/core/di/locator.dart` | GetIt setup. `Future<ProjectPaths>` is registered as a lazy singleton. |
| `lib/features/import/` | M1. `ImportRepository.importSong()` → `ImportedSong` (projectId, title, source, sourceCopyPath, wavPath, sampleRate, channels, frameCount). `ImportCubit` drives the Analyzing screen and, on `done`, the screen replaces itself with `BeatEditorRoute(projectId:)`. |
| `lib/features/projects/presentation/pages/home_screen.dart` | Home: header ("30 free left" chip, settings icon) + **empty state only**, import flow via `SourcePickerCubit`. |
| `lib/features/beat_editor/` | Editor UI prototype. **Millisecond-based**: `Beat(timeMs, type)`, `BeatProject(id, name, durationMs, int bpm, beats, sections, peaks, peakBinMs=10)`, `SongSection(startMs, endMs, kind: SectionKind)`, cubit state `playheadMs`, `nudgeSelected(deltaMs)`, `addBeatAtPlayhead()` snaps to `60000/bpm`. Painter `timeline_painter.dart` maps ms → px with `kPxPerSecondAt1x = 12.8` × zoom. Data comes from `DemoBeatProjectRepository` (a fake 128 BPM song). |
| `lib/shared/styles/kv_colors.dart` | `KvColors.section(SectionKind)` returns the section colour. |
| `test/features/beat_editor/bloc/*.dart` | 15 cubit tests against the demo repository. They must keep passing after the migration (ported to samples). |

## 4. Scope

### 4.1 Domain model (owned by the `projects` feature)

Create `lib/features/projects/` following the feature layout in
`.ai/rules/structure.md`. Entities (Freezed, `domain/entities/`):

```text
Project
  id: String
  title: String
  source: ProjectSource
  sampleRate: int            // from song.wav header
  channels: int              // from song.wav header
  sampleCount: int           // frames in song.wav — the master timebase
  beats: List<Beat>          // sorted by sample, no duplicates
  sections: List<Section>    // sorted, non-overlapping
  bpm: double?               // null until detection (M4) or manual entry
  beatPhaseSample: int?      // grid phase for snap; null until known
  detection: DetectionSettings
  createdAt: DateTime        // UTC
  updatedAt: DateTime        // UTC

ProjectSource
  kind: ImportSourceKind     // reuse the enum from features/import (file|library|video)
  originalName: String       // e.g. "Midnight Run.m4a"
  copiedFileName: String?    // e.g. "source.m4a"; null for iOS library items

Beat
  sample: int
  type: BeatType             // beat | strong | drop | downbeat

Section
  startSample: int
  endSample: int             // exclusive
  name: String               // e.g. "Verse"
  colorArgb: int

DetectionSettings
  sensitivity: double        // 0–1, default 0.5
  filter: BeatFilter         // every | strong | drops | every2nd | every4th; default every
```

Derived getters on `Project` (pure, tested): `durationMs`
(`sampleCount * 1000 ~/ sampleRate`), `sampleToMs(int)`, `msToSamples(int)`,
`beatCount`, `strongCount` (non-`beat` types), `dropCount`.

Section presets (for M5's UI, define now so colours have one home):
Intro/Outro `#9B8CFF`, Verse `#45D4FF`, Build `#FF6FB5`, Drop `#FF8A4C`
(the HANDOFF tokens). Expose them as a `SectionPreset` list in the domain
layer; `KvColors.section(SectionKind)` can be removed or rewritten to read
the colour from the section itself.

**Paths are not stored as absolute paths.** iOS changes the app container
path between installs and updates. Store file *names* relative to the
project folder and resolve them with `ProjectPaths`.

### 4.2 Persistence: one JSON file per project

Data layer (`data/models/` with Freezed + json_serializable, plus a mapper
to/from the entities). Layout per project:

```text
<documents>/projects/<id>/
  source.<ext>        # from M1 (absent for iOS library items)
  song.wav            # from M1
  overview.bin        # NEW in M2 — see 4.3
  project.json        # NEW in M2
<documents>/projects/index.json   # NEW in M2 — summaries for Home
```

`project.json` top level includes `"schemaVersion": 1`. Unknown future
versions must not crash the app: skip that project in the list and log it.

`ProjectRepository` (abstract) + `ProjectRepositoryImpl` in
`data/repositories/`, registered in `repository_locator`-style GetIt setup
(the current single `locator.dart` is fine). Operations:

| Method | Behaviour |
|---|---|
| `Future<Project> createFromImport(ImportedSong song)` | Reads `song.wav` header (via `readWavInfo`) for sampleRate/channels/sampleCount; computes `overview.bin` in an isolate; writes `project.json`; updates `index.json`. Empty beats/sections, `bpm: null`. On any failure, delete the project folder and rethrow. |
| `Future<List<ProjectSummary>> listProjects()` | From `index.json`, newest `updatedAt` first. Rebuild the index (by reading every `project.json`) if it is missing, unparseable, or its id set differs from the project folders on disk. |
| `Future<Project> getProject(String id)` | Reads `project.json`. Throws a typed not-found / corrupt exception (don't leak `FileSystemException` / `FormatException` to the UI). |
| `Future<void> saveProject(Project p)` | Sets `updatedAt = now (UTC)`, writes atomically, updates the index entry. |
| `Future<void> renameProject(String id, String title)` | Trims; rejects empty. |
| `Future<void> deleteProject(String id)` | Deletes the folder and its index entry. |
| `Future<void> cleanUpOrphans()` | Called once at app start, before any import: deletes project folders that have neither `project.json` nor a recoverable `project.json.tmp` (left by an import that was killed). |

**Atomic writes:** write `<name>.tmp`, flush (`flush: true`), then rename
over the target. When reading, if `project.json` is missing but
`project.json.tmp` exists and parses, promote it (rename) and use it. Same
pattern for `index.json`.

`ProjectSummary` (what Home needs, stored in `index.json`): `id`, `title`,
`beatCount`, `bpm`, `durationMs` (display only), `updatedAt`, and
`thumbnail: List<int>` — 64 values 0–255, downsampled from `overview.bin`.

Never hold a whole song in memory. Never read `song.wav` on the UI isolate.

### 4.3 Interim waveform data: `overview.bin`

M3 will add proper multi-resolution peaks. M2 needs just enough for the Home
mini waveform and for the editor to draw something real:

- One value per bin, `binFrames = round(sampleRate / 100)` (≈ 10 ms).
- Value = max absolute sample across all channels in the bin, scaled to
  0–255 (`(maxAbs * 255) ~/ 32767`).
- File format, little-endian: ASCII `KVOV`, `u16 version = 1`,
  `u32 binFrames`, `u32 binCount`, then `binCount` bytes.
- Computed with `Isolate.run` (or `compute`), reading `song.wav` from
  `WavInfo.dataOffset` in chunks of ≤ 1 MB. A 10-minute stereo song must not
  allocate more than a few MB.
- Pure functions (`computeOverview(...)`, `encodeOverview`/`decodeOverview`,
  `thumbnail(overview, 64)`) in `lib/core/audio_math/overview.dart`, unit
  tested.

### 4.4 Import → project

After `ImportRepository.importSong` succeeds, the import flow must call
`ProjectRepository.createFromImport(song)` before reporting `done`, so the
editor always opens a saved project. Keep the layer rule: the Cubit calls
repositories, never the UI. Suggested: `ImportCubit` takes both
repositories (constructor injection with `locator` defaults); decode progress
maps to 0–0.9 and project creation to 0.9–1.0. A creation failure is an
`ImportFailure(unknown)` and removes the folder. Update the M1 tests
accordingly.

### 4.5 Editor migration (milliseconds → samples)

Migrate `lib/features/beat_editor/` to load and save real `Project`s:

- Delete `BeatProject`, the editor's `Beat`/`SongSection` and
  `BeatProjectRepository`/`DemoBeatProjectRepository` from `lib/`. The
  editor uses the `projects` feature's entities and `ProjectRepository`.
- Move the demo song generator to `test/fixtures/demo_project.dart` (as a
  `Project` in samples, 44.1 kHz) for the ported tests.
- Cubit state holds `project` plus the overview (`Uint8List` + `binFrames`)
  and `playheadSample: int` (replaces `playheadMs`). Zoom stays as is.
- `nudgeSelected(int deltaMs)` keeps its ms-based API but converts to frames
  with the project's sample rate; neighbour clamping and the 1-second
  undo-coalescing behaviour stay.
- `addBeatAtPlayhead()`: snaps only when `snap` is on **and** `bpm != null`;
  grid = `sampleRate * 60 / bpm` frames, offset by `beatPhaseSample ?? 0`;
  duplicate guard = 20 ms converted to frames.
- `seekBy(ms)` / transport ±2 s convert ms → frames.
- Painter and hit testing: `pxPerSample = zoom * kPxPerSecondAt1x / sampleRate`.
  Waveform reads from the overview; section tint/label use `section.colorArgb`
  / `section.name`. Ruler and time bubble format time from samples.
- **Persistence:** every committed edit (add, nudge, type, delete, undo,
  redo) saves via `ProjectRepository.saveProject`, debounced ~500 ms, and
  pending saves are flushed in `close()`. Undo/redo stacks are not persisted.
  A failed save emits an error the UI shows as a SnackBar; it must not lose
  the in-memory edit.
- **Empty / unknown-tempo states** (imported projects have no beats or BPM
  until M4). Match `EditorEmpty.png` where it applies: top bar subtitle
  `2:48 · no beats yet`; BPM chip shows `– BPM`; Snap chip disabled when
  `bpm == null`; the context panel shows the two buttons from the design.
  "Auto-detect beats" shows a SnackBar "Beat detection arrives in the next
  update" (M4 wires it). "Tap them in while it plays" switches to the Tap
  tool tab. Nothing may throw or divide by zero with 0 beats, no sections or
  `bpm == null`.
- Fake playback (the `Timer` ticker) stays until M3. Its time maths moves to
  frames.
- `BeatEditorRoute` requires `projectId` (no `'demo'` default). Load errors
  (not found / corrupt) show an error view with a "Back to projects" button.

### 4.6 Home: project list

Match `Home.png` (list) and keep `HomeEmpty.png` (no projects).

- `ProjectsCubit` (`features/projects/bloc/`): states `loading`,
  `loaded(List<ProjectSummary>)`, `error`. Methods `load()`, `rename(id,
  title)`, `delete(id)`. It reloads when Home becomes visible again (e.g.
  returning from the editor) so "Edited …" and counts are fresh.
- Header (existing) + `Projects` title (Space Grotesk ~34) + right-aligned
  count `5 songs` / `1 song` (text2).
- Card per project (surface1, border, radius ~24): title (ui 17 w600, one
  line, ellipsis), right-aligned `Edited …` (text2); second line
  `358 beats · 128 BPM · 2:48` — the number of beats in volt, `beats` in
  text2, BPM and duration in JetBrains Mono; when `bpm == null` show
  `– BPM`; when 0 beats show `no beats yet` instead of `0 beats`.
- Mini waveform (CustomPainter) from the 64-value thumbnail, bars in
  `waveUnplayed`, plus a row of small volt ticks under it (≈ 32 evenly
  spaced, every 4th taller and full opacity) **only if the project has
  beats**.
- Tap → `BeatEditorRoute(projectId:)`. Long-press → bottom sheet with
  "Rename" (dialog with text field, prefilled) and "Delete" (confirmation
  dialog naming the song; `HapticFeedback.mediumImpact()` on confirm).
- `ListView.builder`. The "Import a song" primary button stays pinned at the
  bottom over a fade, as in the design.
- "Edited …" label, a pure tested function `editedLabel(DateTime updated,
  DateTime now)` in local time:
  `< 1 min` → `Edited just now`; `< 60 min` → `Edited 5 min ago`;
  `< 24 h` → `Edited 2 h ago`; previous calendar day → `Edited yesterday`;
  within the last 7 days → `Edited Mon`; same year → `Edited 12 Nov`;
  otherwise `Edited 12 Nov 2025`.

### 4.7 Routing and startup

- Routes: Home (initial) → Analyzing → Editor (replace) as today; Home →
  Editor for existing projects.
- `main.dart`: after `setupLocator()`, run `ProjectRepository.cleanUpOrphans()`
  (don't block the first frame for more than a moment; failures are logged,
  not fatal).

## 5. Rules to respect (summary of the repo rules)

- Feature-first folders, barrels for every feature (export every new file),
  import via barrels across features.
- Cubits get repositories by constructor with a `locator` default; wrap
  repository calls in try/catch; emit loading → loaded/error.
- Freezed unions (`sealed class`) for states; single-case data `abstract
  class`. Read states with Dart `switch` on the sealed type.
- UI never touches repositories, `File`, or `ProjectPaths` directly.
- No new packages. (`path_provider`, `path`, `uuid`, `freezed`,
  `json_serializable`, `bloc_test`, `mocktail` are already available.)
- Don't break M1: import flow, error dialog, Android library list.

## 6. Tests required

All pure Dart, runnable with `flutter test` on Windows. Use temp directories,
never the real documents folder.

| Test file | Must cover |
|---|---|
| `test/core/audio_math/overview_test.dart` | Synthetic 16-bit WAV (mono and stereo, odd final bin): correct bin count, max-abs per bin across channels, scaling to 0–255, encode/decode round trip, header fields, `thumbnail` length 64 and max-preserving downsample. |
| `test/features/projects/data/project_model_test.dart` | JSON round trip of a full project (all beat types, sections, bpm, detection settings, dates in UTC); `schemaVersion` written; unknown version rejected with the typed exception. |
| `test/features/projects/data/project_repository_test.dart` | `createFromImport` writes project.json + overview.bin + index entry with the WAV's real sample count; save/get round trip updates `updatedAt`; list order newest-first; index rebuilt when deleted or corrupt or out of sync with folders; `.tmp` promotion; corrupt project.json is skipped in the list (not fatal) and `getProject` throws the typed exception; rename (and empty-title rejection); delete removes folder + entry; `cleanUpOrphans` removes a folder with only `song.wav` but keeps complete projects; stored paths are relative (move the documents dir and reload). |
| `test/features/projects/bloc/projects_cubit_test.dart` | load → loaded/empty/error; rename; delete. |
| `test/features/projects/presentation/edited_label_test.dart` | Every branch of `editedLabel`, including the year boundary. |
| `test/features/import/bloc/import_cubit_test.dart` (update) | Project creation after decode; progress ends at 1.0; creation failure → failed state. |
| `test/features/beat_editor/bloc/*` (port) | All existing behaviours, now in samples, against `test/fixtures/demo_project.dart`; plus: nudge ±1 ms at 44.1 kHz moves exactly 44 frames (`round(44.1)`) and at 48 kHz exactly 48; snap uses `bpm` + `beatPhaseSample`; with `bpm == null` add-at-playhead does not snap; edits trigger a debounced `saveProject` (mock repository, `fakeAsync` or real short delays) and `close()` flushes a pending save; 0-beat project: select/nudge/delete/undo are no-ops and don't throw. |
| Timebase invariant (anywhere sensible) | Converting a beat's sample → ms → sample for display never mutates stored beats: save/load round trip of 1,000 beats at 44.1 kHz and 48 kHz returns identical integers. |

## 7. Out of scope for M2 (do not build)

- Real audio playback / just_audio (M3), multi-level peaks / 60 fps work (M3).
- Beat detection (M4) beyond the placeholder SnackBar.
- Command-stack undo, tap pad, latency calibration, sections editing UI,
  click preview (M5).
- Export, share (M6). Guide video (M7). Settings screen, onboarding,
  paywall, entitlement service (M8). The settings icon and "How beat packs
  work" stay non-functional.
- Any native (Kotlin/Swift) or Pigeon change. Any new package.

## 8. Acceptance checklist (used for verification)

Commands (all must pass on the pushed branch):

```powershell
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Behaviour:

- [ ] No `timeMs`, `durationMs` field, `startMs`/`endMs`, or `playheadMs` is
      stored in any entity, model or state (ms only in display helpers and
      user-facing nudge/seek arguments).
- [ ] `project.json` contains only sample indices for beats/sections and
      relative file names; `schemaVersion: 1`.
- [ ] Writes are atomic (`.tmp` + rename) for both project.json and
      index.json.
- [ ] `overview.bin` is computed off the UI isolate in bounded memory.
- [ ] Import → Analyzing → editor opens the **imported** project (not the
      demo); killing the app and relaunching shows it on Home.
- [ ] Home list matches `Home.png`; empty state still matches `HomeEmpty.png`;
      count, "Edited …", `– BPM` / `no beats yet` cases render.
- [ ] Rename and delete work, with confirmation for delete.
- [ ] Editor edits persist across leaving and reopening the project.
- [ ] Editor with 0 beats and `bpm == null` matches `EditorEmpty.png` closely
      enough and nothing throws.
- [ ] Demo repository is gone from `lib/`; the fixture lives in `test/`.
- [ ] Every new file is exported from its barrel; no layer bypasses.
- [ ] No changes under `android/`, `ios/`, `pigeons/`; no new packages in
      `pubspec.yaml`.
- [ ] All tests in §6 exist and pass; existing 39 tests still pass (ported
      where needed).
- [ ] Branch `m2/projects-persistence` is pushed; not merged.

## 9. Report to hand back

End your session with a message containing:

1. Branch name and the list of commits (`git log --oneline main..HEAD`).
2. The output tail of `flutter analyze` and `flutter test` (pass counts).
3. A file-level summary: new, changed, deleted.
4. Any decision you made where this brief was ambiguous, and why.
5. Anything in §8 you could not complete or verify, stated plainly.
6. Anything you noticed that should be fixed later but was out of scope.
