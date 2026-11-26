import '../../beat_detection/domain/beat_filter_view.dart';
import '../../projects/domain/entities/beat.dart';
import '../../projects/domain/entities/project.dart';

/// Haptic event fired when a visible beat passes the playhead during playback.
enum BeatPassHaptic { light, heavy }

/// Pure playhead-crossing detector for playback haptics (§6.2).
///
/// Returns the haptics to fire for visible beats strictly between
/// [previousSample] and [currentSample] while moving forward:
/// - Only fires while [playing] is true and `currentSample > previousSample`.
/// - Jumps greater than 250 ms count as a seek and fire nothing.
/// - `BeatType.drop` fires [BeatPassHaptic.heavy] whenever playing.
/// - `BeatType.strong` and `BeatType.downbeat` fire [BeatPassHaptic.light]
///   only when [clicksEnabled] is true.
///
/// Pass [visibleIndices] (`visibleBeatIndices(project)`, cached by the caller)
/// when calling this every frame, so the filter isn't recomputed per frame.
List<BeatPassHaptic> detectPassedBeatHaptics({
  required Project project,
  required int previousSample,
  required int currentSample,
  required bool playing,
  required bool clicksEnabled,
  List<int>? visibleIndices,
}) {
  if (!playing || currentSample <= previousSample) {
    return const <BeatPassHaptic>[];
  }
  final maxStep = project.msToSamples(250);
  if (currentSample - previousSample > maxStep) {
    return const <BeatPassHaptic>[];
  }

  final visible = visibleIndices ?? visibleBeatIndices(project);
  if (visible.isEmpty) return const <BeatPassHaptic>[];

  final out = <BeatPassHaptic>[];
  final beats = project.beats;
  for (final idx in visible) {
    final beat = beats[idx];
    if (beat.sample <= previousSample) continue;
    if (beat.sample > currentSample) break;
    switch (beat.type) {
      case BeatType.drop:
        out.add(BeatPassHaptic.heavy);
      case BeatType.strong:
      case BeatType.downbeat:
        if (clicksEnabled) out.add(BeatPassHaptic.light);
      case BeatType.beat:
        break;
    }
  }
  return out;
}
