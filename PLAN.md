# KickVolt — Implementation Plan

Status: **approved; decisions in §8. Building M1.**

## 1. Where the repo is today

| Area | State |
|---|---|
| Toolchain | Flutter 3.47.2 stable, Dart ^3.13. Dev machine is **Windows**: Android builds work (SDK 36; some licenses not yet accepted), **iOS cannot be built or run here**. |
| Git | Folder is **not a git repo yet**. M1 starts with `git init` + a baseline commit. |
| Packages | flutter_bloc 9, freezed 4, json_serializable, get_it 9, auto_route 11, flutter_hooks, google_fonts, flutter_svg, material_ui, bloc_test, mocktail. |
| Theme | `AppTheme.dark()`, `KvColors` ThemeExtension and `KvText` match the design tokens in `design/kickvolt-design/HANDOFF.md`. Reuse as is. |
| Shared widgets | `KvButton*`, `KvIcon`, `KvSegmented`. Reuse. |
| Beat editor | A UI prototype of the core screen: top bar, timeline `CustomPainter` (ruler, sections, waveform, markers, playhead), inspector with nudge/type/delete, undo/redo, tool tabs. Fed by `DemoBeatProjectRepository` (fake 128 BPM song). Playback is a `Timer` that advances a fake playhead. 15 cubit tests pass; `flutter analyze` is clean. |
| Designs | `design/kickvolt-design/` — 31 HTML screens + PNGs + `HANDOFF.md`. Used as the visual source of truth. |

### What has to change in the existing code

1. **Timebase.** `Beat.timeMs`, `BeatProject.durationMs`, `SongSection.startMs/endMs`, `playheadMs` and `nudge(ms)` are all milliseconds. These become **integer sample indices** (`Beat.sample`, `project.sampleCount`, `section.startSample/endSample`, `playheadSample`). Milliseconds survive only in formatting helpers and in user-facing nudge amounts, which are converted to frames (see §3).
2. **Beat types.** Add `downbeat` (brief) to `beat/strong/drop`.
3. **Sections.** Today a fixed `SectionKind` enum with fixed colours. Brief wants `{start, end, name, color}`. New model: free `name` + `color` (ARGB int), with the design's five kinds offered as presets.
4. **Undo/redo.** Today: whole-list snapshots inside the Freezed state. Replace with a command stack (§5, M5); the existing nudge coalescing behaviour is kept.
5. **Peaks.** Today one `List<double>` at 10 ms bins in the entity. Moves out of the entity into a cached multi-resolution peak file (M3).
6. **Playback.** The `Timer` ticker is replaced by `just_audio` + a smoothed playhead (M3).
7. **Routing.** Editor is the initial route; becomes Home → Editor once M2 lands.

## 2. Package choices (checked on pub.dev, 2026-11-22)

| Need | Pick | Latest / last publish | Why |
|---|---|---|---|
| Platform channel | `pigeon` (dev) | 30.0.4 / 2026-11-17 | Required by the brief; typed Swift + Kotlin + Dart. |
| Playback, speed | `just_audio` | 0.10.6 / 2026-06-29 | Maintained, iOS + Android, `setSpeed`, `positionStream`, plays local WAV. Plus `audio_session` 0.2.4 for the audio category and output-latency hints. |
| FFT | `fftea` | 1.5.0+1 / 2024-07-14 | Pure Dart (so platform support is a non-issue and it runs in isolates), has STFT + windows, no deps. No release in 2 years, but it is small and feature-complete; if it gives trouble, a radix-2 real FFT is ~100 lines and I'd vendor it. |
| Files import | `file_picker` | 13.4.1 / 2026-11-21 | Actively maintained, both platforms, returns a path we copy into the project. |
| Video from camera roll | `image_picker` (`pickVideo`) | 1.2.4 / 2026-10-06 | Flutter-team package. **Spike in M1**: confirm it hands back the original asset rather than a transcoded copy on iOS; if it transcodes, do PHPicker natively behind Pigeon instead. Audio extraction itself is native (decoder reads the video's audio track). |
| Music library | **native, behind Pigeon** | — | iOS `MPMediaPickerController` → `assetURL` (nil for DRM/cloud items → clear error). Android: `MediaStore.Audio` query + our own picker list. **Not** `on_audio_query` (last release 2023-05). |
| Share / Save to Files | `share_plus` | 13.3.1 / 2026-10-01 | System share sheet on both. "Save to Files" on iOS is in the share sheet; Android gets an explicit "Save" via SAF `ACTION_CREATE_DOCUMENT` (native, small). |
| Paths | `path_provider` 2.1.6, `uuid` 4.6.0 | | Standard. |
| Settings | `shared_preferences` 2.5.6 | | A handful of scalar settings. |
| Paywall | `purchases_flutter` + `purchases_ui_flutter` 11.0.4 | 2026-11-18 | RevenueCat, both platforms (M8). |
| Permissions | `permission_handler` 13.0.2 | 2026-09-04 | Android `READ_MEDIA_AUDIO`, iOS media library. Only if the native pickers don't already cover it. |

**Rejected:** `ffmpeg_kit_flutter` (retired, per brief). `on_audio_query` (stale). `drift` (see §4). `flutter_soloud` for click preview (see M5). `hive_ce` (nothing here needs it).

## 3. Core rule: one timebase

- The **decoded PCM is the master clock**. Every beat, section bound and range is an `int` sample frame index into it. Seconds/ms appear only when formatting or converting user input (nudge ±1/±10 ms → `round(ms * sampleRate / 1000)` frames).
- **Decoded format:** 16-bit signed little-endian interleaved PCM at the file's native sample rate and channel count, written by the native decoder **directly as a WAV file** (`projects/<id>/song.wav`). That one file is: the analysis input, the playback source for `just_audio`, and the exported song. `sampleCount` = data bytes / (2 × channels).
  - Why int16, not float32: half the disk (a 10-min stereo 44.1 kHz song ≈ 106 MB vs 212 MB), the source is already lossy, and export is 16-bit anyway.
- **Guide track:** 16-bit WAV, stereo by default (mono via a setting), same `sampleRate`, same `sampleCount` as `song.wav`.
- **Required test:** song and guide track have identical sample rate and frame count (read back from the files' headers and data sizes).
- Encoder priming/padding is avoided by never re-exporting the original compressed file: the M4A option re-encodes our PCM (warn the user it may shift a few ms in some editors).

## 4. Persistence decision: one JSON file per project

`projects/<id>/project.json` (json_serializable models), written atomically (write `project.json.tmp`, fsync, rename).

Why not drift: there are no cross-project queries beyond "list them all, newest first", a project is a single document loaded and saved whole, and beats are a flat list (a 10-min song at 180 BPM ≈ 1,800 beats ≈ 40 KB JSON). A file per project also keeps everything for one project (source copy, `song.wav`, peaks, exports, json) in one folder, so delete = `rm -r`, and corruption is contained to one project. Home reads a small `index.json` cache (id, title, beat count, BPM, duration, updatedAt, peak thumbnail) rebuilt from the project files if missing.

Project folder:
```
documents/projects/<id>/
  source.<ext>      # copy of the imported file (survives the original moving)
  song.wav          # decoded PCM (master)
  peaks.bin         # multi-level min/max cache
  project.json      # the model below
  exports/          # generated packs
```

Model (Freezed + json):
```
Project { id, title, source: SourceInfo{kind: file|video|library, originalName, copiedPath, mime},
          pcmPath, sampleRate, channels, sampleCount,
          beats: [Beat{sample:int, type: beat|strong|drop|downbeat}],
          sections: [Section{startSample, endSample, name, colorArgb}],
          bpm: double?, beatPhaseSample: int?, detection: DetectionSettings{sensitivity, filter},
          createdAt, updatedAt, schemaVersion }
```

## 5. Architecture

Follows `.ai/rules/*` (features under `lib/features/`, Cubit/Bloc + Freezed, GetIt, auto_route, barrels).

```
lib/core/
  audio_native/        # Pigeon-generated API + Dart wrapper (AudioNativeClient)
  isolates/            # Job runner: Isolate.spawn + progress SendPort + cancel (kill)
  storage/             # ProjectStore (json files), SettingsStore (shared_prefs)
  audio_math/          # pure Dart: wav reader/writer, pcm reader, peaks, click synth, mixer
lib/features/
  import/              # pickers, copy, decode job, Analyzing/ImportError screens
  projects/            # Home + empty state, ProjectsCubit, ProjectRepository
  beat_detection/      # onset, tempo, DP tracker, classifier (pure Dart, isolate)
  beat_editor/         # existing feature, migrated to samples + command stack
  playback/            # PlaybackController around just_audio, smoothed playhead
  export/              # export options, job, success/failed, share/save
  settings/            # settings + latency calibration
  onboarding/, how_to/, paywall/ (+ core/entitlements/EntitlementService)
pigeons/audio_api.dart # Pigeon source
ios/Runner/Audio/*.swift, android/app/src/main/kotlin/.../audio/*.kt
```

**Native interface (Pigeon, draft):**
```dart
@HostApi() abstract class AudioHostApi {
  @async DecodeResult decodeToWav(String jobId, String inputPath, String outputWavPath); // file or video
  void cancel(String jobId);
  @async LibraryPick? pickFromMusicLibrary();          // iOS MPMediaPicker / Android MediaStore list
  @async List<LibraryTrack> listMusicLibrary();        // Android only
  @async String encodeM4a(String jobId, String wavPath, String outPath, int bitrate); // M6
  @async String saveToDocuments(String path, String suggestedName); // Android SAF create-document
  @async double outputLatencySeconds();                // AVAudioSession.outputLatency / AudioManager hint
  // M7: encodeGuideVideo(...)
}
@FlutterApi() abstract class AudioProgressApi { void onProgress(String jobId, double fraction); }
DecodeResult { sampleRate, channels, sampleCount, durationUs }
Errors: PlatformException codes `drm_protected`, `no_audio_track`, `unsupported_format`, `decode_failed`, `disk_full`, `cancelled`.
```

**Off the main isolate, with progress + cancel:** decode (native thread), peaks, detection, guide/preview/export rendering (Dart isolates via the job runner). Native jobs report progress through `AudioProgressApi`.

## 6. Milestones

Every milestone ends with: codegen if needed → `dart format .` → `flutter analyze` → `flutter test` → commit → short summary to you.

### M1 — Import and decode
- `git init`, baseline commit of the current repo.
- Pigeon setup (`pigeons/audio_api.dart`, generated Dart/Swift/Kotlin).
- **Android** (Kotlin): `MediaExtractor` select first `audio/*` track → `MediaCodec` decoder → convert output buffers to int16 (handle `KEY_PCM_ENCODING` float/16-bit, output format changes) → stream to WAV on disk, patch header sizes at end. Works for audio files and videos (same path). `MediaStore.Audio` list for the music library (`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` ≤ 32).
- **iOS** (Swift): `AVURLAsset` → `AVAssetReader` + `AVAssetReaderTrackOutput` with `kAudioFormatLinearPCM`, 16-bit int, interleaved, native rate/channels → stream to WAV. `hasProtectedContent` → `drm_protected`. `MPMediaPickerController` → `assetURL == nil` → DRM/cloud error. *Compiled by Codemagic, not locally.*
- Dart: `ImportRepository` (pick → copy into `projects/<id>/source.*` → decode → verify WAV header), `ImportCubit` with progress/cancel; ImportSheet, Analyzing (progress), ImportError screens per designs.
- Errors: unsupported, DRM, no audio track, decode failure, disk full (check free space ≥ est. WAV size before decoding; catch `ENOSPC`), cancel → delete partial folder.
- Tests: pure-Dart WAV header reader/writer; `ImportCubit` flows with mocked native API; Android instrumentation smoke test decoding a bundled short MP3/M4A (run on emulator if available).
- **Spikes reported back:** image_picker video originality on iOS; Android decoder output formats on API 24 vs 34.

### M2 — Projects and persistence
- Models above (Freezed + json), `ProjectStore` with atomic writes, `index.json` cache, schema version.
- `ProjectsCubit`, Home (list with mini waveform from the coarsest peak level, beat count, BPM, length, last edited), HomeEmpty, delete/rename.
- Routing: Home → Import → Analyzing → Editor. Editor loads real projects; demo repository removed (kept as a test fixture).
- Migrate the editor's entities and cubit to the sample timebase + new section model; existing tests ported.
- Tests: store round-trip, atomic write recovers from a stale `.tmp`, index rebuild, cubit.

### M3 — Waveform and playback
- Peaks: one pass over `song.wav` in an isolate producing min/max int16 pairs at 64, 256, 1024, 4096, 16384 frames/bucket (mono-mixed), saved to `peaks.bin` and memory-loaded as `Int16List`s (~2.2 MB total for 10 min). Below 64 frames/px (deep zoom, down to ~20 ms per screen) the painter reads the raw PCM window straight from `song.wav` (`RandomAccessFile`, small cached window).
- Painter: picks the level with ≤ 1 bucket per pixel, draws only visible columns, single `Path`/`drawRawPoints` per frame, no allocation in `paint`; overview strip uses the coarsest level. Profile in `--profile` on a device; target 60 fps.
- `PlaybackController` (just_audio + audio_session): play/pause, seek, speed 0.5/0.75/1. Playhead driven by a `Ticker`: extrapolate from the last `positionStream` sample with wall clock × speed, gently correct toward reported position (avoid backward jumps). State exposes the playhead as a sample index via a `ValueNotifier` (not the Cubit) so 60 fps updates don't rebuild the widget tree.
- Tests: peak computation vs brute force, level selection, playhead smoothing maths.

### M4 — Beat detection (pure Dart, isolate)
- Mono mixdown → STFT (fftea, 2048 window, 512 hop, Hann) → log-magnitude (`log(1 + C·|X|)`) → half-wave-rectified spectral flux → detrend/normalise → onset envelope.
- Tempo: autocorrelation of the envelope over 40–220 BPM, weighted by a log-Gaussian prior centred on 120 BPM; compare the peak with its ×2 and ×½ candidates (and ×3/2) and pick by prior-weighted score; report BPM to 0.1.
- Tracker: Ellis 2007 dynamic programming (`score = onset + α·max(prev − λ·log²(Δ/period))`), backtrack. Then snap each beat to the strongest onset peak within ±1/8 period, and **refine to sample accuracy** by searching a short high-resolution energy-rise function (64-frame hop) around the hop-level peak — needed because a 512 hop at 44.1 kHz is 11.6 ms, which by itself can't meet ±10 ms.
- Classify: strong = onset strength ≥ percentile (driven by sensitivity); drops = sustained (≥ 2 bars) jump in low-band (<150 Hz) energy vs the previous 4 bars; downbeats = best of 4 phases by summed low-band onset strength (`// HEURISTIC` comment). Optional: rough sections from drop/energy changes.
- Filter is a pure view: `every | strong | drops | every2nd | every4th` → exported/displayed subset; data untouched.
- Isolate job with progress + cancel; Auto sheet (sensitivity, filter, live estimate, Detect), EditorDetectFailed when no steady tempo (low autocorrelation confidence).
- Tests: synthetic click tracks at 90/120/128 BPM, clean and with noise (white noise at e.g. −20 dB and a quiet pad), mono and stereo, 44.1 and 48 kHz: every detected beat within ±10 ms of truth, BPM within ±1; also half/double-tempo cases.

### M5 — Beat editor
- Markers per type (beat, strong, drop, downbeat, selected) on the M3 painter; tap select; floating info card.
- **Command stack:** `EditCommand { apply(beats), invert }` — Add, Delete, Move(nudge, coalesced like today), SetType, ShiftAll, ClearRange(restores removed beats), Snap, SetSections, ReplaceAll (re-detect). All edits go through it; capped history; undo/redo in the top bar.
- Nudge ±1/±10 ms, delete, change type; haptics per HANDOFF (selectionClick on place/snap/nudge, warning on delete/clear, success on detect/export, global off switch).
- Tap pad: beat at `currentPlaybackSample − latencyFrames`, latency from calibration.
- Latency calibration (Settings): play a click at a known tempo, collect ≥ 16 taps, drop outliers, store median offset; include `outputLatency` from the platform when available; detect Bluetooth route (via audio_session device info) and warn that BT adds 150–300 ms and must be calibrated with the same headphones.
- Snap to grid (BPM + phase), bulk shift, clear range with drag handles, sections as coloured regions (add/rename/recolour/delete).
- **Click preview — pre-rendered preview mix.** When Clicks is on, render `song + clicks` (filtered beats) to `preview.wav` in an isolate and swap the `just_audio` source at the current position; after edits, re-render debounced (~300 ms) and swap when done. Why: clicks are placed at exact sample indices in the same buffer as the song, so they are sample-accurate by construction regardless of device output latency or speed changes (0.5× stays in sync — a separate click player would drift under time-stretching). A low-latency engine (e.g. SoLoud) scheduling clicks against a second stream can't guarantee sample sync between two players. Cost: a short delay (~0.3–1 s for a 3-min song) before an edit is audible, and disk for one extra WAV; I'll show a small "updating clicks" indicator.
- Widget tests: select → nudge → undo → redo; delete + undo; tap-mark; clear range + undo.

### M6 — Export
- Pure-Dart WAV writer (RIFF/WAVE, `fmt ` PCM 16-bit, `data`), streaming in chunks.
- Click synth: 4 styles (Snap, Rim, Blip, Kick), 5–10 ms exponentially decaying burst, peak −3 dBFS, onset exactly at the beat's sample index (first non-zero sample = beat sample), overlapping clicks summed and clipped.
- Outputs: `<title>_song.wav` (copy of our PCM WAV, or M4A via native AAC encoder with a sync warning), `<title>_beats.wav` (guide), optional `<title>_preview.wav`. Titles sanitised for file names.
- Share via share_plus; "Save to Files" (iOS share sheet / Android SAF). CapCut/VN: I'll check whether either documents a URL scheme or intent that **accepts a file**; if not (expected), the design's "Open in CapCut/VN" becomes share-sheet + How-to guide, and I'll tell you.
- Interrupted exports: export runs in an isolate writing to `.part` files, renamed at the end; on app pause the job continues while the OS allows; if it's killed, partial files are removed on next launch and the Export screen offers retry (ExportFailed).
- Free-quota check through `EntitlementService` (stubbed as "unlimited" until M8).
- Tests: header fields, exact frame counts (song == guide), click positions found by reading the file back, peak level ≈ −3 dBFS, filter respected.

### M7 — Guide video *(I will ask you before starting)*
- Native H.264 MP4, 30 fps, black frames, white flash + beat number on beat frames (frame = `floor(sample * 30 / sampleRate)`), guide track muxed as AAC. iOS `AVAssetWriter` + pixel buffers drawn with CoreGraphics; Android `MediaCodec` (surface input, Canvas drawing) + `MediaMuxer`.

### M8 — Onboarding, how-to, settings, paywall
- Onboarding (Main/Onboarding2/Onboarding3), Coach marks 1–3, HowToCapCut/HowToVN.
- Settings: default click style, export formats, mono/stereo guide track, detection sensitivity, haptics, latency calibration (dark theme only, no theme switch).
- `EntitlementService` (single source of truth): `canExport()`, `recordExport()`, `hasGuideVideo`, `hasUnlimitedExports`, `hasAdvancedDetection`; free tier N exports / rolling 7 days, N from config (default 30). RevenueCat `purchases_flutter` behind it; Paywall screen per design.

## 7. Testing and verification limits

- Pure-Dart audio code (WAV, peaks, detection, click synth, mixer, command stack) gets unit tests and runs on Windows.
- Android native code: compiled here; exercised on an emulator/device if one is attached.
- **iOS native code cannot be compiled or run on this Windows machine.** Codemagic compiles it; runtime behaviour on iOS is unverified until you run a build on a device.
- 60 fps waveform claim needs a profile build on a real device; I'll measure on Android and report numbers.

## 8. Decisions (answered 2026-11-22)

1. **iOS verification:** Codemagic. `codemagic.yaml` builds iOS (unsigned, simulator/`--no-codesign`) and Android on every push, so the Swift side is at least compiled in CI. Tests run there too.
2. **App ID:** `com.kickvolt.app` (Android `applicationId`/namespace, iOS bundle ID).
3. **Min OS:** iOS 15, Android API 24.
4. **Click styles:** four — Snap, Rim, Blip, Kick.
5. **Downbeat marker:** strong-beat style with a small "1" pill in a lighter volt.
6. **Free tier:** **30 exports per rolling 7 days** (a whole beat pack = one export), N configurable. All copy uses 30, overriding the designs' "3": Paywall row "Unlimited exports — Free: 30 a week", Export button caption "Uses 1 of your 30 free exports this week" (with the live remaining count).
7. **Theme:** dark only. Settings shows no theme switch for now (the theme row is dropped from the Settings screen).
8. **Guide track:** **stereo** 16-bit by default (same click on both channels, same sample rate and frame count as the song), with a Settings toggle "Mono guide track (smaller file)".

## 9. Progress

### M1 — Import and decode: done (2026-11-22)
- App ID `com.kickvolt.app`, Android minSdk 24, iOS 15. `codemagic.yaml` added (analyze, tests, generated-code check, unsigned Android + iOS builds).
- Pigeon API `pigeons/audio_api.dart` → `AudioHostApi` (decode, cancel, music library, content-URI copy, free space) + `AudioProgressApi`.
- Android: `WavDecoder.kt` (MediaExtractor + MediaCodec → 16-bit WAV, float output handled, >2 ch → first two), MediaStore library list with `READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` (≤ 32).
- iOS: `WavDecoder.swift` (AVAssetReader, async property loading, `hasProtectedContent` → DRM error), `MPMediaPickerController` (nil `assetURL` → DRM or not-downloaded error). Library songs are decoded straight from the `ipod-library://` URL; `song.wav` is their durable copy.
- Dart: `ImportRepository` (copy → decode → read the WAV header back and cross-check), `SourcePickerCubit`, `ImportCubit`, Home empty state, Import sheet, Analyzing (decode progress, cancel), import error dialog, Android library list.
- Spike: `image_picker_ios` uses PHPicker with `preferredAssetRepresentationMode = .current`, so videos arrive untranscoded.
- **Not verified yet:** neither native side has been compiled. iOS needs Codemagic; the local Android build was blocked by a slow Gradle distribution download. No on-device test of decode yet.
- Until M2, a successful import opens the editor with the demo song (projects aren't persisted yet).

### M2 — Projects and persistence: done (2026-11-23)
- Built by a separate agent from `docs/handoff/M2-projects-and-persistence.md`, verified here, then merged.
- `projects` feature: `Project` entity in sample indices, one `project.json` per project plus `index.json` for Home, all written via `.tmp` + rename; `overview.bin` (~10 ms max-abs bins) computed in an isolate.
- Import now creates the project; the editor loads/saves real projects (debounced, flushed on close) and handles 0 beats / unknown BPM. Home shows the project list with rename and delete.
- Fix added during verification: saves are serialized (editor queue + repository locks) so an older edit can't overwrite a newer one.
- **Known small issues for later:** beats and the playhead can sit at `sampleCount` (one past the last frame); clamp to `sampleCount - 1` before M6 export. Home rebuilds the index while a project folder has no `project.json` yet (slower, not wrong).
- **Not verified on a device.** The local Android build is blocked by a corrupt Gradle download (`gradle-9.3.1-all.zip` is truncated at 150 MB).

### M3 — Waveform and playback: done (2026-11-23)
- **Packages:** `just_audio` 0.10.6 (AVPlayer / ExoPlayer, local files, `setSpeed`, `PlaybackEvent.updatePosition/updateTime` anchors) and `audio_session` 0.2.4 (music session; pause on interruptions and on headphones unplugged).
- **Peaks:** `peaks.bin` holds mono min/max at 64/256/1024/4096/16384 frames per bucket (~2.4 MB for 10 min at 48 kHz). It's built in an isolate during import, alongside `overview.bin`, or on first open for M2-era projects. Below 64 frames per bar the painter reads exact samples through `PcmWindowLoader` (small async reads from `song.wav`).
- **Zoom:** from the whole song across the screen down to 20 ms per screen width (about 1,500× at 390 px).
- **Playback:** `PlayheadController` + `PlayheadClock` give a smoothed, never-backwards playhead updated once per display frame. Small drift is blended in over 250 ms; seeks and stalls jump. The playhead and zoom are `ValueListenable`s that the painters listen to directly, so playing or pinching doesn't rebuild widgets. Dragging scrubs the playhead and seeks the audio on release (pausing and resuming around the drag).
- **Painter:** columns sit on a fixed frame grid (no shimmer while scrolling); bars are drawn with `drawRawPoints`; paints and text layouts are cached; markers simplify and thin out when they're closer than 14 px / 4 px; ruler has sub-second steps.
- Also fixed: the playhead and new beats are clamped to `sampleCount - 1`.
- **Measured:** recording a frame takes 0.5–2.2 ms in a debug (JIT) test build across all zoom levels with the demo song playing (budget at 60 fps: 16.7 ms). Not included: GPU raster time and real-device profile numbers.
- **Not verified:** actual audio playback, the smoothing feel and 60 fps on a device. Still no Android build here (corrupt Gradle download), no device attached; iOS via Codemagic only.
