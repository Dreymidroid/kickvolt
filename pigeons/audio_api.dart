// Pigeon source for the native audio bridge. Regenerate (then format) with:
//   dart run pigeon --input pigeons/audio_api.dart &&
//     dart format lib/core/audio_native/audio_api.g.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/audio_native/audio_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/kickvolt/app/audio/AudioApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.kickvolt.app.audio'),
    swiftOut: 'ios/Runner/Audio/AudioApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'kickvolt',
  ),
)
/// What the native decoder wrote. `frameCount` is the number of sample
/// frames (one sample per channel) in the WAV's data chunk; it is the
/// project's master timebase.
class DecodeResult {
  DecodeResult({
    required this.sampleRate,
    required this.channels,
    required this.frameCount,
  });

  int sampleRate;
  int channels;
  int frameCount;
}

/// A song from the device's music library.
class LibraryTrack {
  LibraryTrack({
    required this.id,
    required this.title,
    required this.uri,
    required this.durationMs,
    this.artist,
  });

  String id;
  String title;
  String? artist;
  int durationMs;

  /// Android: a `content://` URI. iOS: the item's `ipod-library://` asset
  /// URL, which the decoder can read directly.
  String uri;
}

/// Duration and format of a media file as the platform sees it. The audio
/// fields describe the first audio track; the `video*` fields are set only for
/// files with a video track (the M7 guide video).
class MediaInfo {
  MediaInfo({
    required this.sampleRate,
    required this.channels,
    required this.durationUs,
    this.frameCount,
    this.hasVideo,
    this.videoWidth,
    this.videoHeight,
    this.videoFrameCount,
    this.videoDurationUs,
  });

  int sampleRate;
  int channels;
  int durationUs;
  int? frameCount;
  bool? hasVideo;
  int? videoWidth;
  int? videoHeight;

  /// Number of video samples (frames) in the track, counted by reading it.
  int? videoFrameCount;
  int? videoDurationUs;
}

/// What the native guide-video encoder renders (M7 §5). Timing is decided in
/// Dart: frame `k` is presented at exactly `k / fps`; [flashFrames] (ascending)
/// and [beatNumbers] (parallel, 1-based) fully determine every frame's look.
class GuideVideoSpec {
  GuideVideoSpec({
    required this.fps,
    required this.width,
    required this.height,
    required this.totalFrames,
    required this.flashFrames,
    required this.beatNumbers,
    required this.audioWavPath,
    required this.outPath,
    required this.videoBitrate,
    required this.audioBitrate,
  });

  int fps;
  int width;
  int height;
  int totalFrames;
  List<int> flashFrames;
  List<int> beatNumbers;

  /// The pack's guide track (16-bit PCM WAV), muxed as AAC.
  String audioWavPath;
  String outPath;
  int videoBitrate;
  int audioBitrate;
}

/// Native audio work. Long jobs run off the platform main thread and report
/// progress through [AudioProgressApi]. Failures are PlatformExceptions with
/// one of these codes: `drm_protected`, `cloud_item`, `no_audio_track`,
/// `unsupported_format`, `decode_failed`, `encode_failed`, `disk_full`,
/// `permission_denied`, `cancelled`.
@HostApi()
abstract class AudioHostApi {
  /// Decodes the first audio track of [inputPath] (an audio or video file,
  /// or a library URI) to a 16-bit little-endian interleaved PCM WAV at the
  /// track's native sample rate. Tracks with more than two channels are
  /// reduced to stereo.
  @async
  DecodeResult decodeToWav(String jobId, String inputPath, String outputPath);

  /// Stops a running job; its future then fails with `cancelled`.
  void cancelJob(String jobId);

  /// iOS only: presents MPMediaPickerController. Null if the user cancels.
  /// Fails with `drm_protected` / `cloud_item` when the song can't be read.
  @async
  LibraryTrack? pickFromMusicLibrary();

  /// Android only: songs in MediaStore, asking for the audio permission
  /// first if needed. Fails with `permission_denied`.
  @async
  List<LibraryTrack> listMusicLibrary();

  /// Requests runtime permission for music/audio library access without
  /// opening a picker (Android `READ_MEDIA_AUDIO` on API 33+,
  /// `READ_EXTERNAL_STORAGE` on API <= 32; iOS
  /// `MPMediaLibrary.requestAuthorization`). Returns `true` if granted,
  /// `false` if denied.
  @async
  bool requestAudioPermission();

  /// Android only: copies a `content://` URI to [destPath].
  @async
  void copyContentUri(String uri, String destPath);

  /// Free bytes on the volume holding [path].
  int freeDiskBytes(String path);

  /// Encodes a 16-bit PCM WAV to AAC in an MPEG-4 container (.m4a) at
  /// [bitrate] bits/s, same sample rate and channel count. Progress through
  /// AudioProgressApi. Fails with `disk_full`, `encode_failed`, `cancelled`.
  @async
  MediaInfo encodeM4a(
    String jobId,
    String wavPath,
    String outPath,
    int bitrate,
  );

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

  /// Encodes the guide video (M7): H.264 at [GuideVideoSpec.fps] constant
  /// frame rate with the guide WAV as AAC audio, in an MPEG-4 container. Falls
  /// back to 720 × 1280 if the encoder refuses the requested size (the result
  /// says which size was written). Progress through AudioProgressApi (fraction
  /// of totalFrames written). Fails with `disk_full`, `encode_failed`,
  /// `cancelled`.
  @async
  MediaInfo encodeGuideVideo(String jobId, GuideVideoSpec spec);
}

@FlutterApi()
abstract class AudioProgressApi {
  void onProgress(String jobId, double fraction);
}
