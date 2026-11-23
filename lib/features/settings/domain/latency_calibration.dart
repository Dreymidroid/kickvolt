import 'dart:math' as math;

/// Calibration constants (§7.6): 30 s click track at 100 BPM.
const double kCalibrationBpm = 100.0;
const int kCalibrationDurationSeconds = 30;
const int kCalibrationSampleRate = 44100;
const int kCalibrationMinTaps = 16;
const int kCalibrationMinInliers = 12;

/// Minimum MAD-based threshold in ms so near-identical taps (MAD ≈ 0) don't
/// falsely drop taps that are only a few ms away from the median.
const double kCalibrationMinOutlierThresholdMs = 10.0;

/// Maximum allowable spread (MAD) of the remaining inliers; above this the
/// taps are considered too erratic to produce a reliable offset.
const double kCalibrationMaxInlierMadMs = 45.0;

/// Valid latency offset bounds stored in settings (ms).
const int kLatencyOffsetMinMs = -100;
const int kLatencyOffsetMaxMs = 500;

enum CalibrationStatus { needMoreTaps, ready, tooUneven }

/// Result of evaluating a set of user tap samples against calibration clicks.
class CalibrationEvaluation {
  const CalibrationEvaluation({
    required this.status,
    required this.validTapCount,
    required this.inlierCount,
    this.offsetMs,
  });

  final CalibrationStatus status;
  final int validTapCount;
  final int inlierCount;

  /// Calibrated latency offset in milliseconds when [status] is
  /// [CalibrationStatus.ready], clamped to `[-100, 500]`.
  final int? offsetMs;
}

/// Generates the sorted integer sample indices for a calibration click track.
/// Starts at 0.5 s so the first click has breathing room after playback begins.
List<int> calibrationClickSamples({
  int sampleRate = kCalibrationSampleRate,
  double bpm = kCalibrationBpm,
  int durationSeconds = kCalibrationDurationSeconds,
}) {
  final totalSamples = sampleRate * durationSeconds;
  final period = sampleRate * 60.0 / bpm;
  final start = (sampleRate * 0.5).round();
  final maxSample = totalSamples - (sampleRate * 0.1).round();
  final out = <int>[];
  for (var i = 0; ; i++) {
    final s = start + (i * period).round();
    if (s >= maxSample) break;
    out.add(s);
  }
  return out;
}

/// Evaluates user [tapSamples] against [clickSamples] (§7.6).
///
/// Algorithm:
/// 1. Match each tap to its nearest click; ignore taps farther than half a
///    beat period from any click (`|tap - nearestClick| > period / 2`).
/// 2. Each valid tap yields `offsetMs = (tap - nearestClick) * 1000 / sampleRate`.
/// 3. If fewer than [kCalibrationMinTaps] (16) valid taps, return `needMoreTaps`.
/// 4. Outlier removal: compute `median` and `MAD = median(|x - median|)`.
///    Drop taps with `|x - median| > max(3 * MAD, 10 ms)`.
/// 5. If fewer than [kCalibrationMinInliers] (12) taps remain, or the inliers'
///    MAD exceeds [kCalibrationMaxInlierMadMs], return `tooUneven`.
/// 6. Otherwise return `ready` with `round(median(inliers))` clamped to
///    `[-100, 500]`.
CalibrationEvaluation evaluateCalibrationTaps({
  required List<int> clickSamples,
  required List<int> tapSamples,
  required int sampleRate,
  double bpm = kCalibrationBpm,
}) {
  if (clickSamples.isEmpty || sampleRate <= 0 || bpm <= 0) {
    return const CalibrationEvaluation(
      status: CalibrationStatus.needMoreTaps,
      validTapCount: 0,
      inlierCount: 0,
    );
  }

  final halfPeriodSamples = (sampleRate * 60.0 / bpm) / 2.0;
  final offsetsMs = <double>[];

  for (final tap in tapSamples) {
    final nearest = _nearestSample(clickSamples, tap);
    final diffSamples = tap - nearest;
    if (diffSamples.abs() <= halfPeriodSamples) {
      offsetsMs.add(diffSamples * 1000.0 / sampleRate);
    }
  }

  if (offsetsMs.length < kCalibrationMinTaps) {
    return CalibrationEvaluation(
      status: CalibrationStatus.needMoreTaps,
      validTapCount: offsetsMs.length,
      inlierCount: 0,
    );
  }

  final med = _median(offsetsMs);
  final absDevs = [for (final x in offsetsMs) (x - med).abs()];
  final mad = _median(absDevs);
  final threshold = math.max(3.0 * mad, kCalibrationMinOutlierThresholdMs);

  final inliers = [
    for (final x in offsetsMs)
      if ((x - med).abs() <= threshold) x,
  ];

  if (inliers.length < kCalibrationMinInliers) {
    return CalibrationEvaluation(
      status: CalibrationStatus.tooUneven,
      validTapCount: offsetsMs.length,
      inlierCount: inliers.length,
    );
  }

  final inlierMed = _median(inliers);
  final inlierMad = _median([for (final x in inliers) (x - inlierMed).abs()]);
  if (inlierMad > kCalibrationMaxInlierMadMs) {
    return CalibrationEvaluation(
      status: CalibrationStatus.tooUneven,
      validTapCount: offsetsMs.length,
      inlierCount: inliers.length,
    );
  }

  return CalibrationEvaluation(
    status: CalibrationStatus.ready,
    validTapCount: offsetsMs.length,
    inlierCount: inliers.length,
    offsetMs: inlierMed.round().clamp(kLatencyOffsetMinMs, kLatencyOffsetMaxMs),
  );
}

int _nearestSample(List<int> sorted, int target) {
  var lo = 0;
  var hi = sorted.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid] < target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo == 0) return sorted.first;
  if (lo >= sorted.length) return sorted.last;
  final prev = sorted[lo - 1];
  final curr = sorted[lo];
  return (target - prev).abs() <= (curr - target).abs() ? prev : curr;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final n = sorted.length;
  if (n == 0) return 0.0;
  final mid = n >> 1;
  return n.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0;
}
