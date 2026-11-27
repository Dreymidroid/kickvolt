import 'dart:typed_data';

/// Guide video frame rate (constant frame rate, M7 §4.1).
const int kGuideVideoFps = 30;

/// Portrait 1080 × 1920 (TikTok/Reels/Shorts, M7 §4.3).
const int kGuideVideoWidth = 1080;
const int kGuideVideoHeight = 1920;

/// H.264 average bitrate. Mostly-black frames compress to almost nothing.
const int kGuideVideoBitrate = 2000000;

/// AAC bitrate for the guide track muxed into the MP4.
const int kGuideVideoAudioBitrate = 192000;

/// Number of video frames for a song of [frameCount] sample frames:
/// `ceil(frameCount × fps / sampleRate)` in exact integer maths. The video is
/// at most one frame longer than the audio.
int guideVideoTotalFrames({
  required int frameCount,
  required int sampleRate,
  int fps = kGuideVideoFps,
}) {
  _checkRate(sampleRate, fps);
  if (frameCount <= 0) return 0;
  return (frameCount * fps + sampleRate - 1) ~/ sampleRate;
}

/// The video frame whose time span `[k / fps, (k + 1) / fps)` contains
/// [sample]: `floor(sample × fps / sampleRate)`.
int guideVideoFrameForSample(
  int sample, {
  required int sampleRate,
  int fps = kGuideVideoFps,
}) {
  _checkRate(sampleRate, fps);
  return (sample * fps) ~/ sampleRate;
}

void _checkRate(int sampleRate, int fps) {
  if (sampleRate <= 0) {
    throw ArgumentError.value(sampleRate, 'sampleRate', 'must be > 0');
  }
  if (fps <= 0) throw ArgumentError.value(fps, 'fps', 'must be > 0');
}

/// What the native encoder renders (M7 §4). Native code never derives timing
/// itself: every frame `k` is presented at exactly `k / fps` and its look is
/// fully determined by [flashFrames] / [beatNumbers]:
///
/// - frame in [flashFrames] (index i): white, number `beatNumbers[i]` in black;
/// - the frame right after a flash: black, the same number in white;
/// - any later frame: black, the last number in white at 40% opacity;
/// - before the first flash: plain black.
class GuideVideoPlan {
  GuideVideoPlan({
    required this.fps,
    required this.width,
    required this.height,
    required this.totalFrames,
    required this.flashFrames,
    required this.beatNumbers,
    required this.beatCount,
  }) : assert(flashFrames.length == beatNumbers.length);

  final int fps;
  final int width;
  final int height;
  final int totalFrames;

  /// Ascending, unique frame indices in `[0, totalFrames - 1]`.
  final Int32List flashFrames;

  /// Parallel to [flashFrames]: the 1-based number shown on that flash.
  final Int32List beatNumbers;

  /// Number of visible beats (after clamping and de-duplication). Equals
  /// `flashCount` unless two beats share a frame.
  final int beatCount;

  int get flashCount => flashFrames.length;

  /// Exact video duration in microseconds (`totalFrames / fps`), rounded up.
  int get durationUs => (totalFrames * 1000000 + fps - 1) ~/ fps;

  /// One frame in microseconds, rounded up (the verification tolerance).
  int get frameDurationUs => (1000000 + fps - 1) ~/ fps;
}

/// Pure frame plan for the guide video (M7 §4.1).
///
/// - Beats are the visible beats, sorted, de-duplicated and clamped to
///   `[0, frameCount - 1]`; beat number = 1-based index in that list (the
///   editor's "BEAT n / N").
/// - Beat → frame is `floor(sample × fps / sampleRate)`.
/// - Two beats in one frame produce **one** flash showing the **later**
///   beat's number; the earlier number is skipped. At 30 fps that needs beats
///   under 33 ms apart (above 1800 BPM), i.e. double markers.
GuideVideoPlan planGuideVideo({
  required int sampleRate,
  required int frameCount,
  required List<int> visibleBeatSamples,
  int fps = kGuideVideoFps,
  int width = kGuideVideoWidth,
  int height = kGuideVideoHeight,
}) {
  final totalFrames = guideVideoTotalFrames(
    frameCount: frameCount,
    sampleRate: sampleRate,
    fps: fps,
  );

  final beats = <int>[];
  if (frameCount > 0 && visibleBeatSamples.isNotEmpty) {
    final maxSample = frameCount - 1;
    final sorted = <int>[
      for (final s in visibleBeatSamples) s.clamp(0, maxSample),
    ]..sort();
    for (final s in sorted) {
      if (beats.isEmpty || beats.last != s) beats.add(s);
    }
  }

  final frames = <int>[];
  final numbers = <int>[];
  for (var i = 0; i < beats.length; i++) {
    final frame = guideVideoFrameForSample(
      beats[i],
      sampleRate: sampleRate,
      fps: fps,
    );
    if (frames.isNotEmpty && frames.last == frame) {
      // Same frame as the previous beat: the later number wins.
      numbers[numbers.length - 1] = i + 1;
    } else {
      frames.add(frame);
      numbers.add(i + 1);
    }
  }

  return GuideVideoPlan(
    fps: fps,
    width: width,
    height: height,
    totalFrames: totalFrames,
    flashFrames: Int32List.fromList(frames),
    beatNumbers: Int32List.fromList(numbers),
    beatCount: beats.length,
  );
}

/// Estimated MP4 size: (video + audio bitrate) × duration + 10% (M7 §6).
int estimateGuideVideoBytes({
  required int frameCount,
  required int sampleRate,
  int videoBitrate = kGuideVideoBitrate,
  int audioBitrate = kGuideVideoAudioBitrate,
}) {
  if (frameCount <= 0 || sampleRate <= 0) return 0;
  final bitsTimesRate = (videoBitrate + audioBitrate) * frameCount;
  final bytes = (bitsTimesRate + 8 * sampleRate - 1) ~/ (8 * sampleRate);
  return bytes + (bytes + 9) ~/ 10;
}
