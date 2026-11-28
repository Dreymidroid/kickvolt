import '../../../core/audio_native/audio_native_client.dart';
import '../domain/guide_video_plan.dart';

/// The Pigeon spec for [plan]: frame indices and numbers exactly as planned in
/// Dart, so native code only renders (M7 §5).
GuideVideoSpec guideVideoSpecFor(
  GuideVideoPlan plan, {
  required String audioWavPath,
  required String outPath,
  int videoBitrate = kGuideVideoBitrate,
  int audioBitrate = kGuideVideoAudioBitrate,
}) {
  return GuideVideoSpec(
    fps: plan.fps,
    width: plan.width,
    height: plan.height,
    totalFrames: plan.totalFrames,
    flashFrames: List<int>.of(plan.flashFrames),
    beatNumbers: List<int>.of(plan.beatNumbers),
    audioWavPath: audioWavPath,
    outPath: outPath,
    videoBitrate: videoBitrate,
    audioBitrate: audioBitrate,
  );
}

/// Checks a probed guide video (M7 §6). Returns null when it is fine, else
/// what is wrong:
///
/// - it has a video track, with [GuideVideoPlan.totalFrames] frames when the
///   platform reports a frame count (that plus the duration means 30 fps);
/// - the video lasts as long as the song, within one frame;
/// - it has audio in the guide track's sample rate and channel count.
///
/// The audio track's own duration is not compared: AAC pads to whole
/// 1024-sample packets, which at 22.05 kHz is more than one video frame.
String? guideVideoVerificationProblem(
  MediaInfo media, {
  required GuideVideoPlan plan,
  required int sampleRate,
  required int frameCount,
  required int guideChannels,
}) {
  if (media.hasVideo != true) return 'The guide video has no video track.';
  if (media.sampleRate != sampleRate || media.channels != guideChannels) {
    return 'The guide video audio is ${media.sampleRate} Hz / '
        '${media.channels} ch, expected $sampleRate Hz / $guideChannels ch.';
  }
  final frames = media.videoFrameCount;
  if (frames != null && frames != plan.totalFrames) {
    return 'The guide video has $frames frames, expected ${plan.totalFrames}.';
  }
  final videoUs = media.videoDurationUs ?? media.durationUs;
  // |videoUs - songUs| <= one frame, with songUs = frameCount * 1e6 / rate,
  // compared exactly in integers.
  final diff = (videoUs * sampleRate - frameCount * 1000000).abs();
  if (diff > plan.frameDurationUs * sampleRate) {
    return 'The guide video lasts $videoUs µs; the song lasts '
        '${frameCount * 1000000 ~/ sampleRate} µs.';
  }
  return null;
}
