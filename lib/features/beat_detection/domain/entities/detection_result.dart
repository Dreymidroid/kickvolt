import '../../../projects/domain/entities/beat.dart';
import '../../../projects/domain/entities/section.dart';

/// Result of running cheap classification on a [BeatAnalysis] for a given
/// sensitivity in `0.0..1.0`.
class DetectionResult {
  const DetectionResult({
    required this.succeeded,
    required this.beats,
    required this.bpm,
    required this.beatPhaseSample,
    required this.sections,
    this.fallbackDrops = const <Beat>[],
  });

  /// True when a steady beat was found; false on "no steady beat" failure.
  final bool succeeded;

  /// Classified beats sorted by sample index. Empty when [succeeded] is false.
  final List<Beat> beats;

  /// Final BPM to 0.1, or null when [succeeded] is false.
  final double? bpm;

  /// Grid phase in sample frames, or null when [succeeded] is false.
  final int? beatPhaseSample;

  /// Heuristic song sections covering `[0, sampleCount)`. Empty on failure.
  final List<Section> sections;

  /// Drops detected from low-band energy jumps even when [succeeded] is false,
  /// used by the "Mark drops only" fallback action.
  final List<Beat> fallbackDrops;
}
