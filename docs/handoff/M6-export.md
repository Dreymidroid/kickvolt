# Handoff: M6 — Export

Self-contained brief for an agent implementing milestone M6 of KickVolt.
Part 1 is the prompt to paste. Parts 2–11 are the spec. Verification
against §10 happens afterwards, in a separate session.

**Precondition:** M5 is merged into `main` (done 2026-11-26). M6 reuses
M5's click synth, preview mix, settings store and haptics service.

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M6 (Export)** of KickVolt, a Flutter app
> in the current repository (`https://github.com/Dreymidroid/kickvolt`,
> branch `main`).
>
> Before writing any code, read these in full:
> 1. `docs/handoff/M6-export.md` (this brief — it is the spec)
> 2. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 3. `PLAN.md`, especially §3 "one timebase" (non-negotiable), §5 (native
>    interface draft), §6 "M6", §8 (decisions) and §9 (what M1–M5 built,
>    known limits)
> 4. `design/kickvolt-design/HANDOFF.md` and the screens `Export`,
>    `Exporting`, `ExportFailed`, `ExportSuccess` (`png/` = visual truth,
>    `screens/*.html` = exact copy and sizes)
> 5. The code listed in §3 of the brief.
>
> Then:
> - Create a branch `m6/export` from `main`.
> - Implement §4–§7. Do **not** do anything in §9 (out of scope).
> - The only new package allowed is `share_plus` (§6.1). Confirm every
>   `share_plus` API you call in your pub cache before using it.
> - Native code (§5) uses only documented platform APIs. For each one,
>   name the Apple / Android reference page in your report. Do not invent
>   APIs; if something you need isn't there, say so instead of working
>   around it.
> - Write the pure-Dart tests in §8 **first** (WAV writer, guide track,
>   pack planner, file names, export pipeline), then make them pass. Then
>   the cubit and widget tests.
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart run pigeon --input pigeons/audio_api.dart`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be
>   clean/green. Run `flutter test` at least twice; a test that passes only
>   sometimes is a failure.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report in §11.
>
> If the brief is ambiguous, pick the option that keeps every exported file
> at the song's exact sample rate and frame count, and keeps clicks at the
> exact beat sample; note the decision in your report and carry on. Do not
> loosen a test tolerance to make it pass; if a check can't be met, say so
> in the report. Report honestly what you could not compile or run.

---

## 2. Context

KickVolt lets a user import a song, mark its beats and export a **beat
pack** (the song plus a click guide track) for CapCut/VN. The user puts the
guide track under the song at 0:00, runs the editor's auto-beat on it, and
mutes it. That only works if every click sits **exactly** on the beat
sample and the guide is exactly as long as the song. Done so far (details
in `PLAN.md` §9):

- **M1** import + native decode to `projects/<id>/song.wav` (16-bit PCM,
  native sample rate, 1–2 channels). Pigeon `AudioHostApi` with Swift and
  Kotlin implementations.
- **M2** one `project.json` per project, atomic serialized writes; Home.
- **M3** peaks, zoom, `just_audio` playback.
- **M4** pure-Dart beat detection; filter as a view (`visibleBeatIndices`).
- **M5** command stack, Tap/Bulk/Sections, click synth
  (`lib/core/audio_math/click_synth.dart`), streaming preview mix
  (`preview_mix.dart`), settings store (`shared_preferences`), haptics
  service, latency calibration.

M6 adds the Export flow: options screen, a streaming export job in an
isolate with progress and cancel, native M4A encoding, failure handling
(disk full, interrupted), the success screen with share / Save to Files,
and a stub `EntitlementService` (everything allowed) that a later payments
milestone replaces. **No payments, limits or "Pro" labels are visible
anywhere for now** (decided 2026-11-26).

**Core rule:** every exported audio file has the **same sample rate and
frame count** as `song.wav`, read back from the file. Clicks start at the
exact beat sample. Beats are clamped to `[0, sampleCount - 1]` before
rendering. Never re-export the user's original compressed file
(`source.*`): it carries encoder priming/padding that shifts timing.

Environment notes:
- Windows dev machine; no Android device or emulator, and the local
  Android build is broken (truncated Gradle download). iOS compiles only on
  Codemagic, which hasn't been run yet. **Native code you write here can't
  be compiled or run locally.** Keep the native surface small, write it
  carefully against the docs, and say plainly in the report that it is
  uncompiled. The Dart side (everything except the M4A encode and the
  native save) is the acceptance bar and must be fully tested.
- Material comes from `package:material_ui/material_ui.dart`.
- Theme: `context.kv` (`KvColors`), fonts via `KvText`. Reuse `lib/shared/`
  widgets before writing new ones.
- On Windows an open file handle blocks deleting its folder. Anything that
  writes files in an isolate that may be cancelled must close them on
  every path.

## 3. Existing code you'll touch

Names below are as on `main` after the M5 merge (2026-11-26).

| Path | What it is today |
|---|---|
| `lib/core/audio_math/wav_header.dart` | `readWavInfo(File)` → `WavInfo` (`sampleRate`, `channels`, `bitsPerSample`, `dataOffset`, `dataBytes`, `frameCount`, `bytesPerFrame`); `buildWavHeader({sampleRate, channels, bitsPerSample, frameCount})` → 44-byte header. |
| `lib/core/audio_math/click_synth.dart` (M5) | `enum ClickStyle { snap, rim, blip, kick }`, `kClickPeakLinear` (−3 dBFS), `renderClick(style, sampleRate)` → `Float64List`, `addClicksToChunk({monoOut, chunkStart, chunkLength, beatSamples, click, totalSampleCount})`, `clipInt16`. **Reuse unchanged.** |
| `lib/core/audio_math/preview_mix.dart` (M5) | `renderPreviewMix({songWavPath, outputWavPath, beatSamples, style, songGain, isCancelled, onProgress})` → `PreviewMixStats`; writes `.part` then renames; closes files in `finally`. The export's preview mix **reuses this**. |
| `lib/features/click_preview/data/preview_isolate_runner.dart` (M5) | Isolate runner with cooperative cancel + grace-period kill. Follow the same pattern (or extract a shared runner into `lib/core/isolates/` if that's cleaner; don't change behaviour). **Lesson from M5 verification:** a cancel that arrives while the isolate is still spawning must wait for the spawn and stop the worker; otherwise an orphan renders the whole file and keeps it open. Test this case. |
| `lib/features/beat_detection/domain/beat_filter_view.dart` | `visibleBeatIndices(project)` — the export uses the **visible** beats (the user's current filter). |
| `lib/features/settings/` (M5) | `AppSettings` (Freezed), `SettingsRepository` over `SharedPreferences` (keys `UPPER_SNAKE_CASE`). You add export defaults here (§6.4). |
| `lib/core/haptics/haptics.dart` (M5) | `Haptics.successNotification()` on export success. |
| `lib/core/storage/project_paths.dart` | Per-project paths; add `exportsDir(id)` (`projects/<id>/exports/`). |
| `lib/features/projects/` | `Project` (`title`, `sampleRate`, `channels`, `sampleCount`, `beats`, `bpm`), `ProjectRepository` (serialized atomic writes). |
| `lib/features/beat_editor/presentation/widgets/editor_top_bar.dart` | Export pill — currently does nothing. Wire it to the Export route. |
| `pigeons/audio_api.dart` → `lib/core/audio_native/audio_api.g.dart`, `AudioApi.g.kt`, `AudioApi.g.swift` | `AudioHostApi` (`decodeToWav`, `cancelJob`, library, `copyContentUri`, `freeDiskBytes`) + `AudioProgressApi.onProgress`. Error codes include `disk_full`, `cancelled`. You add methods (§5). |
| `lib/core/audio_native/audio_native_client.dart` | Dart wrapper (`AudioNative` interface, `AudioNativeException(kind)`). Extend it; tests use a fake. |
| `android/app/src/main/kotlin/com/kickvolt/app/audio/` | `AudioHostApiImpl.kt`, `WavDecoder.kt` (coroutines, job map, cancel). Add `M4aEncoder.kt`, `FileSaver.kt`. |
| `ios/Runner/Audio/` | `AudioHostApiImpl.swift`, `WavDecoder.swift`. Add `M4aEncoder.swift`, `FileSaver.swift` **and register them in `ios/Runner.xcodeproj/project.pbxproj` by hand** (copy how M1 added the `Audio` group's files: a `PBXFileReference`, a `PBXBuildFile`, an entry in the group and in the Runner target's Sources phase, each with a new unique 24-hex id). A Swift file missing from the project doesn't compile into the app and Codemagic won't tell you why the symbol is missing. |
| `lib/app/app_constants.dart` | `AppConstants.freeExportsPerWeek = 30` (for the later payments milestone; the stub ignores it). |
| `test/fixtures/` | `synthetic_audio.dart` / `synthetic_music.dart` (WAV writers with faded notes), `demo_project.dart`, `editor_fakes.dart`. |

## 4. Export pipeline (pure Dart)

### 4.1 Shape

New feature `lib/features/export/` (barrel `export.dart`, exported from
`features.dart`). Suggested seams (adapt names, keep the behaviour):

```dart
/// What the user chose on the Export screen.
class ExportOptions {
  final bool includeSong;      // always true in the UI; kept for tests
  final bool includeGuide;     // always true in the UI
  final bool includePreview;   // optional
  final ClickStyle clickStyle;
  final AudioFormat format;    // wav (default) | m4a
  final bool monoGuide;        // from settings (§6.4)
}

/// Pure: decides file names and what to render, from a project + options.
BeatPackPlan planBeatPack(Project project, ExportOptions options);

/// Runs a plan: renders into `exports/<packId>/*.part`, encodes if M4A,
/// renames, returns the finished files. Cancellable, reports progress.
abstract interface class ExportRepository {
  Future<BeatPack> export(Project project, ExportOptions options,
      {required ExportCancelToken cancel,
       void Function(ExportProgress)? onProgress});
  Future<void> cleanUpStaleParts();          // called at app start
  Future<List<BeatPack>> packsFor(String projectId); // optional, for "last export"
}
```

The cubit never sees files being written; it sees `ExportProgress`
(overall fraction, current step, per-file fraction, "Placing N clicks…")
and a `BeatPack` (list of `ExportedFile { path, kind, displayName,
frameCount, clickCount }`) or a typed failure.

### 4.2 WAV writer

`lib/core/audio_math/wav_writer.dart`, pure Dart, streaming:

- RIFF/WAVE, `fmt ` chunk PCM (format 1), 16-bit, little-endian, 44-byte
  header from `buildWavHeader` (reuse; don't write a second header
  builder).
- Opens a `RandomAccessFile` on `<path>.part`, writes a header with the
  **known** frame count up front (we always know it: it's the song's), then
  data in chunks, then verifies the number of frames written equals the
  declared count before closing. A mismatch is a bug → throw, delete the
  `.part`.
- `close()` in `finally` on every path; on cancel or error delete the
  `.part`.
- Rename `.part` → final name only after the file is closed.

### 4.3 Guide track

`renderGuideTrack({songWavPath, outputWavPath, beatSamples, style,
channels (1 or 2), isCancelled, onProgress})`:

- Reads only the **header** of `song.wav` (`readWavInfo`) for
  `sampleRate` and `frameCount`; it never reads the song's samples.
- Output: same `sampleRate`, same `frameCount`, 16-bit, `channels` = 2
  (default, `PLAN.md` §8.8) or 1 when "Mono guide track" is on. Same click
  on every channel.
- Silence everywhere except clicks. Clicks via `renderClick` +
  `addClicksToChunk`, then `clipInt16`. Peak ≈ −3 dBFS (one click);
  overlapping clicks are summed and clipped; a click near the end is
  truncated at `frameCount`.
- First non-zero sample of each click == the beat sample.
- Beats: the **visible** beats (`visibleBeatIndices(project)`), sorted,
  de-duplicated, clamped to `[0, frameCount - 1]`. If the project's
  `sampleCount` disagrees with `song.wav`'s frame count, the **file wins**
  (log it, clamp to the file).
- Chunked: bounded memory (≤ 4 MB peak buffers for any song length).

### 4.4 Song

- **WAV:** a byte-exact copy of `song.wav` (stream copy in chunks into
  `.part`, rename). Then `readWavInfo` the result and check rate, channels
  and frame count equal the source.
- **M4A:** native AAC encode of **our** `song.wav` (§5.1), never of
  `source.*`.

### 4.5 Preview mix (optional)

`renderPreviewMix` from M5 with the chosen click style and the visible
beats. Same rate/channels/frames as the song by construction. M4A if the
format is M4A.

### 4.6 Format, names, folder

- **One format for the whole pack.** If the user picks M4A, the song, the
  guide and the preview are all M4A, encoded with the same native encoder
  settings. Why: AAC adds encoder priming (typically 1024–2112 frames) at
  the start, and some editors don't trim it. If both files go through the
  same encoder, any shift is the same for both and they stay aligned with
  each other. A WAV guide under an M4A song could be ~25–50 ms off in
  such an editor. Never mix formats inside a pack.
- **M4A warning** (inline under the format chips when M4A is selected):
  "M4A is smaller, but some editors shift it by a few milliseconds. Use WAV
  for exact sync." WAV stays the default.
- **File names:** `<Title>_song.<ext>`, `<Title>_beats.<ext>`,
  `<Title>_preview.<ext>` (the user asked for `_beats`; the design mock
  shows `_guide` — use `_beats` and flag it in the report). `<Title>` is
  the project title sanitised for file systems: drop characters in
  `\/:*?"<>|` and control characters, collapse whitespace, trim dots and
  spaces from the ends, keep Unicode letters, cap at 60 UTF-16 units
  without splitting a surrogate pair, fall back to `KickVolt` when empty.
  Spaces → nothing to match the design (`MidnightRun_song.m4a`) — or keep
  them; pick one, test it, say which.
- **Folder:** `projects/<id>/exports/<yyyyMMdd-HHmmss>/` (one folder per
  pack, so a re-export never overwrites a file the share sheet may still be
  reading). Add `ProjectPaths.exportsDir(id)` / `exportPackDir(id, stamp)`.
  Keep the last 3 packs per project; delete older ones after a successful
  export. Project delete already removes them (same folder).

### 4.7 Running it

- Rendering runs in an isolate with cooperative cancel (check between
  chunks; grace period then hard kill, as M4/M5 do). Native encodes run on
  native background threads and cancel through `cancelJob(jobId)`.
- Order: guide → song → preview (the guide is the file that matters; if
  the disk fills, it fails early). Progress: weight each step by frames.
- **Disk space:** before starting, estimate the bytes (WAV: `44 + frames ×
  channels × 2` per file; M4A: WAV estimate × 0.25 for the transient WAV
  plus the M4A) and compare with `freeDiskBytes(exportsDir)` with a 20 MB
  margin. Not enough → fail with `diskFull` before writing anything.
  During writing, a `FileSystemException` whose `osError.errorCode` is 28
  (`ENOSPC` on both iOS and Android) or a native `disk_full` → `diskFull`.
  Report how many MB are needed (the design's "Free up about 40 MB").
- **Interrupted:** all writes go to `.part` names in the pack folder and
  are renamed only at the end; the pack folder is deleted on failure or
  cancel. At app start `cleanUpStaleParts()` deletes pack folders that
  contain any `.part` file or are empty. If the app goes to the background
  mid-export, let it continue (on iOS request background time, §5.3); if
  the job dies, the screen shows ExportFailed with the "interrupted" copy
  and **Try again**.
- **Atomicity:** the pack is reported only when every file is renamed and
  re-read (`readWavInfo` for WAV; native probe for M4A, §5.1).

## 5. Native additions (Pigeon)

Extend `pigeons/audio_api.dart` (then regenerate and `dart format
lib/core/audio_native/audio_api.g.dart` — CI diffs it). Keep the existing
methods and error codes unchanged. Add:

```dart
/// Encodes a 16-bit PCM WAV to AAC in an MPEG-4 container (.m4a) at
/// [bitrate] bits/s, same sample rate and channel count. Progress through
/// AudioProgressApi. Fails with `disk_full`, `encode_failed`, `cancelled`.
@async
MediaInfo encodeM4a(String jobId, String wavPath, String outPath, int bitrate);

/// Duration and format of an audio file as the platform sees it (for
/// verifying an export, and for the E2E tests).
@async
MediaInfo probeMedia(String path);

/// Lets the user pick a folder (Android SAF / iOS document picker) and
/// copies [paths] into it. Returns how many were saved; 0 if cancelled.
@async
int saveToFiles(List<String> paths);

/// iOS: begins/ends a background task so an export can finish when the app
/// is backgrounded. Android: no-op.
int beginBackgroundWork(String name);
void endBackgroundWork(int token);

class MediaInfo { int sampleRate; int channels; int durationUs; int? frameCount; }
```

### 5.1 `encodeM4a`

- 192 kbps AAC-LC by default (constant in Dart).
- **iOS:** `AVAssetReader` (or read the WAV yourself) → `AVAssetWriter`
  with `AVFileType.m4a` and an `AVAssetWriterInput` for audio with
  `AVFormatIDKey: kAudioFormatMPEG4AAC`, sample rate and channel count of
  the source, `AVEncoderBitRateKey`. Write on a background queue;
  `requestMediaDataWhenReady`; cancel → `cancelWriting()` and delete the
  output.
- **Android:** `MediaCodec` encoder for `MediaFormat.MIMETYPE_AUDIO_AAC`
  (`KEY_AAC_PROFILE` = `AACObjectLC`, `KEY_BIT_RATE`, sample rate,
  channels) fed from the WAV's PCM, output into `MediaMuxer` with
  `MUXER_OUTPUT_MPEG_4`. Set `presentationTimeUs` from the frame position
  (`frames * 1_000_000 / sampleRate`), not from a wall clock. Use the
  existing coroutine/job pattern for cancel. Delete the output on failure.
- Both: return `probeMedia(outPath)`.
- AAC encoders only support certain sample rates (all common ones incl.
  44.1/48 kHz). If the platform refuses the song's rate, fail with
  `encode_failed`; the UI offers WAV.

### 5.2 `saveToFiles`

- **Android:** `Intent.ACTION_OPEN_DOCUMENT_TREE` → the user picks a
  folder → for each file `DocumentsContract.createDocument(resolver,
  treeDocUri, mime, displayName)` and stream-copy through
  `contentResolver.openOutputStream`. Needs an activity-result callback in
  `MainActivity` (M1 already routes permission results there; follow that
  pattern). No storage permission is needed for SAF.
- **iOS:** `UIDocumentPickerViewController(forExporting: urls, asCopy:
  true)` (iOS 14+) presented from the root view controller; the delegate
  reports picked / cancelled.
- Both return the number of files saved (0 on cancel, not an error).

### 5.3 Background work

- **iOS:** `UIApplication.shared.beginBackgroundTask(withName:
  expirationHandler:)`; the expiration handler ends the task (the Dart job
  is then likely suspended; that's the "interrupted" path).
  `endBackgroundTask` when the export finishes, fails or is cancelled.
- **Android:** no-op (the process keeps running in the background for a
  while; if it's killed, the stale-part cleanup and retry handle it). Do
  **not** add a foreground service in M6.

The Dart side wraps all of this in `AudioNative` and is tested with a fake.

## 6. Sharing, settings, entitlements

### 6.1 Share (`share_plus`)

- Add `share_plus: ^13.3.1` (latest on pub.dev: 13.3.1, published
  2026-10-01, needs Flutter ≥ 3.38.1 — <https://pub.dev/packages/share_plus>).
  Confirm in your pub cache: the API in 13.x is
  `SharePlus.instance.share(ShareParams(files: [XFile(path)], ...))`
  returning `ShareResult`; check the exact names and whether
  `sharePositionOrigin` is required on iPad.
- **Share** on ExportSuccess shares all files of the pack in one sheet.
  On iOS the sheet includes "Save to Files"; CapCut and VN may appear in it
  if they accept the file type (VN's help pages describe importing music
  shared to it via AirDrop and the Files app — <https://vlognow.me/help/getting-started/import-music/>).
- Wrap it in a `ShareService` interface (impl + fake), so widget tests
  don't hit the plugin.

### 6.2 "Open in CapCut / Open in VN" — not possible as designed

Research done for this brief (2026-11-26): neither CapCut nor VN documents
a URL scheme, intent or API that accepts an audio or video file from
another app. CapCut's help only documents template deep links
(<https://www.capcut.com/help/template-jump-exception>); the "CapCut APIs"
on GitHub are reverse-engineered draft-file tools, not a supported
hand-off. VN's help documents import from Files, AirDrop, Wi-Fi and
links, not a scheme (<https://vlognow.me/help/getting-started/import-music/>).
Opening the app without the file would leave the user to find the file
anyway.

So, on ExportSuccess: replace "Open in CapCut" / "Open in VN" with
**Share** (primary) and **Save to Files** (secondary), and keep "How to use
it in CapCut and VN" as a link (the how-to screens are M8; until then it
opens nothing or a placeholder — say which). Tell the user in the report.
Don't add `url_launcher` or any app-opening code.

### 6.3 Save to Files

**Save to Files** on ExportSuccess calls `saveToFiles(pack paths)`. Result
→ SnackBar "Saved 2 files" / nothing on cancel. The design's subtitle
"Saved to Files › KickVolt › Midnight Run" isn't true (files live in the
app's private folder until the user saves them): show
"Ready to share" instead, and after a save "Saved to the folder you
picked".

### 6.4 Settings (export defaults)

Add to `AppSettings` + `SettingsRepository` (defaults in brackets):
`defaultClickStyle` [`snap`], `defaultAudioFormat` [`wav`],
`includePreviewByDefault` [`false`], `monoGuideTrack` [`false`]. The Export
screen starts from these; changes on the Export screen apply to that
export only. The Settings screen that edits them is M8.

### 6.5 Entitlement service (stub)

`lib/core/entitlements/entitlement_service.dart` — the **one** place any
code asks "is this allowed?". No other code checks Pro status or counts
exports. Interface (keep these names; the payments milestone implements
them for real):

```dart
abstract interface class EntitlementService {
  Stream<Entitlements> get changes;
  Future<Entitlements> current();
  Future<ExportQuota> exportQuota(); // remaining this window, or unlimited
  Future<bool> canExport();
  Future<void> recordExport();       // call once per successful pack
}

class Entitlements { bool isPro; bool hasGuideVideo; bool hasUnlimitedExports; bool hasAdvancedDetection; }
```

M6 ships `UnlimitedEntitlementService` (everything allowed, quota
unlimited, `recordExport` no-op), registered in the locator. The Export
flow calls `canExport()` before starting and `recordExport()` after
success. With an unlimited quota the caption under the Export button is
hidden (always, for now); if a later service returns a finite quota it shows "Uses 1 of your 30 free
exports this week" (keep the widget ready and test both).

## 7. UI

### 7.1 Export screen (`Export.png`)

Route `ExportRoute(projectId)` from the editor's Export pill (flush the
editor's pending save first, so the export sees the latest beats).

- Header: title, "358 beats · 128 BPM · 2:48" — **beats = visible beats**
  (that's what gets exported).
- "In the pack": Song (always on), Guide track (always on), Guide video
  (disabled with "Coming soon" until M7; **no PRO badge**),
  Preview mix (toggle).
- Click sound: Snap / Rim / Blip / Kick (`KvSegmented`). Tapping one plays
  a one-shot preview of that click (render with `renderClick` into a tiny
  temp WAV, play through `AudioPlayback`) — optional; skip if it costs
  more than ~an hour and say so.
- Audio format: M4A / WAV, WAV selected by default; the warning (§4.6)
  under it when M4A is on.
- File list preview: the names and durations that will be written, "358
  clicks" for the guide.
- Primary button "Export N files", caption per §6.5.
- 0 visible beats → button disabled with "Mark some beats first".

### 7.2 Exporting (`Exporting.png`)

Big percentage, "Building your beat pack", step text ("Placing 358
clicks…", "Encoding song…"), per-file rows with progress, **Cancel**
(confirms nothing; cancels, deletes the pack folder, returns to Export).
Back/swipe = Cancel. Keep the screen awake is **not** required.

### 7.3 ExportFailed (`ExportFailed.png`)

Export screen with the error card: title "Export didn't finish" and a
message per failure:

| Failure | Message | Actions |
|---|---|---|
| `diskFull` | "Your phone ran out of space while saving the guide track. Free up about N MB, or save as M4A instead of WAV (much smaller)." (name the file that failed) | Try again · Switch to M4A and retry (only when WAV) · Cancel |
| `interrupted` | "The export stopped when KickVolt was closed. Try again and keep the app open until it's done." | Try again · Cancel |
| `encodeFailed` | "This phone couldn't make an M4A of this song. WAV works everywhere." | Switch to WAV and retry · Cancel |
| `sourceMissing` | "The song's audio file is missing. Re-import the song." | Cancel |
| other | "Something went wrong while exporting." + error in small text | Try again · Cancel |

### 7.4 ExportSuccess (`ExportSuccess.png`)

"Done", "Beat pack ready", the files with sizes and "Song · 2:48" /
"Guide track · 358 clicks", then **Share** and **Save to Files** (§6.2,
§6.3), and "How to use it in CapCut and VN". `successNotification` haptic
on arrival.

### 7.5 State

`ExportCubit` (Freezed sealed state: `editing(options, plan, quota)`,
`exporting(progress)`, `failed(failure, options)`, `done(pack)`), repository
and services injected with locator defaults. `BlocListener` for haptics
and SnackBars.

## 8. Tests required

Deterministic only: **no real-time waits**; use `fakeAsync`,
`tester.pump(duration)`, injected clocks, or `close()`. Generated audio
fades every note out (a hard cut is a real click). Write WAVs to temp
directories and **verify every output by reading the file back** from
disk, not from in-memory buffers.

| Test | Must cover |
|---|---|
| `wav_writer_test.dart` | Header fields read back with `readWavInfo` **and** byte-by-byte for the 44 header bytes (RIFF size = 36 + data bytes, `fmt ` size 16, format 1, channels, rate, byte rate, block align, 16 bits, `data` size); mono/stereo × 44.1/48 kHz; 0-frame and 1-frame files; written-frames mismatch throws and leaves no `.part`; cancel leaves no `.part` and the folder deletes immediately. |
| `guide_track_test.dart` | Song fixtures: 44.1 kHz stereo, 48 kHz mono, an odd length (e.g. 1 s + 1 frame), 22.05 kHz. **"Song and guide track have identical sample counts"**: frame count and rate of the guide read back from the file == `song.wav`'s, for stereo and mono guides. For every visible beat: the first non-zero sample at or after `beat − 1` is exactly `beat`; samples between clicks are exactly 0; peak of an isolated click within −3 dBFS ±0.1 dB; filter respected (hidden beats → silence there); beats at 0 and `frameCount − 1`; beats beyond the end clamped; overlapping clicks summed and clipped; same click on both channels; all four styles; chunk boundary straddling a click (a beat 3 samples before a chunk end). Peak buffer ≤ 4 MB for a 10-minute song (compute from chunk sizes; don't render 10 minutes if slow — say how you measured). |
| `beat_pack_plan_test.dart` | File names and sanitising (unicode, emoji/surrogates, reserved chars, empty, very long, dots); one format for the whole pack; preview included only when asked; estimate of bytes. |
| `export_repository_test.dart` | With a fake `AudioNative`: WAV pack → song file is byte-identical to `song.wav`; guide/preview as above; M4A pack calls `encodeM4a` for each file and deletes intermediate WAVs; cancel mid-render **and** cancel immediately after start (isolate still spawning) → pack folder gone, no `.part`, folder deletable, repeated 30× without a leak; ENOSPC (simulate with a writer that throws `FileSystemException(osError: OSError('', 28))`) → `diskFull`; pre-check with `freeDiskBytes` too low → `diskFull` before any file is written; native `encode_failed` → `encodeFailed`; `cleanUpStaleParts` removes stale packs and keeps finished ones; only the last 3 packs kept. |
| `export_cubit_test.dart` | Options from settings defaults; plan updates on option change; export → progress → done, `recordExport` called once, `successNotification` fired; each failure → `failed` with the right kind; retry and "switch format and retry"; `canExport() == false` → never starts (future payments path, with a fake service); cancel. |
| `entitlement_service_test.dart` | The stub: unlimited quota, `canExport` true, `recordExport` harmless. |
| Widget tests (`test/features/export/presentation/`) | Export screen: chips, M4A warning appears/disappears, file list names, disabled with 0 beats, quota caption shown for a finite quota and hidden for unlimited; Exporting: progress and Cancel; ExportFailed: copy and buttons per failure; ExportSuccess: Share calls the fake `ShareService` with all paths, Save to Files calls `saveToFiles`. |
| Pigeon round-trip | The generated Dart file is formatted; `AudioNativeClient` maps the new error codes (`encode_failed`, plus existing ones) to typed exceptions. |

## 9. Out of scope (do not build)

- Guide video (M7). The row is shown disabled ("Coming soon").
- Paywall, export counting, RevenueCat, any "Pro" label (later payments
  milestone). Only the stub service.
- Settings screen, onboarding, how-to screens (M8).
- Opening CapCut/VN; `url_launcher`.
- A foreground service or any long-running background mode.
- Changing the click synth, preview mix, detection or the editor (other
  than wiring the Export pill and flushing the save).
- Any package other than `share_plus`.

## 10. Acceptance checklist (used for verification)

Commands (must pass on the pushed branch):

```powershell
dart run build_runner build --delete-conflicting-outputs
dart run pigeon --input pigeons/audio_api.dart
dart format lib/core/audio_native/audio_api.g.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Behaviour:

- [ ] All §8 tests exist and pass on two consecutive full runs; no
      real-time waits.
- [ ] Guide track and song: identical sample rate and frame count, read
      back from the files (stereo and mono guides).
- [ ] Every click's first non-zero sample == the beat sample; −3 dBFS;
      visible beats only; clamped to `[0, frameCount − 1]`.
- [ ] WAV song is a byte-exact copy of `song.wav`; nothing is exported
      from `source.*`.
- [ ] One format per pack; M4A warning shown; WAV is the default.
- [ ] Rendering in an isolate with progress and cooperative cancel; files
      closed on every path; `.part` + rename; stale parts cleaned at start.
- [ ] Disk-full detected before and during export with the design's copy;
      interrupted export → ExportFailed with retry.
- [ ] Share via `share_plus` behind `ShareService`; Save to Files via the
      native SAF / document picker; no "Open in CapCut/VN".
- [ ] `EntitlementService` is the only gate; stub registered; Export calls
      `canExport` / `recordExport`.
- [ ] New Swift files are in `project.pbxproj`; Pigeon output regenerated
      and formatted; existing native behaviour unchanged.
- [ ] Every new file exported from its barrel; no layer bypasses.
- [ ] Only `share_plus` added.
- [ ] Branch `m6/export` pushed; not merged; no PR.

## 11. Report to hand back

1. Branch name and `git log --oneline main..HEAD`.
2. Tails of `flutter analyze` and both `flutter test` runs (pass counts).
3. The sync check: for each guide-track test case, rate / channels / frame
   count of `song.wav` vs guide (and preview), number of clicks checked,
   worst position error in samples (must be 0), measured click peak in
   dBFS.
4. Render time for a 3-minute 44.1 kHz stereo pack (WAV) on this machine
   and peak buffer size; how you measured.
5. Every `share_plus` API used (file and line in the pub cache), and every
   native API used with its Apple / Android documentation link.
6. File-level summary: new, changed, deleted (incl. `project.pbxproj`).
7. Decisions where the brief was ambiguous (file-name spacing, `_beats` vs
   design `_guide`, how-to link before M8, click audition, anything else).
8. What you could not compile, run or verify — say explicitly that the
   Swift and Kotlin code is uncompiled and nothing ran on a device.
9. Anything noticed for M7/M8/M4b.
