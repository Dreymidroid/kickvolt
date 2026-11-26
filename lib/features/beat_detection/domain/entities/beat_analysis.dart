import 'dart:typed_data';

import '../../../projects/domain/entities/detection_settings.dart';

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

/// A distinct candidate tempo found during analysis (§4.1), ordered best first.
class TempoCandidate {
  const TempoCandidate({
    required this.bpm,
    required this.periodFrames,
    required this.score,
  });

  /// Candidate tempo in BPM (40–240), rounded to 0.1.
  final double bpm;

  /// Period in STFT hop frames corresponding to [bpm].
  final double periodFrames;

  /// Prior- and harmonic-weighted score normalised to `0.0..1.0` (winner = 1.0).
  final double score;
}

/// Estimated eighth-note swing ratio and confidence (§4.1, §4.4).
class SwingEstimate {
  const SwingEstimate({this.ratio = 0.5, this.confidence = 0.0});

  /// Dominant off-beat eighth-note position as a fraction of the beat (`0..1`).
  /// `~0.50` = straight, `0.60..0.75` = swung.
  final double ratio;

  /// Confidence of the off-beat subdivision peak in `0.0..1.0`.
  final double confidence;

  /// Minimum confidence required to report a swung feel in the UI or apply the
  /// swing tempo rule (§4.4).
  static const double confidentThreshold = 0.35;

  /// Whether a confident swing feel (`0.58 <= ratio <= 0.75`) was detected.
  bool get isSwung =>
      confidence >= confidentThreshold && ratio >= 0.58 && ratio <= 0.75;
}

/// Options for re-tracking beats from a cached [BeatAnalysis] (§4.2, §4.3).
class TrackingOptions {
  const TrackingOptions({this.targetBpm, this.tempoMode = TempoMode.steady});

  /// User-selected tempo in BPM (e.g. ½×, 2×, or a candidate from "More…").
  /// When `null`, uses the analyser's automatic winner.
  final double? targetBpm;

  /// Steady constant-period tracking vs varying local-tempo tracking.
  final TempoMode tempoMode;

  TrackingOptions copyWith({
    double? targetBpm,
    bool clearTargetBpm = false,
    TempoMode? tempoMode,
  }) => TrackingOptions(
    targetBpm: clearTargetBpm ? null : (targetBpm ?? this.targetBpm),
    tempoMode: tempoMode ?? this.tempoMode,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackingOptions &&
          other.tempoMode == tempoMode &&
          _sameBpm(other.targetBpm, targetBpm));

  @override
  int get hashCode => Object.hash(
    tempoMode,
    targetBpm == null ? null : (targetBpm! * 10).round(),
  );

  static bool _sameBpm(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return (a * 10).round() == (b * 10).round();
  }
}

/// Relative spread threshold of `localTempo` above which the Auto-detect sheet
/// suggests "Tempo changes" (§4.3, §6).
///
/// Set to `0.015` (1.5 % trimmed relative spread / IQR): steady tracks have
/// `tempoStability < 0.005`, while ramps (120→130), steps (100→140) and
/// ±2 % live drift have `tempoStability >= 0.018`.
const double tempoStabilitySuggestionThreshold = 0.015;

/// Cached output of the heavy analysis pass (one per song).
///
/// Holds everything needed by `classify` to run in < 5 ms on every slider move,
/// plus the cached envelopes and curves needed by `retrack` (§4.1, §4.2).
class BeatAnalysis {
  BeatAnalysis({
    required this.sampleRate,
    required this.sampleCount,
    required this.hopSize,
    required this.bpm,
    required this.confidence,
    required this.beatPhaseSample,
    required this.candidates,
    required this.frameLowEnergy,
    required this.frameOverallEnergy,
    Float32List? onsetEnvelope,
    Float32List? lowMidOnsetEnvelope,
    this.tempoCandidates = const <TempoCandidate>[],
    Float32List? localTempo,
    this.tempoStability = 0.0,
    this.swing = const SwingEstimate(),
  }) : onsetEnvelope = onsetEnvelope ?? Float32List(0),
       lowMidOnsetEnvelope = lowMidOnsetEnvelope ?? Float32List(0),
       localTempo = localTempo ?? Float32List(0);

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

  /// Per-hop-frame full-band onset strength envelope `O[t]` (§4.1).
  final Float32List onsetEnvelope;

  /// Per-hop-frame kick/snare (< 4 kHz) onset strength envelope (§4.1).
  final Float32List lowMidOnsetEnvelope;

  /// Up to 5 distinct candidate tempi (40–240 BPM), best first (§4.1).
  final List<TempoCandidate> tempoCandidates;

  /// Smoothed local tempo period curve (in hop frames, 1 value per ~1 s block) (§4.1, §4.3).
  final Float32List localTempo;

  /// Relative spread of [localTempo] after outlier removal (§4.1, §4.3).
  final double tempoStability;

  /// Estimated eighth-note swing ratio and confidence (§4.1, §4.4).
  final SwingEstimate swing;

  /// Whether [tempoStability] exceeds [tempoStabilitySuggestionThreshold] (§4.3).
  bool get suggestsTempoChanges =>
      tempoStability > tempoStabilitySuggestionThreshold;

  /// Returns a copy with updated tracking outputs (`bpm`, `beatPhaseSample`,
  /// `candidates`, and optionally `swing`).
  BeatAnalysis copyWithTracking({
    required double bpm,
    required int beatPhaseSample,
    required List<CandidateBeat> candidates,
    SwingEstimate? swing,
  }) => BeatAnalysis(
    sampleRate: sampleRate,
    sampleCount: sampleCount,
    hopSize: hopSize,
    bpm: bpm,
    confidence: confidence,
    beatPhaseSample: beatPhaseSample,
    candidates: candidates,
    frameLowEnergy: frameLowEnergy,
    frameOverallEnergy: frameOverallEnergy,
    onsetEnvelope: onsetEnvelope,
    lowMidOnsetEnvelope: lowMidOnsetEnvelope,
    tempoCandidates: tempoCandidates,
    localTempo: localTempo,
    tempoStability: tempoStability,
    swing: swing ?? this.swing,
  );

  /// Convenience helper for tests to copy with a different [bpm].
  BeatAnalysis copyWithBpm(double nextBpm) => copyWithTracking(
    bpm: nextBpm,
    beatPhaseSample: beatPhaseSample,
    candidates: candidates,
  );
}
