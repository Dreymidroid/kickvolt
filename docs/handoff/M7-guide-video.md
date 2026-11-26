# Handoff: M7 — Guide video

Self-contained brief for an agent implementing milestone M7 of KickVolt.
Part 1 is the prompt to paste. Parts 2–11 are the spec. Verification
against §10 happens afterwards, in a separate session.

**Preconditions:**
- M6 (`m6/export`) is verified and merged into `main`. M7 adds one file to
  the M6 beat pack and reuses its M4A encoder, export job and
  `EntitlementService`.
- **The user must say "go" before any M7 code is written** (`PLAN.md` §6
  "M7: I will ask you before starting"). The prompt below makes the agent
  stop and ask first.

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M7 (Guide video)** of KickVolt, a
> Flutter app in the current repository
> (`https://github.com/Dreymidroid/kickvolt`, branch `main`).
>
> **Stop before writing any code.** First read the documents below, then
> reply to the user with a short plan (the native approach you picked on
> each platform from §5, video size, and anything in this brief you think
> is wrong) and ask: "OK to start M7?" Write code only after the user
> answers yes in this conversation. If they say no or want changes, follow
> their answer.
>
> Read these in full:
> 1. `docs/handoff/M7-guide-video.md` (this brief — it is the spec)
> 2. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 3. `PLAN.md`, especially §3 "one timebase", §5, §6 "M6" and "M7", §8 and
>    §9 (what M1–M6 built, known limits)
> 4. `docs/handoff/M6-export.md` (the export pipeline you extend)
> 5. The code listed in §3 of the brief.
>
> Then, once the user has said yes:
> - Check that `main` contains M6 (`lib/features/export/`). If not, stop
>   and say so.
> - Create a branch `m7/guide-video` from `main`.
> - Implement §4–§7. Do **not** do anything in §9 (out of scope).
> - **No new packages.** Native code uses only documented platform APIs
>   (AVFoundation / CoreVideo / CoreGraphics on iOS; MediaCodec,
>   MediaMuxer, MediaFormat and EGL/GLES or `Image` on Android). For each
>   API you call, name its Apple / Android reference page in your report.
>   Do not invent APIs; if something you need isn't there, say so instead
>   of working around it.
> - Write the pure-Dart tests in §8 **first** (frame plan), then make them
>   pass. Then the cubit and widget tests.
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart run pigeon --input pigeons/audio_api.dart`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be
>   clean/green. Run `flutter test` at least twice.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report in §11.
>
> If the brief is ambiguous, pick the option that keeps the video exactly
> as long as the song and each flash on the frame that contains its beat;
> note the decision in your report and carry on. Do not loosen a test
> tolerance to make it pass; if a check can't be met, say so in the
> report. Report honestly what you could not compile or run.

---

## 2. Context

KickVolt exports a **beat pack** (song + click guide track, optional
preview mix) for CapCut/VN; M6 built that. M7 adds the **guide video** (free for now; the design marks it Pro, but
there are no payments yet and no "Pro" label is shown):
a black clip, exactly as long as the song, that flashes white and shows the
beat number on every beat, with the guide track as its audio. The user
drops it on the timeline at 0:00 and cuts to the flashes by eye, or runs
auto-beat on its audio.

Done so far: M1–M6 (see `PLAN.md` §9). Relevant pieces:
- Pigeon `AudioHostApi` with `encodeM4a`, `probeMedia`, `cancelJob`,
  `beginBackgroundWork` (M6) and the native job/cancel pattern
  (`AudioHostApiImpl.kt` with coroutines, `AudioHostApiImpl.swift`).
- `ExportRepository` / `planBeatPack` / `ExportCubit` (M6) — the job
  pipeline, `.part` + rename, disk checks, failure kinds.
- `EntitlementService` (M6 stub: everything allowed; a later payments
  milestone replaces it).
  Guide video is gated by `hasGuideVideo`.

**Core rule:** the beat → frame mapping is computed **in Dart** from integer
sample indices and handed to native code as integers. Native code renders
exactly what it's told; it never re-derives timing from seconds or a
wall clock.

Environment notes:
- Windows dev machine; no Android device/emulator; local Android build is
  broken; iOS compiles only on Codemagic. **The native encoders can't be
  compiled or run here.** The Dart frame plan and Dart integration are the
  testable part and must be fully tested. Say plainly in the report that
  the Swift and Kotlin code is uncompiled.
- New Swift files must be added to `ios/Runner.xcodeproj/project.pbxproj`
  by hand (see how M1/M6 added files to the `Audio` group).

## 3. Existing code you'll touch

| Path | What it is today |
|---|---|
| `pigeons/audio_api.dart` (+ generated Dart/Kotlin/Swift) | Add `encodeGuideVideo` (§5). Regenerate, then `dart format lib/core/audio_native/audio_api.g.dart` (CI diffs it). |
| `lib/core/audio_native/audio_native_client.dart` | `AudioNative` wrapper + error mapping; extend. |
| `android/app/src/main/kotlin/com/kickvolt/app/audio/` | `AudioHostApiImpl.kt`, `WavDecoder.kt`, `M4aEncoder.kt` (M6). Add `GuideVideoEncoder.kt`. |
| `ios/Runner/Audio/` | `AudioHostApiImpl.swift`, `WavDecoder.swift`, `M4aEncoder.swift` (M6). Add `GuideVideoEncoder.swift` + pbxproj entries. |
| `lib/features/export/` (M6) | `ExportOptions`, `planBeatPack`, `ExportRepository`, `ExportCubit`, Export/Exporting/Failed/Success screens. Guide video row is disabled ("Coming soon"). |
| `lib/core/entitlements/entitlement_service.dart` (M6) | `Entitlements.hasGuideVideo`. |
| `lib/features/beat_detection/domain/beat_filter_view.dart` | `visibleBeatIndices(project)` — the video uses the same visible beats as the guide track. |

## 4. Frame plan (pure Dart)

`lib/features/export/domain/guide_video_plan.dart`:

```dart
class GuideVideoPlan {
  final int fps;            // 30
  final int width, height;  // §4.3
  final int totalFrames;
  final Int32List flashFrames;  // ascending, unique
  final Int32List beatNumbers;  // parallel to flashFrames, 1-based
}
GuideVideoPlan planGuideVideo({required int sampleRate,
    required int frameCount, required List<int> visibleBeatSamples});
```

### 4.1 Timing

- `fps = 30` (constant frame rate).
- `totalFrames = ceil(frameCount × 30 / sampleRate)` in integer maths
  (`(frameCount * 30 + sampleRate - 1) ~/ sampleRate`). The video track is
  at most one frame (33 ms) longer than the audio; the muxed audio is the
  exact guide track, so the file's audio duration equals the song's.
- Beat → frame: `floor(sample × 30 / sampleRate)` (integer division), so
  the flash is on the frame whose time span contains the beat.
- Beats are the visible beats, sorted, unique, clamped to
  `[0, frameCount − 1]`. Two beats in one frame → one flash; the number
  shown is the **later** beat's number, and the earlier number is skipped
  (document this; at 30 fps it only happens above 1800 BPM-equivalent
  spacing, i.e. double markers).
- Beat number = 1-based index in the visible list (what the user sees as
  "BEAT n / N" in the editor's playing panel).

### 4.2 What each frame looks like

- Black (`#000000`) background.
- **Flash frame** (the beat's frame): full white frame with the beat
  number in black, large, centred.
- **The next frame:** black with the number in white (a 2-frame flash is
  more visible to editors' scene detection, but keep the white frame to
  exactly one so the cut point is unambiguous).
- Between beats: black, with the last beat number in white at 40%
  opacity, so a paused frame shows where you are. Before the first beat:
  plain black.
- Number font: the platform's bold system font (no font assets), sized to
  ~40% of the frame height for up to 3 digits, shrinking for 4+.

### 4.3 Size and encoding

- 1080 × 1920 portrait (TikTok/Reels/Shorts), H.264, constant 30 fps,
  keyframe every 1 s (GOP 30), bitrate ~2 Mbps (mostly-black frames
  compress to almost nothing). If the device's encoder refuses 1080×1920,
  fall back to 720 × 1280 and say so in the result.
- Audio: the guide track (from M6's renderer, same format rule as the
  pack: WAV source → AAC in the MP4; the MP4 container always has AAC
  audio).
- File: `<Title>_guide.mp4` in the pack folder, `.part` + rename like the
  audio files.

## 5. Native: `encodeGuideVideo`

```dart
class GuideVideoSpec {
  int fps; int width; int height; int totalFrames;
  List<int> flashFrames; List<int> beatNumbers;
  String audioWavPath;   // the pack's guide track (WAV) — already rendered
  String outPath;
  int videoBitrate; int audioBitrate;
}
/// Fails with `disk_full`, `encode_failed`, `cancelled`. Progress via
/// AudioProgressApi (fraction of totalFrames written).
@async
MediaInfo encodeGuideVideo(String jobId, GuideVideoSpec spec);
```

Every frame's presentation time is `frameIndex / fps` exactly — set it
explicitly from the frame index, never from the system clock.

### 5.1 iOS

`AVAssetWriter` (`.mp4`), video `AVAssetWriterInput` with
`AVVideoCodecType.h264`, width/height, `AVVideoCompressionPropertiesKey`
(`AVVideoAverageBitRateKey`, `AVVideoMaxKeyFrameIntervalKey`),
`expectsMediaDataInRealTime = false`, plus an
`AVAssetWriterInputPixelBufferAdaptor`. Draw each distinct frame look into
a `CVPixelBuffer` from the adaptor's pool with CoreGraphics/CoreText;
cache identical frames (black, "white with N", "black with N") rather than
redrawing. Append with `CMTime(value: frameIndex, timescale: 30)`.
Audio: a second input fed by AAC-encoding the guide WAV (reuse M6's
encoder code path). Background queue, `requestMediaDataWhenReady`,
`cancelWriting()` on cancel, delete the output on failure. Wrap in M6's
`beginBackgroundWork`.

### 5.2 Android

`MediaCodec` H.264 encoder (`MediaFormat.MIMETYPE_VIDEO_AVC`,
`KEY_FRAME_RATE` 30, `KEY_I_FRAME_INTERVAL` 1, `KEY_BIT_RATE`,
`KEY_COLOR_FORMAT`) + `MediaMuxer` (`MUXER_OUTPUT_MPEG_4`) with an AAC
audio track (reuse M6's AAC encoder code).

**You must be able to set each frame's presentation time.** Pick one and
justify it in the report:
- **Surface input + EGL:** `createInputSurface()`, an EGL context on that
  surface, draw with GLES (or upload a `Bitmap` drawn with `Canvas` as a
  texture), set the time with `EGLExt.eglPresentationTimeANDROID` before
  `eglSwapBuffers`. This is the approach used by the AOSP/Grafika encoder
  samples.
- **ByteBuffer/Image input:** `COLOR_FormatYUV420Flexible`,
  `getInputImage(index)`, write Y/U/V planes (the frames are black, white
  and a number, so precompute the few distinct frames as YUV), and queue
  with `presentationTimeUs = frameIndex * 1_000_000L / 30`.

Do **not** use `Surface.lockCanvas` / `lockHardwareCanvas` on the encoder
surface: you can't set presentation times that way, so the video would
follow the wall clock. Cancel via the existing coroutine job; release
codec, muxer and EGL in `finally`; delete the output on failure.

## 6. Export integration

- Export screen: the Guide video row becomes a toggle when
  `hasGuideVideo` is true (always, with the M6 stub). When false (only
  after payments exist), the row is disabled and calls one `onLocked`
  callback that does nothing today. No PRO badge, no paywall.
- `ExportOptions.includeVideo`; `planBeatPack` adds `<Title>_guide.mp4`
  after the guide track (the video needs the guide WAV; if the pack format
  is M4A, render the guide WAV first, encode the video from it, then
  encode the guide M4A, then delete the WAV).
- Progress weights by work (video ≈ frames; give it a fair share).
- Disk estimate: bitrate × duration + 10%.
- Failure kinds: reuse M6's (`diskFull`, `encodeFailed` with copy "This
  phone couldn't make the guide video. Export without it?" + button
  "Export without video", `interrupted`).
- ExportSuccess lists the video ("Guide video · 358 flashes").
- Verify after encoding with `probeMedia`: duration within one frame of
  the song, has audio, has video at 30 fps.

## 7. Settings

The Settings screen's "Video format: MP4" row is M8; nothing to add here
beyond `ExportOptions.includeVideo` remembered as `includeVideoByDefault`
in `AppSettings` (default `false`).

## 8. Tests required

Deterministic only: no real-time waits. Verify outputs by reading files
back where a file is produced.

| Test | Must cover |
|---|---|
| `guide_video_plan_test.dart` | `totalFrames` for 44.1/48/22.05 kHz and odd lengths (exact integer maths, incl. `frameCount` an exact multiple of a frame and one sample over); beat → frame at boundaries (a beat on the last sample of frame k → k; first sample of k+1 → k+1); first/last sample beats; two beats in one frame → one flash with the later number; filter respected; numbers 1-based and parallel; empty beat list → black video of the right length. Property test on a seeded RNG: every flash frame's time span contains its beat. |
| `export_repository_test.dart` (extend) | With a fake `AudioNative`: video included only when asked and entitled; spec passed to `encodeGuideVideo` equals `planGuideVideo` output and points at the rendered guide WAV; M4A pack order (guide WAV → video → guide M4A → WAV deleted); `encode_failed` → failure with "export without video"; cancel cancels the native job and removes the pack folder. |
| `export_cubit_test.dart` (extend) | Toggle allowed with `hasGuideVideo`; with a fake service returning false the row is disabled and calls `onLocked`; retry without video. |
| Widget tests | Export screen video row on/off/locked; ExportSuccess lists the MP4. |
| Pigeon | Generated file formatted; new error copy mapped. |

The on-device checks (actually decoding the MP4 and checking flash frames)
belong to `docs/handoff/E2E-testing.md`; list in your report what an
integration test should assert.

## 9. Out of scope (do not build)

- Paywall, RevenueCat, real entitlement checks, PRO labels (later
  payments milestone).
- Landscape/square sizes, colours or fonts the user can choose.
- Video preview playback inside the app.
- Any package (no `ffmpeg_kit`, no video plugins).
- Changes to the click synth, guide track or detection.

## 10. Acceptance checklist (used for verification)

```powershell
dart run build_runner build --delete-conflicting-outputs
dart run pigeon --input pigeons/audio_api.dart
dart format lib/core/audio_native/audio_api.g.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

- [ ] The user said yes before any code was written (quote it in the report).
- [ ] All §8 tests exist and pass on two consecutive full runs.
- [ ] Frame plan is pure Dart, integer maths, tested; native code receives
      frame indices and only renders.
- [ ] Presentation times set from frame indices on both platforms (no
      wall clock, no `lockCanvas`).
- [ ] Audio track is the guide track; video duration within one frame of
      the song (checked with `probeMedia` after encoding).
- [ ] Gated by `EntitlementService.hasGuideVideo` only.
- [ ] Cancel, disk full, encoder failure handled; `.part` + rename; codec,
      muxer, writer released on every path.
- [ ] New Swift files in `project.pbxproj`; Pigeon regenerated and
      formatted; no new packages.
- [ ] Branch `m7/guide-video` pushed; not merged; no PR.

## 11. Report to hand back

1. The user's go-ahead (quote) and the plan you sent before it.
2. Branch name and `git log --oneline main..HEAD`.
3. Tails of `flutter analyze` and both `flutter test` runs.
4. Frame-plan check: cases run, worst "flash frame span doesn't contain
   beat" count (must be 0).
5. Native approach per platform and every API used, with documentation
   links; which Android input path you chose and why.
6. File-level summary (incl. `project.pbxproj`).
7. Decisions where the brief was ambiguous.
8. What you could not compile, run or verify — say explicitly that the
   native code is uncompiled and nothing ran on a device.
9. What the E2E integration test for the video should assert.
