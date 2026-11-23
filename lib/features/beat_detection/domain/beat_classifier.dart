import 'dart:math' as math;
import 'dart:typed_data';

import '../../projects/domain/entities/beat.dart';
import '../../projects/domain/entities/section.dart';
import 'entities/beat_analysis.dart';
import 'entities/detection_result.dart';
import 'section_builder.dart';

/// Minimum number of tracked beats required for a valid steady-beat result.
const int minTrackedBeats = 8;

/// Computes the [percentile]-th percentile (`0..100`) of [values] using
/// linear interpolation between sorted ranks.
double percentileOf(List<double> values, double percentile) {
  if (values.isEmpty) return 0.0;
  final sorted = Float64List.fromList(values)..sort();
  return _percentileFromSorted(sorted, percentile);
}

double _percentileFromSorted(Float64List sorted, double percentile) {
  if (sorted.isEmpty) return 0.0;
  final p = percentile.clamp(0.0, 100.0) / 100.0;
  if (sorted.length == 1) return sorted[0];
  final pos = p * (sorted.length - 1);
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return sorted[lo];
  final frac = pos - lo;
  return sorted[lo] * (1.0 - frac) + sorted[hi] * frac;
}

/// Confidence threshold that decreases with [sensitivity] (`0..1`):
/// higher sensitivity accepts weaker periodicity (§4.6).
double confidenceThresholdForSensitivity(double sensitivity) {
  final s = sensitivity.clamp(0.0, 1.0);
  // At sensitivity 0.0: requires confidence >= 2.25.
  // At sensitivity 0.5: requires confidence >= 1.85.
  // At sensitivity 1.0: requires confidence >= 1.45.
  return 2.25 - 0.80 * s;
}

/// Pure, fast (< 5 ms for 2,000 beats) classification function (§4.5–§4.8).
///
/// Takes a precomputed [BeatAnalysis] and [sensitivity] in `0.0..1.0` and
/// returns a [DetectionResult] with classified beats, BPM, grid phase, and
/// rough sections (or a failure result when no steady beat is present).
DetectionResult classifyBeats(
  BeatAnalysis analysis, {
  required double sensitivity,
}) {
  final s = sensitivity.clamp(0.0, 1.0);
  final candidates = analysis.candidates;
  final n = candidates.length;

  final minConf = confidenceThresholdForSensitivity(s);
  if (n < minTrackedBeats ||
      analysis.bpm <= 0 ||
      analysis.confidence < minConf) {
    final fallbackDrops = _detectEnergyOnlyDrops(analysis);
    return DetectionResult(
      succeeded: false,
      beats: const <Beat>[],
      bpm: null,
      beatPhaseSample: null,
      sections: const <Section>[],
      fallbackDrops: fallbackDrops,
    );
  }

  // Sort strengths and per-beat lowEnergy once (O(N log N) where N = candidate beats).
  final sortedStrengths = Float64List(n);
  final sortedLowEnergies = Float64List(n);
  var maxLowEnergy = 1e-9;
  for (var i = 0; i < n; i++) {
    final c = candidates[i];
    sortedStrengths[i] = c.strength;
    sortedLowEnergies[i] = c.lowEnergy;
    if (c.lowEnergy > maxLowEnergy) {
      maxLowEnergy = c.lowEnergy;
    }
  }
  sortedStrengths.sort();
  sortedLowEnergies.sort();

  // §4.5 Strong: strength >= p-th percentile, p = 85 - 40 * sensitivity
  // (top 15 % at 0, top 55 % at 1).
  final strongPercentile = 85.0 - 40.0 * s;
  final strongThreshold = _percentileFromSorted(
    sortedStrengths,
    strongPercentile,
  );

  // §4.5 Sensitivity pruning: with sensitivity < 0.5, beats in quiet stretches
  // (strength below q-th percentile, q = 40 * (0.5 - sensitivity), up to
  // bottom 20 % at 0) are removed. At >= 0.5 nothing is pruned.
  final pruneThreshold = s < 0.5
      ? _percentileFromSorted(sortedStrengths, 40.0 * (0.5 - s))
      : -1.0;

  // HEURISTIC: Downbeats (§4.5).
  // For each phase phi in {0,1,2,3}, sum (strength + normalised lowEnergy) of
  // beats with index % 4 == phi; the best phi's beats are downbeats.
  final phaseScores = Float64List(4);
  final phaseCounts = Int32List(4);
  final invMaxLow = 1.0 / maxLowEnergy;
  for (var i = 0; i < n; i++) {
    final c = candidates[i];
    final phi = c.index & 3;
    phaseScores[phi] += c.strength + c.lowEnergy * invMaxLow;
    phaseCounts[phi]++;
  }
  var downbeatPhase = 0;
  var bestPhaseScore = -1.0;
  for (var phi = 0; phi < 4; phi++) {
    final score = phaseCounts[phi] > 0
        ? phaseScores[phi] / phaseCounts[phi]
        : 0.0;
    if (score > bestPhaseScore) {
      bestPhaseScore = score;
      downbeatPhase = phi;
    }
  }

  // HEURISTIC: Drops (§4.5).
  // A downbeat is a drop when the mean low-band energy over the next 2 bars
  // (8 beats) is >= 2x (+6 dB) the mean over the previous 4 bars (16 beats)
  // AND above the song's median low-band energy. Keep at least 8 bars
  // (32 beats) between drops; keep only the strongest in any 8-bar window.
  final medianBeatLow = _percentileFromSorted(sortedLowEnergies, 50.0);
  final isDrop = _findDropCandidateMask(
    candidates: candidates,
    downbeatPhase: downbeatPhase,
    medianLowEnergy: medianBeatLow,
  );

  // Build final classified beat list with precedence:
  // drop > downbeat > strong > beat.
  final beats = <Beat>[];
  for (var i = 0; i < n; i++) {
    final c = candidates[i];
    if (s < 0.5 && c.strength < pruneThreshold) {
      continue;
    }
    final BeatType type;
    if (isDrop[i] != 0) {
      type = BeatType.drop;
    } else if ((c.index & 3) == downbeatPhase) {
      type = BeatType.downbeat;
    } else if (c.strength >= strongThreshold) {
      type = BeatType.strong;
    } else {
      type = BeatType.beat;
    }
    beats.add(Beat(sample: c.sample, type: type));
  }

  if (beats.length < minTrackedBeats) {
    final fallbackDrops = _detectEnergyOnlyDrops(analysis);
    return DetectionResult(
      succeeded: false,
      beats: const <Beat>[],
      bpm: null,
      beatPhaseSample: null,
      sections: const <Section>[],
      fallbackDrops: fallbackDrops,
    );
  }

  final sections = buildHeuristicSections(
    beats: beats,
    sampleCount: analysis.sampleCount,
    hopSize: analysis.hopSize,
    frameLowEnergy: analysis.frameLowEnergy,
    frameOverallEnergy: analysis.frameOverallEnergy,
  );

  return DetectionResult(
    succeeded: true,
    beats: beats,
    bpm: analysis.bpm,
    beatPhaseSample: analysis.beatPhaseSample,
    sections: sections,
  );
}

// HEURISTIC: Drop detection on downbeats using per-beat low-band energy (§4.5).
// Because each candidate beat already stores `lowEnergy` (mean low-band energy
// over that beat's period `[beat, beat + 1)`), the mean over the previous 4
// bars is the mean of `candidates[i - 16 .. i - 1].lowEnergy` and the mean
// over the next 2 bars is the mean of `candidates[i .. i + 7].lowEnergy`.
// Score is computed from the step jump `nextMean - prevMean` so the drop lands
// right on the downbeat where the bass enters (rather than 1 bar early).
Uint8List _findDropCandidateMask({
  required List<CandidateBeat> candidates,
  required int downbeatPhase,
  required double medianLowEnergy,
}) {
  final n = candidates.length;
  final mask = Uint8List(n);
  if (n < 24) return mask;

  // Prefix sum of per-beat lowEnergy for O(1) bar-window averages.
  final prefix = Float64List(n + 1);
  for (var i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + candidates[i].lowEnergy;
  }

  const prevBeats = 16; // 4 bars
  const nextBeats = 8; // 2 bars

  final dropIndices = <int>[];
  final dropScores = <double>[];

  for (var i = 8; i <= n - 4; i++) {
    final c = candidates[i];
    if ((c.index & 3) != downbeatPhase) continue;

    final p0 = math.max(0, i - prevBeats);
    final n1 = math.min(n, i + nextBeats);
    if (i <= p0 || n1 <= i) continue;

    final prevMean = (prefix[i] - prefix[p0]) / (i - p0);
    final nextMean = (prefix[n1] - prefix[i]) / (n1 - i);

    if (nextMean > medianLowEnergy &&
        nextMean > 1e-6 &&
        nextMean >= 2.0 * math.max(1e-9, prevMean)) {
      // Score favours the sharp onset boundary where energy jumps:
      // `(nextMean - prevMean)` peaks at the exact downbeat where bass starts
      // because earlier downbeats include quiet bars in `nextMean` and later
      // downbeats include loud bars in `prevMean`.
      final immediateJump = c.lowEnergy - candidates[i - 1].lowEnergy;
      final score = (nextMean - prevMean) + 0.5 * math.max(0.0, immediateJump);
      dropIndices.add(i);
      dropScores.add(score);
    }
  }

  if (dropIndices.isEmpty) return mask;

  // Greedy selection in descending score order with >= 8 bars (32 beats) spacing.
  final order = List<int>.generate(dropIndices.length, (k) => k)
    ..sort((a, b) => dropScores[b].compareTo(dropScores[a]));

  const minBeatDistance = 32; // 8 bars * 4 beats/bar
  final chosen = <int>[];
  for (final k in order) {
    final idx = dropIndices[k];
    var tooClose = false;
    for (var j = 0; j < chosen.length; j++) {
      if ((chosen[j] - idx).abs() < minBeatDistance) {
        tooClose = true;
        break;
      }
    }
    if (!tooClose) {
      chosen.add(idx);
      mask[idx] = 1;
    }
  }
  return mask;
}

// HEURISTIC: Energy-only fallback drops on failure (§4.6) so "Mark drops only"
// has something to mark if a track has big bass hits without a steady tempo.
List<Beat> _detectEnergyOnlyDrops(BeatAnalysis analysis) {
  final frameLow = analysis.frameLowEnergy;
  if (frameLow.length < 32 || analysis.sampleRate <= 0) return const <Beat>[];

  final sortedLow = Float64List.fromList(frameLow)..sort();
  final medianLow = _percentileFromSorted(sortedLow, 50.0);
  final p90Low = _percentileFromSorted(sortedLow, 90.0);
  if (p90Low <= 1e-5) return const <Beat>[];

  final framesPerBar = math.max(
    4,
    (2.0 * analysis.sampleRate / analysis.hopSize).round(),
  );
  final prevFrames = 4 * framesPerBar;
  final nextFrames = 2 * framesPerBar;
  final minGapFrames = 8 * framesPerBar;

  final prefix = Float64List(frameLow.length + 1);
  for (var i = 0; i < frameLow.length; i++) {
    prefix[i + 1] = prefix[i] + frameLow[i];
  }

  final raw = <(int frame, double score)>[];
  for (var f = framesPerBar; f < frameLow.length - framesPerBar; f++) {
    final p0 = math.max(0, f - prevFrames);
    final n1 = math.min(frameLow.length, f + nextFrames);
    final prevMean = (prefix[f] - prefix[p0]) / (f - p0);
    final nextMean = (prefix[n1] - prefix[f]) / (n1 - f);
    if (nextMean > math.max(medianLow, p90Low * 0.5) &&
        nextMean >= 2.5 * math.max(1e-6, prevMean)) {
      raw.add((f, nextMean - prevMean));
    }
  }

  if (raw.isEmpty) return const <Beat>[];
  raw.sort((a, b) => b.$2.compareTo(a.$2));

  final chosenFrames = <int>[];
  for (final (f, _) in raw) {
    if (chosenFrames.every((c) => (c - f).abs() >= minGapFrames)) {
      chosenFrames.add(f);
    }
  }
  chosenFrames.sort();

  return <Beat>[
    for (final f in chosenFrames)
      Beat(
        sample: (f * analysis.hopSize).clamp(
          0,
          math.max(0, analysis.sampleCount - 1),
        ),
        type: BeatType.drop,
      ),
  ];
}
