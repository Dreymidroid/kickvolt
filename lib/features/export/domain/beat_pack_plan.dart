import 'dart:math' as math;

import '../../../core/audio_math/guide_track.dart';
import '../../../core/audio_math/wav_header.dart';
import '../../beat_detection/domain/beat_filter_view.dart';
import '../../projects/domain/entities/project.dart';
import 'entities/beat_pack.dart';
import 'entities/export_options.dart';
import 'guide_video_plan.dart';

const int _maxTitleCodeUnits = 60;
const String _fallbackExportTitle = 'KickVolt';
const String _reservedChars = r'\/:*?"<>|';

/// Sanitises [title] for file systems (§4.6):
/// - Drops characters in `\/:*?"<>|` and control characters.
/// - Drops whitespace (`Midnight Run` → `MidnightRun` to match the design).
/// - Trims dots and spaces from both ends.
/// - Preserves Unicode letters and numbers.
/// - Caps at 60 UTF-16 code units without splitting a surrogate pair.
/// - Falls back to `KickVolt` when empty.
String sanitizeExportTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return _fallbackExportTitle;

  final sb = StringBuffer();
  for (final rune in trimmed.runes) {
    // Drop ASCII and C1 control characters.
    if (rune <= 0x1F || (rune >= 0x7F && rune <= 0x9F)) continue;
    final ch = String.fromCharCode(rune);
    // Drop reserved filesystem chars.
    if (_reservedChars.contains(ch)) continue;
    // Drop whitespace so "Midnight Run" -> "MidnightRun".
    if (ch.trim().isEmpty) continue;
    sb.write(ch);
  }

  // Trim leading and trailing dots.
  var cleaned = sb.toString().replaceAll(RegExp(r'^\.+|\.+$'), '');
  if (cleaned.isEmpty) return _fallbackExportTitle;

  // Cap at 60 UTF-16 code units without splitting a surrogate pair.
  if (cleaned.length > _maxTitleCodeUnits) {
    var end = _maxTitleCodeUnits;
    final lastUnit = cleaned.codeUnitAt(end - 1);
    // High surrogate is in 0xD800..0xDBFF.
    if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
      end -= 1;
    }
    cleaned = cleaned.substring(0, end).replaceAll(RegExp(r'\.+$'), '');
  }

  return cleaned.isEmpty ? _fallbackExportTitle : cleaned;
}

/// Pure beat-pack planner (§4.1, §4.6, §4.7).
///
/// Execution order is `guide` → `video` → `song` → `preview` so the guide track
/// is rendered first and the guide video (M7) can be encoded from it. The
/// video is planned only together with the guide track, whose WAV it needs.
BeatPackPlan planBeatPack(Project project, ExportOptions options) {
  final sanitizedTitle = sanitizeExportTitle(project.title);
  final ext = options.format.extension;
  final frameCount = math.max(0, project.sampleCount);
  final songChannels = project.channels.clamp(1, 2);
  final guideChannels = options.monoGuide ? 1 : 2;

  final visibleIndices = visibleBeatIndices(project);
  final rawBeats = <int>[
    for (final i in visibleIndices)
      if (i >= 0 && i < project.beats.length) project.beats[i].sample,
  ];
  final visibleBeatSamples = clampAndDeduplicateBeats(rawBeats, frameCount);

  int wavBytesFor(int channels) => wavHeaderBytes + frameCount * channels * 2;

  final files = <PlannedExportFile>[];
  if (options.includeGuide) {
    files.add(
      PlannedExportFile(
        kind: ExportFileKind.guide,
        fileName: '${sanitizedTitle}_beats.$ext',
        channels: guideChannels,
        frameCount: frameCount,
        estimatedWavBytes: wavBytesFor(guideChannels),
        clickCount: visibleBeatSamples.length,
      ),
    );
  }
  GuideVideoPlan? guideVideo;
  var videoBytes = 0;
  if (options.includeVideo && options.includeGuide && project.sampleRate > 0) {
    guideVideo = planGuideVideo(
      sampleRate: project.sampleRate,
      frameCount: frameCount,
      visibleBeatSamples: visibleBeatSamples,
    );
    videoBytes = estimateGuideVideoBytes(
      frameCount: frameCount,
      sampleRate: project.sampleRate,
    );
    files.add(
      PlannedExportFile(
        kind: ExportFileKind.video,
        fileName: '${sanitizedTitle}_guide.mp4',
        channels: guideChannels,
        frameCount: frameCount,
        // Not a WAV: the estimated MP4 size (kept out of the audio total).
        estimatedWavBytes: videoBytes,
        clickCount: visibleBeatSamples.length,
      ),
    );
  }
  if (options.includeSong) {
    files.add(
      PlannedExportFile(
        kind: ExportFileKind.song,
        fileName: '${sanitizedTitle}_song.$ext',
        channels: songChannels,
        frameCount: frameCount,
        estimatedWavBytes: wavBytesFor(songChannels),
      ),
    );
  }
  if (options.includePreview) {
    files.add(
      PlannedExportFile(
        kind: ExportFileKind.preview,
        fileName: '${sanitizedTitle}_preview.$ext',
        channels: songChannels,
        frameCount: frameCount,
        estimatedWavBytes: wavBytesFor(songChannels),
      ),
    );
  }

  final totalWavBytes = files
      .where((f) => f.kind != ExportFileKind.video)
      .fold<int>(0, (sum, f) => sum + f.estimatedWavBytes);
  // §4.7: WAV: 44 + frames * channels * 2 per file;
  // M4A: WAV estimate * 0.25 for the transient WAV plus the M4A.
  // M7 §6: plus the guide video, bitrate × duration + 10%.
  final estimatedDiskBytes =
      switch (options.format) {
        AudioFormat.wav => totalWavBytes,
        AudioFormat.m4a => (totalWavBytes * 0.25).ceil(),
      } +
      videoBytes;

  return BeatPackPlan(
    projectId: project.id,
    sanitizedTitle: sanitizedTitle,
    options: options,
    sampleRate: project.sampleRate,
    songChannels: songChannels,
    frameCount: frameCount,
    durationMs: project.durationMs,
    visibleBeatSamples: visibleBeatSamples,
    files: files,
    estimatedDiskBytes: estimatedDiskBytes,
    guideVideo: guideVideo,
  );
}
