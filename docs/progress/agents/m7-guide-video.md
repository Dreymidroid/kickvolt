# Agent log — M7 guide video

- **Branch:** `m7/guide-video` (from `main` after M8 is merged), own git worktree.
- **Spec:** `docs/handoff/M7-guide-video.md`.
- **Go-ahead:** the user asked on 2026-11-27 to "complete the app"; the lead
  treats that as the "go" that `PLAN.md` §6 M7 requires, so the brief's
  "stop and ask first" step is skipped.
- **Extra scope beyond the brief:** M8 landed first, so the agent also
  turns on the M7-dependent bits M8 left off: the Video tile in the
  onboarding beat-pack illustration (no PRO badge), the Settings rows "Video
  format (MP4)" and "Guide video in packs", and the Export option that M6
  showed as "Coming soon".
- **Device:** Android verification on the connected Xiaomi 23106RN0DA
  (Android 14) is done by the lead/test agent after the merge; iOS compiles
  only on Codemagic.

## Activity

<!-- The agent appends dated entries below: what it did, commands, results, open issues. -->

### 2026-11-27 — setup

- The worktree started on `main` (6fa6af5), not on M8. Created
  `m7/guide-video` from `m8/onboarding-settings` (dd441d4, = origin), which
  contains M1–M6, M4b and M8. `lib/features/export/` (M6) present.
- The checkout had CRLF working files (`core.autocrlf=true`, index is LF);
  normalised the working tree to LF so scripted edits match. No content diff.

### 2026-11-27 — frame plan (pure Dart, tests first)

- `lib/features/export/domain/guide_video_plan.dart`: `planGuideVideo`,
  `guideVideoTotalFrames` (`(frameCount*30 + rate - 1) ~/ rate`),
  `guideVideoFrameForSample` (`sample*30 ~/ rate`), `estimateGuideVideoBytes`
  ((2 Mbps video + 192 kbps AAC) × duration + 10%), constants (30 fps,
  1080×1920, 2 Mbps).
- `test/features/export/domain/guide_video_plan_test.dart`: 23 exact
  totalFrames cases (44.1/48/22.05/32 kHz, exact frame multiples and one
  sample over, odd lengths, 0/1 sample), boundary test at 8 rates × 9 frames
  (last sample of k → k, first of k+1 → k+1), first/last sample beats,
  clamping, two beats in a frame (later number wins), duplicates, 1-based
  parallel numbers, empty → black video, and a seeded property test (400
  random songs, >1000 flashes): **0 flash frames whose span misses its
  beat**. Plus `planBeatPack` with video (file order, `.mp4` in M4A packs,
  filter respected, disk estimate).

### 2026-11-27 — Pigeon, repository, cubit, UI

- Pigeon: `GuideVideoSpec`, `encodeGuideVideo(jobId, spec)`, and nullable
  `MediaInfo.hasVideo/videoWidth/videoHeight/videoFrameCount/videoDurationUs`.
  `dart run pigeon --input pigeons/audio_api.dart` →
  `dart format lib/core/audio_native/audio_api.g.dart` ("Formatted 1 file").
- `ExportRepositoryImpl`: video gated by `EntitlementService.current()
  .hasGuideVideo` (injected; locator passes the service). Order
  guide → video → song → preview. WAV pack: video encodes from the staged
  `<Title>_beats.wav.part`. M4A pack: guide WAV → video → guide M4A → WAV
  deleted. Video progress weight 2× an audio file. After rename, verified
  with `probeMedia` (`guideVideoVerificationProblem`): has video, frame
  count == plan, video duration within one frame of the song (exact integer
  compare), audio at the guide's rate/channels. `encode_failed` on the video
  → `ExportFailure(encodeFailed, failedFile: video)`: "This phone couldn’t
  make the guide video. Export without it?" + "Export without video".
- `ExportCubit`: `videoAllowed` in editing/failed states, `setIncludeVideo`,
  `onVideoLocked` (no-op), `retryWithoutVideo`, default from
  `AppSettings.includeVideoByDefault`.
- UI: Export row is a toggle (locked = dimmed, tap → `onVideoLocked`; no PRO,
  no paywall); file list "2:48 · 358 flashes"; ExportSuccess "Guide video ·
  358 flashes · size" (+ "720×1280" when the encoder fell back).
- M8 bits turned on: Onboarding2 Video tile (1–6, beat 3 white; no PRO),
  Settings "Video format · MP4" (read-only) and "Guide video in packs"
  (`INCLUDE_VIDEO_BY_DEFAULT`, persisted). `first_run_routing_test` now
  expects `find.text('Video')` findsOneWidget (deliberate).
- Applied the lead's fix to `settings_screen_test.dart` (no
  `addTearDown(cubit.close)`, `toggle(label)` Semantics finder).

### 2026-11-27 — native

- Android `GuideVideoEncoder.kt`: **Surface input + EGL14/GLES20**; per
  frame `EGLExt.eglPresentationTimeANDROID(k * 1e9 / fps)` then
  `eglSwapBuffers` (no `lockCanvas`, no clock). Looks drawn with
  `Canvas`/`Typeface.DEFAULT_BOLD` into a `Bitmap`, uploaded with
  `GLUtils.texImage2D/texSubImage2D` only when the look changes. H.264 via
  `MediaCodecList.findEncoderForFormat` + `COLOR_FormatSurface`,
  `KEY_FRAME_RATE` 30, `KEY_I_FRAME_INTERVAL` 1, `KEY_BIT_RATE`; falls back
  to 720×1280. Audio: M6 `M4aEncoder` → temp .m4a → `MediaExtractor` samples
  interleaved into `MediaMuxer` (`MUXER_OUTPUT_MPEG_4`). Codec, EGL, surface,
  muxer, extractor released in `finally`; output deleted on failure; cancel
  via the job flag. `M4aEncoder.probeMedia` now reports the video track
  (frames counted with `MediaExtractor.advance`).
- iOS `GuideVideoEncoder.swift` (+ `project.pbxproj`: file ref
  `4B1D0A…0105`, build file `4B1D0A…0205`, Audio group, Sources phase):
  `AVAssetWriter(.mp4)`, H.264 input (`AVVideoAverageBitRateKey`,
  `AVVideoMaxKeyFrameIntervalKey` 30), `canApply` fallback to 720×1280,
  `AVAssetWriterInputPixelBufferAdaptor` pool buffers drawn with
  CoreGraphics + CoreText (`CTFontCreateUIFontForLanguage(.emphasizedSystem)`),
  cached per look, appended at `CMTime(value: k, timescale: 30)`; AAC audio
  input fed from `AVAssetReader` (M6 settings); `endSession(atSourceTime:
  totalFrames/30)`; `cancelWriting()` on cancel; temp `.mp4` + hard-linked
  `.wav` (AVURLAsset needs extensions). `M4aEncoder.probeMedia` counts video
  samples with a passthrough `AVAssetReaderTrackOutput`.

### Decisions where the brief was ambiguous

- Number size: 40% of the height overflows a 1080-wide frame for 3 digits
  (~1270 px), so the number is 40% of height **capped to 90% of the width**.
- "Duration within one frame" is checked on the **video track**; AAC pads to
  1024-sample packets (46 ms at 22.05 kHz > one frame), so the audio track is
  checked for presence/rate/channels, not duration.
- "30 fps" verified as `videoFrameCount == totalFrames` plus the duration.
- The video is planned only together with the guide track (it needs its WAV).
- Onboarding tile numbers are 1…6 (the video counts beats sequentially), not
  the design's 1 2 3 4 1 2.
- Two beats in one frame: one flash, later number (as the brief).
