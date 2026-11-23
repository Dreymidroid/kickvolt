import 'dart:typed_data';

/// Progress stages reported during background beat analysis.
enum AnalysisStage { envelope, tempo, tracking, sections }

/// Progress snapshot from the background analysis isolate.
class AnalysisProgress {
  const AnalysisProgress({
    required this.stage,
    required this.fraction,
    this.bpm,
  });

  final AnalysisStage stage;

  /// Overall analysis progress in 0.0..1.0.
  final double fraction;

  /// Preliminary or refined BPM once known (from `tempo` stage onward).
  final double? bpm;
}

/// One candidate beat produced by the heavy analysis pass.
class CandidateBeat {
  const CandidateBeat({
    required this.index,
    required this.sample,
    required this.strength,
    required this.lowEnergy,
  });

  /// Sequential index in the tracked beat list (`0..n-1`).
  final int index;

  /// Refined attack start position as an integer sample frame index into `song.wav`.
  final int sample;

  /// Onset strength at this beat, normalised to `0.0..1.0` over the song.
  final double strength;

  /// Mean low-band (< 150 Hz) energy over the beat's period, raw or normalised.
  final double lowEnergy;
}

/// Cached output of the heavy analysis pass (one per song).
///
/// Holds everything needed by `classify` to run in < 5 ms on every slider move.
class BeatAnalysis {
  const BeatAnalysis({
    required this.sampleRate,
    required this.sampleCount,
    required this.hopSize,
    required this.bpm,
    required this.confidence,
    required this.beatPhaseSample,
    required this.candidates,
    required this.frameLowEnergy,
    required this.frameOverallEnergy,
  });

  final int sampleRate;
  final int sampleCount;
  final int hopSize;

  /// Refined tempo in BPM (rounded to 0.1), or 0.0 if no periodicity found.
  final double bpm;

  /// Normalized autocorrelation confidence measure.
  final double confidence;

  /// First refined beat's sample modulo the grid period, or 0 if no beats.
  final int beatPhaseSample;

  /// Tracked and sample-refined candidate beats.
  final List<CandidateBeat> candidates;

  /// Per-hop-frame low-band (< 150 Hz) energy `L[t]`.
  final Float32List frameLowEnergy;

  /// Per-hop-frame overall spectral energy.
  final Float32List frameOverallEnergy;
}
