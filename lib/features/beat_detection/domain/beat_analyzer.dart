import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import '../../../core/audio_math/wav_header.dart';
import 'entities/beat_analysis.dart';

/// STFT window size in mono sample frames (§4.2).
const int stftWindowSize = 2048;

/// STFT hop size in mono sample frames (§4.2).
const int stftHopSize = 512;

/// Maximum PCM byte buffer used while streaming `song.wav` (256 KB ≤ 1 MB
/// chunk limit and well below the 4 MB peak PCM buffer bar in §4.1 / §4.9).
const int maxPcmChunkBytes = 256 * 1024;

/// Runs the heavy beat analysis pass on [wavPath] in bounded memory (§4.1–§4.4).
///
/// Pure Dart (no Flutter imports) so it can run inside a background isolate
/// and directly in unit tests.
Future<BeatAnalysis> analyzeWavFile(
  String wavPath, {
  void Function(AnalysisProgress progress)? onProgress,
  bool Function()? isCancelled,
}) async {
  void checkCancel() {
    if (isCancelled != null && isCancelled()) {
      throw const AnalysisCancelledException();
    }
  }

  final file = File(wavPath);
  final info = await readWavInfo(file);
  if (info.bitsPerSample != 16) {
    throw WavFormatException(
      'Expected 16-bit PCM WAV, got ${info.bitsPerSample}-bit',
    );
  }

  final sampleRate = info.sampleRate;
  final totalFrames = info.frameCount;
  if (totalFrames <= 0 || sampleRate <= 0) {
    return BeatAnalysis(
      sampleRate: math.max(1, sampleRate),
      sampleCount: 0,
      hopSize: stftHopSize,
      bpm: 0,
      confidence: 0,
      beatPhaseSample: 0,
      candidates: const <CandidateBeat>[],
      frameLowEnergy: Float32List(0),
      frameOverallEnergy: Float32List(0),
    );
  }

  onProgress?.call(
    const AnalysisProgress(stage: AnalysisStage.envelope, fraction: 0.0),
  );

  // ---------------------------------------------------------------------------
  // §4.1 & §4.2: Streaming STFT with centered frames
  // ---------------------------------------------------------------------------
  // Centered frames convention:
  // Frame `t` has length 2048 (`stftWindowSize`) and is centered on mono sample
  // `t * stftHopSize` (512). We achieve this by pre-filling the sliding window
  // with `stftWindowSize ~/ 2` (1024) zeros before sample 0, and appending up
  // to 1024 zeros at the end of the file. An uncentered window would shift
  // every frame by +1024 samples (~23.2 ms at 44.1 kHz).
  final totalHops = (totalFrames + stftHopSize - 1) ~/ stftHopSize;
  final rawFlux = Float32List(totalHops);
  final frameLowEnergy = Float32List(totalHops);
  final frameOverallEnergy = Float32List(totalHops);

  final fft = FFT(stftWindowSize);
  final hann = Window.hanning(stftWindowSize);
  final fftBuf = Float64x2List(stftWindowSize);
  final numBins = (stftWindowSize >> 1) + 1; // 1025 positive-frequency bins
  final prevLogMag = Float32List(numBins);

  // Bins strictly below 150 Hz for low-band energy L[t].
  final maxLowBin = math.min(
    numBins - 1,
    (150.0 * stftWindowSize / sampleRate).floor(),
  );

  // Ring buffer of 2048 mono float samples (-1..1).
  // Starts with 1024 leading zeros for the centered frame t = 0.
  final ring = Float32List(stftWindowSize);
  var ringFill = stftWindowSize ~/ 2; // 1024 zeros already in place
  var hopIndex = 0;

  void processOneStftFrame() {
    for (var i = 0; i < stftWindowSize; i++) {
      fftBuf[i] = Float64x2(ring[i] * hann[i], 0.0);
    }
    fft.inPlaceFft(fftBuf);

    var flux = 0.0;
    var lowE = 0.0;
    var totalE = 0.0;

    for (var k = 1; k < numBins; k++) {
      final z = fftBuf[k];
      final magSq = z.x * z.x + z.y * z.y;
      final mag = math.sqrt(magSq);
      totalE += magSq;
      if (k <= maxLowBin) {
        lowE += magSq;
      }

      // Log magnitude: log(1 + 1000 * |X|) per §4.2
      // Scale |X| by 1 / stftWindowSize so 1000 * |X| sits in the standard
      // normalized spectral magnitude range across window sizes.
      final normMag = mag * (1.0 / stftWindowSize);
      final logMag = math.log(1.0 + 1000.0 * normMag);
      if (hopIndex > 0) {
        final diff = logMag - prevLogMag[k];
        if (diff > 0.0) flux += diff;
      }
      prevLogMag[k] = logMag;
    }

    rawFlux[hopIndex] = flux;
    frameLowEnergy[hopIndex] = lowE;
    frameOverallEnergy[hopIndex] = totalE;
    hopIndex++;

    // Shift ring left by stftHopSize (512) samples.
    ring.setRange(0, stftWindowSize - stftHopSize, ring, stftHopSize);
    ringFill = stftWindowSize - stftHopSize; // 1536
  }

  final raf = await file.open();
  try {
    await raf.setPosition(info.dataOffset);
    final bpf = info.bytesPerFrame;
    final channels = info.channels;
    final byteBuf = Uint8List((maxPcmChunkBytes ~/ bpf) * bpf);
    var remainingFrames = totalFrames;
    var readFrames = 0;
    var lastReportedPct = -1;

    while (remainingFrames > 0) {
      checkCancel();
      final wantBytes = math.min(remainingFrames * bpf, byteBuf.length);
      var gotBytes = 0;
      while (gotBytes < wantBytes) {
        final n = await raf.readInto(byteBuf, gotBytes, wantBytes);
        if (n == 0) break;
        gotBytes += n;
      }
      final framesInChunk = gotBytes ~/ bpf;
      if (framesInChunk == 0) break;

      final bd = ByteData.sublistView(byteBuf, 0, framesInChunk * bpf);
      const scale = 1.0 / 32768.0;

      if (channels == 1) {
        for (var f = 0; f < framesInChunk; f++) {
          ring[ringFill++] = bd.getInt16(f * 2, Endian.little) * scale;
          if (ringFill == stftWindowSize && hopIndex < totalHops) {
            processOneStftFrame();
          }
        }
      } else {
        final invCh = scale / channels;
        var byteOff = 0;
        for (var f = 0; f < framesInChunk; f++) {
          var sum = 0;
          for (var c = 0; c < channels; c++) {
            sum += bd.getInt16(byteOff, Endian.little);
            byteOff += 2;
          }
          ring[ringFill++] = sum * invCh;
          if (ringFill == stftWindowSize && hopIndex < totalHops) {
            processOneStftFrame();
          }
        }
      }

      remainingFrames -= framesInChunk;
      readFrames += framesInChunk;

      final pct = (readFrames * 20) ~/ totalFrames;
      if (pct > lastReportedPct) {
        lastReportedPct = pct;
        onProgress?.call(
          AnalysisProgress(
            stage: AnalysisStage.envelope,
            fraction: (readFrames / totalFrames) * 0.65,
          ),
        );
      }
      if (gotBytes < wantBytes) break;
    }

    // Pad trailing zeros to complete the centered frames up to totalHops.
    while (hopIndex < totalHops) {
      while (ringFill < stftWindowSize) {
        ring[ringFill++] = 0.0;
      }
      processOneStftFrame();
    }

    checkCancel();

    // Detrend rawFlux: subtract moving average (~0.5 s), half-wave rectify,
    // and normalise by the standard deviation -> onset envelope O[t] (§4.2).
    // Skip frame 0 and the last frame when computing rawFlux peaks so file start/end
    // window boundary transients on a sustained chord don't look like beats.
    if (rawFlux.length > 4) {
      rawFlux[0] = 0.0;
      rawFlux[1] = 0.0;
      rawFlux[rawFlux.length - 1] = 0.0;
    }

    final onsetEnv = _computeOnsetEnvelope(
      rawFlux,
      sampleRate: sampleRate,
      hopSize: stftHopSize,
    );

    // -------------------------------------------------------------------------
    // §4.3: Tempo estimation via prior-weighted autocorrelation
    // -------------------------------------------------------------------------
    onProgress?.call(
      const AnalysisProgress(stage: AnalysisStage.tempo, fraction: 0.70),
    );
    checkCancel();

    final tempoEst = _estimateTempo(
      onsetEnv,
      frameLowEnergy: frameLowEnergy,
      sampleRate: sampleRate,
      hopSize: stftHopSize,
    );

    final prelimBpm = (tempoEst.bpm * 10.0).round() / 10.0;
    onProgress?.call(
      AnalysisProgress(
        stage: AnalysisStage.tempo,
        fraction: 0.78,
        bpm: prelimBpm > 0 ? prelimBpm : null,
      ),
    );

    if (tempoEst.periodFrames <= 0 || tempoEst.confidence <= 0) {
      return BeatAnalysis(
        sampleRate: sampleRate,
        sampleCount: totalFrames,
        hopSize: stftHopSize,
        bpm: 0,
        confidence: 0,
        beatPhaseSample: 0,
        candidates: const <CandidateBeat>[],
        frameLowEnergy: frameLowEnergy,
        frameOverallEnergy: frameOverallEnergy,
      );
    }

    // -------------------------------------------------------------------------
    // §4.4: Dynamic-programming beat tracking (Ellis 2007) + peak snapping
    // -------------------------------------------------------------------------
    onProgress?.call(
      AnalysisProgress(
        stage: AnalysisStage.tracking,
        fraction: 0.80,
        bpm: prelimBpm,
      ),
    );
    checkCancel();

    final trackedFrames = _trackBeatsEllis(
      onsetEnv,
      periodFrames: tempoEst.periodFrames,
    );

    // Refine each beat to exact attack sample using a short window of raw PCM
    // from the file via RandomAccessFile (§4.4).
    final candidates = await _refineBeatsToSample(
      raf: raf,
      info: info,
      trackedFrames: trackedFrames,
      onsetEnv: onsetEnv,
      frameLowEnergy: frameLowEnergy,
      periodFrames: tempoEst.periodFrames,
      checkCancel: checkCancel,
    );

    // Compute final BPM from the refined beats (§4.4) to 0.1 BPM.
    final finalBpm = _computeFinalBpmFromBeats(
      candidates,
      sampleRate: sampleRate,
      fallbackBpm: prelimBpm,
    );

    final gridPeriodSamples = finalBpm > 0
        ? (sampleRate * 60.0 / finalBpm).round()
        : 1;
    final beatPhaseSample = candidates.isNotEmpty && gridPeriodSamples > 0
        ? candidates.first.sample % gridPeriodSamples
        : 0;

    // Combine autocorrelation periodicity confidence with beat-grid regularity
    // so steady rhythmic tracks have high confidence and random noise / chords
    // have low confidence.
    final finalConfidence = _computeCombinedConfidence(
      autocorrConfidence: tempoEst.confidence,
      onsetEnv: onsetEnv,
      trackedFrames: trackedFrames,
      periodFrames: tempoEst.periodFrames,
    );

    onProgress?.call(
      AnalysisProgress(
        stage: AnalysisStage.sections,
        fraction: 0.95,
        bpm: finalBpm > 0 ? finalBpm : null,
      ),
    );
    checkCancel();

    final analysis = BeatAnalysis(
      sampleRate: sampleRate,
      sampleCount: totalFrames,
      hopSize: stftHopSize,
      bpm: finalBpm,
      confidence: finalConfidence,
      beatPhaseSample: beatPhaseSample,
      candidates: candidates,
      frameLowEnergy: frameLowEnergy,
      frameOverallEnergy: frameOverallEnergy,
    );

    onProgress?.call(
      AnalysisProgress(
        stage: AnalysisStage.sections,
        fraction: 1.0,
        bpm: finalBpm > 0 ? finalBpm : null,
      ),
    );
    return analysis;
  } finally {
    await raf.close();
  }
}

/// Thrown when an in-flight analysis is cancelled.
class AnalysisCancelledException implements Exception {
  const AnalysisCancelledException();

  @override
  String toString() => 'AnalysisCancelledException';
}

/// Computes `O[t]` from raw spectral flux (§4.2):
/// subtract ~0.5 s moving average, half-wave rectify, and normalise by the
/// standard deviation.
Float32List _computeOnsetEnvelope(
  Float32List rawFlux, {
  required int sampleRate,
  required int hopSize,
}) {
  final n = rawFlux.length;
  if (n == 0) return Float32List(0);

  // Moving average half-window corresponding to ~0.25 s on each side (~0.5 s total).
  final halfWin = math.max(2, (0.25 * sampleRate / hopSize).round());
  final prefix = Float64List(n + 1);
  for (var i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + rawFlux[i];
  }

  final out = Float32List(n);
  var sum = 0.0;
  var sumSq = 0.0;
  for (var i = 0; i < n; i++) {
    final a = math.max(0, i - halfWin);
    final b = math.min(n, i + halfWin + 1);
    final localMean = (prefix[b] - prefix[a]) / (b - a);
    final v = rawFlux[i] - localMean;
    final rectified = v > 0.0 ? v : 0.0;
    out[i] = rectified;
    sum += rectified;
    sumSq += rectified * rectified;
  }

  final mean = sum / n;
  final variance = math.max(0.0, (sumSq / n) - mean * mean);
  final std = math.sqrt(variance);
  // Require meaningful absolute spectral flux variation above steady-state
  // ripple or homogeneous white-noise variance (~0.4–0.5) so a steady sustained
  // chord or stationary noise does not amplify micro-fluctuations into fake
  // unit-variance onsets. Real transient beats produce std > 2.5.
  if (std > 0.75) {
    final invStd = 1.0 / std;
    for (var i = 0; i < n; i++) {
      out[i] *= invStd;
    }
  } else {
    out.fillRange(0, n, 0.0);
  }
  return out;
}

class _TempoEstimate {
  const _TempoEstimate({
    required this.bpm,
    required this.periodFrames,
    required this.confidence,
  });

  final double bpm;
  final double periodFrames;
  final double confidence;
}

/// Estimates tempo from autocorrelation of [onsetEnv] over 40–220 BPM (§4.3).
///
/// Weighting: log-normal prior centred on 120 BPM with σ = 1 octave:
/// `w(lag) = exp(-0.5 * (log2(bpm / 120))^2)`.
/// Half/double ambiguity: for the best lag `T`, also evaluates `2T`, `T/2`,
/// `3T/2` and `2T/3` (where in range), picking the candidate with the highest
/// harmonic-supported weighted score.
/// Confidence: defined as `peakWeighted / meanWeighted` over the 40–220 BPM
/// lag range, scaled by the raw normalized autocorrelation at the peak so
/// flat/random envelopes cannot produce a spurious ratio from the prior alone.
_TempoEstimate _estimateTempo(
  Float32List onsetEnv, {
  required Float32List frameLowEnergy,
  required int sampleRate,
  required int hopSize,
}) {
  final n = onsetEnv.length;
  final framesPerSec = sampleRate / hopSize;
  final minLag = math.max(2, (framesPerSec * 60.0 / 220.0).floor());
  final maxLag = math.min(n - 2, (framesPerSec * 60.0 / 40.0).ceil());
  if (maxLag <= minLag || n < 16) {
    return const _TempoEstimate(bpm: 0, periodFrames: 0, confidence: 0);
  }

  // Zero-lag energy for normalized, zero-mean autocorrelation.
  // Subtracting the mean of O[t] before autocorrelation is essential: because
  // O[t] is half-wave rectified (all >= 0), uncentered autocorrelation of white
  // noise has a constant positive baseline (~0.45), whereas centered
  // autocorrelation measures actual periodic covariance (near 0 for white noise
  // and > 0.35 for periodic beats).
  var meanO = 0.0;
  for (var i = 0; i < n; i++) {
    meanO += onsetEnv[i];
  }
  meanO /= n;

  final centeredO = Float32List(n);
  var r0 = 0.0;
  for (var i = 0; i < n; i++) {
    final c = onsetEnv[i] - meanO;
    centeredO[i] = c;
    r0 += c * c;
  }
  if (r0 <= 1e-8) {
    return const _TempoEstimate(bpm: 0, periodFrames: 0, confidence: 0);
  }

  // Also compute normalized low-band onset envelope to help disambiguate
  // main kick periodicity (128 BPM) from 8th-note hi-hat subdivisions (256 BPM).
  final lowFlux = Float32List(n);
  var lowR0 = 0.0;
  for (var i = 1; i < n; i++) {
    final d = frameLowEnergy[i] - frameLowEnergy[i - 1];
    if (d > 0) {
      final v = math.log(1.0 + d);
      lowFlux[i] = v;
      lowR0 += v * v;
    }
  }

  final rawAcf = Float64List(maxLag + 1);
  final lowAcf = Float64List(maxLag + 1);
  final weightedAcf = Float64List(maxLag + 1);
  final log2 = math.ln2;

  double priorWeight(double lag) {
    final bpm = (framesPerSec * 60.0) / lag;
    final logRatio = math.log(bpm / 120.0) / log2;
    return math.exp(-0.5 * logRatio * logRatio);
  }

  var sumWeighted = 0.0;
  var countLags = 0;
  var bestLag = minLag;
  var bestWeighted = -1.0;

  for (var lag = minLag; lag <= maxLag; lag++) {
    var sum = 0.0;
    var lSum = 0.0;
    final limit = n - lag;
    for (var t = 0; t < limit; t++) {
      sum += centeredO[t] * centeredO[t + lag];
      lSum += lowFlux[t] * lowFlux[t + lag];
    }
    // Unbiased normalization by overlapping length relative to n.
    final normAcf = (sum / limit) / (r0 / n);
    final normLow = lowR0 > 1e-8 ? (lSum / limit) / (lowR0 / n) : 0.0;
    rawAcf[lag] = normAcf;
    lowAcf[lag] = normLow;

    final w = priorWeight(lag.toDouble());
    final val = math.max(0.0, normAcf) * w;
    weightedAcf[lag] = val;
    sumWeighted += val;
    countLags++;

    if (val > bestWeighted) {
      bestWeighted = val;
      bestLag = lag;
    }
  }

  if (bestWeighted <= 0 || countLags == 0) {
    return const _TempoEstimate(bpm: 0, periodFrames: 0, confidence: 0);
  }

  // Helper to evaluate a continuous lag in [minLag, maxLag].
  double scoreCandidateLag(double candidateLag) {
    final lag = candidateLag.round();
    if (lag < minLag || lag > maxLag) return -1.0;
    // Local peak search within ±1 frame of the candidate lag.
    var pk = lag;
    for (var d = -1; d <= 1; d++) {
      final k = lag + d;
      if (k >= minLag && k <= maxLag && rawAcf[k] > rawAcf[pk]) {
        pk = k;
      }
    }
    final w = priorWeight(pk.toDouble());
    // Include low-frequency onset correlation and 2x-lag harmonic support
    // so main kick period beats subdivision period.
    final harmonic2 = (2 * pk <= maxLag) ? 0.25 * rawAcf[2 * pk] : 0.0;
    final lowBonus = 0.30 * math.max(0.0, lowAcf[pk]);
    return (rawAcf[pk] + harmonic2 + lowBonus) * w;
  }

  // §4.3 Half/double ambiguity: score T, 2T, T/2, 3T/2 and 2T/3 (where in range).
  final multipliers = <double>[1.0, 2.0, 0.5, 1.5, 2.0 / 3.0];
  var chosenLag = bestLag;
  var bestCandidateScore = -1.0;

  for (final m in multipliers) {
    final cand = bestLag * m;
    final lagInt = cand.round();
    if (lagInt < minLag || lagInt > maxLag) continue;
    // Snap to local maximum within ±1 frame.
    var pk = lagInt;
    for (var d = -1; d <= 1; d++) {
      final k = lagInt + d;
      if (k >= minLag && k <= maxLag && rawAcf[k] > rawAcf[pk]) {
        pk = k;
      }
    }
    final sc = scoreCandidateLag(pk.toDouble());
    if (sc > bestCandidateScore) {
      bestCandidateScore = sc;
      chosenLag = pk;
    }
  }

  // Parabolic interpolation around chosenLag peak for sub-frame period (§4.3).
  double refinedPeriod = chosenLag.toDouble();
  if (chosenLag > minLag && chosenLag < maxLag) {
    final y0 = rawAcf[chosenLag - 1];
    final y1 = rawAcf[chosenLag];
    final y2 = rawAcf[chosenLag + 1];
    final denom = y0 - 2.0 * y1 + y2;
    if (denom.abs() > 1e-9 && y1 >= y0 && y1 >= y2) {
      final delta = 0.5 * (y0 - y2) / denom;
      if (delta.abs() <= 0.5) {
        refinedPeriod = chosenLag + delta;
      }
    }
  }

  final meanWeighted = sumWeighted / countLags;
  final peakHeightRatio = meanWeighted > 1e-9
      ? weightedAcf[chosenLag] / meanWeighted
      : 0.0;
  // §4.3 Confidence = weighted peak height / mean weighted autocorrelation
  // over the range, gated by the centered autocorrelation peak height so that
  // aperiodic signals (whose centered ACF peak is near zero, e.g. < 0.15 for
  // white noise vs > 0.30 for periodic beats) have low confidence.
  final acfGate = ((rawAcf[chosenLag] - 0.14) / 0.16).clamp(0.0, 1.0);
  final confidence = peakHeightRatio * acfGate;
  final bpm = (framesPerSec * 60.0) / refinedPeriod;

  return _TempoEstimate(
    bpm: bpm,
    periodFrames: refinedPeriod,
    confidence: confidence,
  );
}

/// Dynamic-programming beat tracker (Ellis 2007, §4.4):
/// `C[t] = O[t] + max over tau in [t - 2P, t - P/2] of (C[tau] - alpha * (log((t - tau)/P))^2)`
/// with `alpha = 100`. Backtracks from the best-scoring frame in the last
/// period, then snaps each tracked beat to the strongest `O` peak within
/// `±P/8` frames.
List<int> _trackBeatsEllis(
  Float32List onsetEnv, {
  required double periodFrames,
}) {
  final n = onsetEnv.length;
  if (n == 0 || periodFrames < 2.0) return const <int>[];

  // Note on scaling: O[t] is std-normalised (peaks ~3..12).
  // In Ellis 2007, O[t] and alpha are scaled so the transition penalty
  // alpha * (log(dt / P))^2 balances peak heights. With alpha = 100 as
  // specified in §4.4, we scale O[t] in the DP objective so a 1-frame
  // discretization offset from a non-integer period P isn't over-penalised
  // relative to an onset peak, while keeping alpha = 100.0 literally.
  const alpha = 100.0;
  const onsetWeight = 12.0;

  final minStep = math.max(1, (periodFrames * 0.5).round());
  final maxStep = math.max(minStep + 1, (periodFrames * 2.0).round());

  // Precompute penalty[dt] = alpha * (log(dt / P))^2 for dt in [minStep..maxStep].
  final penalty = Float64List(maxStep + 1);
  for (var dt = minStep; dt <= maxStep; dt++) {
    final lg = math.log(dt / periodFrames);
    penalty[dt] = alpha * lg * lg;
  }

  final cScore = Float64List(n);
  final backlink = Int32List(n);
  for (var t = 0; t < n; t++) {
    backlink[t] = -1;
    final localO = onsetEnv[t] * onsetWeight;
    var bestPrev = 0.0;
    var bestTau = -1;

    final tauMin = math.max(0, t - maxStep);
    final tauMax = t - minStep;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      final dt = t - tau;
      final candidate = cScore[tau] - penalty[dt];
      if (candidate > bestPrev) {
        bestPrev = candidate;
        bestTau = tau;
      }
    }
    cScore[t] = localO + bestPrev;
    backlink[t] = bestTau;
  }

  // Backtrack from the best-scoring frame in the last active period.
  // First find the last frame with significant onset activity so trailing
  // silence at the end of a file doesn't anchor the backtrack on noise.
  var lastActive = n - 1;
  for (var t = n - 1; t >= 0; t--) {
    if (onsetEnv[t] > 1.5) {
      lastActive = t;
      break;
    }
  }
  final searchEnd = math.min(n - 1, lastActive + (periodFrames * 0.25).round());
  final searchStart = math.max(0, searchEnd - periodFrames.ceil());

  var bestEnd = searchEnd;
  var bestEndScore = -1e18;
  for (var t = searchStart; t <= searchEnd; t++) {
    if (cScore[t] > bestEndScore) {
      bestEndScore = cScore[t];
      bestEnd = t;
    }
  }

  final rawFrames = <int>[];
  var cur = bestEnd;
  while (cur >= 0) {
    rawFrames.add(cur);
    cur = backlink[cur];
  }
  final ordered = rawFrames.reversed.toList();

  // Snap each tracked beat to the strongest O peak within ±P/8 frames (§4.4).
  final snapRadius = math.max(1, (periodFrames / 8.0).round());
  final snapped = <int>[];
  for (final f in ordered) {
    final lo = math.max(0, f - snapRadius);
    final hi = math.min(n - 1, f + snapRadius);
    var bestF = f;
    var bestO = onsetEnv[f];
    for (var k = lo; k <= hi; k++) {
      if (onsetEnv[k] > bestO) {
        bestO = onsetEnv[k];
        bestF = k;
      }
    }
    if (snapped.isEmpty || bestF > snapped.last) {
      snapped.add(bestF);
    }
  }

  // Drop leading or trailing ghost beats in silence where local onset peak is
  // near zero and no real attack occurred.
  while (snapped.isNotEmpty && onsetEnv[snapped.first] < 0.35) {
    snapped.removeAt(0);
  }
  while (snapped.isNotEmpty && onsetEnv[snapped.last] < 0.35) {
    snapped.removeLast();
  }

  return snapped;
}

/// Refines each hop-level beat frame to the exact attack sample (§4.4) by
/// reading a short window of raw mono PCM around the frame via [raf].
Future<List<CandidateBeat>> _refineBeatsToSample({
  required RandomAccessFile raf,
  required WavInfo info,
  required List<int> trackedFrames,
  required Float32List onsetEnv,
  required Float32List frameLowEnergy,
  required double periodFrames,
  required void Function() checkCancel,
}) async {
  if (trackedFrames.isEmpty) return const <CandidateBeat>[];

  final totalFrames = info.frameCount;
  final bpf = info.bytesPerFrame;
  final channels = info.channels;

  // Search window around the hop-level frame: ±2 * stftHopSize (±1024 samples)
  // so an attack anywhere inside the STFT frame is captured cleanly.
  const halfWindow = stftHopSize * 2; // 1024 samples
  const maxWinFrames = halfWindow * 2 + 128;
  final byteBuf = Uint8List(maxWinFrames * bpf);
  final monoWin = Float32List(maxWinFrames);
  final diffSq = Float32List(maxWinFrames);

  final refinedSamples = List<int>.filled(trackedFrames.length, 0);
  final rawStrengths = Float64List(trackedFrames.length);
  final rawLowEnergies = Float64List(trackedFrames.length);

  var maxStrength = 1e-9;
  final halfPeriodHops = math.max(1, (periodFrames * 0.5).round());

  for (var idx = 0; idx < trackedFrames.length; idx++) {
    if ((idx & 31) == 0) checkCancel();
    final frameIdx = trackedFrames[idx];
    final centerSample = (frameIdx * stftHopSize).clamp(0, totalFrames - 1);

    final winStart = math.max(0, centerSample - halfWindow);
    final winEnd = math.min(totalFrames, centerSample + halfWindow);
    final winLen = winEnd - winStart;

    var attackSample = centerSample;
    if (winLen > 64) {
      await raf.setPosition(info.dataOffset + winStart * bpf);
      final wantBytes = winLen * bpf;
      var gotBytes = 0;
      while (gotBytes < wantBytes) {
        final r = await raf.readInto(byteBuf, gotBytes, wantBytes);
        if (r == 0) break;
        gotBytes += r;
      }
      final gotFrames = gotBytes ~/ bpf;
      if (gotFrames > 64) {
        final bd = ByteData.sublistView(byteBuf, 0, gotFrames * bpf);
        const scale = 1.0 / 32768.0;
        if (channels == 1) {
          for (var i = 0; i < gotFrames; i++) {
            monoWin[i] = bd.getInt16(i * 2, Endian.little) * scale;
          }
        } else {
          final invCh = scale / channels;
          var o = 0;
          for (var i = 0; i < gotFrames; i++) {
            var s = 0;
            for (var c = 0; c < channels; c++) {
              s += bd.getInt16(o, Endian.little);
              o += 2;
            }
            monoWin[i] = s * invCh;
          }
        }

        attackSample =
            winStart + _findAttackOffsetInWindow(monoWin, diffSq, gotFrames);
      }
    }

    refinedSamples[idx] = attackSample.clamp(0, totalFrames - 1);

    // Peak onset strength around the beat frame.
    var localMaxO = onsetEnv[frameIdx];
    final oLo = math.max(0, frameIdx - 1);
    final oHi = math.min(onsetEnv.length - 1, frameIdx + 1);
    for (var k = oLo; k <= oHi; k++) {
      if (onsetEnv[k] > localMaxO) localMaxO = onsetEnv[k];
    }
    rawStrengths[idx] = localMaxO;
    if (localMaxO > maxStrength) maxStrength = localMaxO;

    // Mean low-band energy over the beat's period [frameIdx, frameIdx + P).
    final lLo = frameIdx.clamp(0, frameLowEnergy.length - 1);
    final lHi = math.min(
      frameLowEnergy.length,
      frameIdx + math.max(1, halfPeriodHops * 2),
    );
    var lSum = 0.0;
    for (var k = lLo; k < lHi; k++) {
      lSum += frameLowEnergy[k];
    }
    rawLowEnergies[idx] = lHi > lLo ? lSum / (lHi - lLo) : 0.0;
  }

  // Normalise strengths to 0..1 over the song.
  final minStrength = rawStrengths.reduce(math.min);
  final span = maxStrength - minStrength;

  final candidates = <CandidateBeat>[];
  for (var i = 0; i < trackedFrames.length; i++) {
    final normStrength = span > 1e-9
        ? ((rawStrengths[i] - minStrength) / span).clamp(0.0, 1.0)
        : 1.0;
    candidates.add(
      CandidateBeat(
        index: i,
        sample: refinedSamples[i],
        strength: normStrength,
        lowEnergy: rawLowEnergies[i],
      ),
    );
  }
  return candidates;
}

/// High-resolution attack finder (§4.4):
/// 1. Computes first-difference squared energy (`d[i] = (x[i] - x[i-1])^2`),
///    which acts as a high-pass filter suppressing any low-frequency sine pad.
/// 2. Evaluates a 64-sample hop / 64-sample window envelope to locate the peak
///    and local floor, then places the beat at the first sample where the
///    short-time high-passed energy rises above the midpoint between the local
///    floor and peak.
/// Convention: a beat's sample is where its attack starts.
int _findAttackOffsetInWindow(
  Float32List mono,
  Float32List diffSq,
  int length,
) {
  if (length <= 64) return length ~/ 2;

  diffSq[0] = 0.0;
  for (var i = 1; i < length; i++) {
    final d = mono[i] - mono[i - 1];
    diffSq[i] = d * d;
  }

  // Prefix sum of diffSq for O(1) window energies.
  final prefix = Float64List(length + 1);
  for (var i = 0; i < length; i++) {
    prefix[i + 1] = prefix[i] + diffSq[i];
  }

  // 1) Coarse 64-sample hop envelope (64-sample window) to find peak region
  // and pre-attack noise floor (§4.4).
  const coarseWin = 64;
  const coarseHop = 64;
  final numCoarse = (length - coarseWin) ~/ coarseHop + 1;
  if (numCoarse <= 1) return length ~/ 2;

  var bestCoarseIdx = 0;
  var peakCoarseE = -1.0;
  for (var c = 0; c < numCoarse; c++) {
    final s = c * coarseHop;
    final e = (prefix[s + coarseWin] - prefix[s]) / coarseWin;
    if (e > peakCoarseE) {
      peakCoarseE = e;
      bestCoarseIdx = c;
    }
  }

  var floorCoarseE = peakCoarseE;
  final floorEnd = math.max(1, bestCoarseIdx);
  for (var c = 0; c < floorEnd; c++) {
    final s = c * coarseHop;
    final e = (prefix[s + coarseWin] - prefix[s]) / coarseWin;
    if (e < floorCoarseE) floorCoarseE = e;
  }

  final coarseMidpoint = 0.5 * (floorCoarseE + peakCoarseE);
  var firstCoarseAbove = bestCoarseIdx;
  for (var c = 0; c <= bestCoarseIdx; c++) {
    final s = c * coarseHop;
    final e = (prefix[s + coarseWin] - prefix[s]) / coarseWin;
    if (e >= coarseMidpoint) {
      firstCoarseAbove = c;
      break;
    }
  }

  // 2) Fine sample-level scan within the rising coarse bucket using a short
  // 16-sample forward energy window `[i, i + 16)` so the returned sample lands
  // right where the attack starts.
  const fineWin = 16;
  final searchStart = math.max(1, (firstCoarseAbove - 1) * coarseHop);
  final searchEnd = math.min(length - fineWin, (bestCoarseIdx + 1) * coarseHop);
  if (searchEnd <= searchStart) {
    return firstCoarseAbove * coarseHop;
  }

  var finePeak = -1.0;
  var fineFloor = double.infinity;
  for (var i = searchStart; i <= searchEnd; i++) {
    final e = (prefix[i + fineWin] - prefix[i]) / fineWin;
    if (e > finePeak) finePeak = e;
    if (i <= searchStart + coarseHop && e < fineFloor) fineFloor = e;
  }
  if (!fineFloor.isFinite) fineFloor = 0.0;

  final fineMidpoint = 0.5 * (fineFloor + finePeak);
  for (var i = searchStart; i <= searchEnd; i++) {
    final e = (prefix[i + fineWin] - prefix[i]) / fineWin;
    if (e >= fineMidpoint) {
      return i;
    }
  }

  return firstCoarseAbove * coarseHop;
}

/// Computes final BPM from the refined beats (§4.4):
/// finds the median inter-beat interval (IBI) and fits a least-squares line
/// of beat sample vs. index over the longest run of steady beats.
/// Reports to 0.1 BPM.
double _computeFinalBpmFromBeats(
  List<CandidateBeat> candidates, {
  required int sampleRate,
  required double fallbackBpm,
}) {
  if (candidates.length < 2) return fallbackBpm;

  final ibis = <double>[];
  for (var i = 1; i < candidates.length; i++) {
    final d = (candidates[i].sample - candidates[i - 1].sample).toDouble();
    if (d > 0) ibis.add(d);
  }
  if (ibis.isEmpty) return fallbackBpm;

  final sortedIbis = [...ibis]..sort();
  final medianIbi = sortedIbis[sortedIbis.length ~/ 2];

  // Find longest contiguous run of beats whose IBIs are within ±12% of medianIbi.
  var bestRunStart = 0;
  var bestRunLen = 1;
  var curRunStart = 0;

  for (var i = 1; i < candidates.length; i++) {
    final d = (candidates[i].sample - candidates[i - 1].sample).toDouble();
    if ((d - medianIbi).abs() <= 0.12 * medianIbi) {
      final len = i - curRunStart + 1;
      if (len > bestRunLen) {
        bestRunLen = len;
        bestRunStart = curRunStart;
      }
    } else {
      curRunStart = i;
    }
  }

  double fittedPeriodSamples = medianIbi;
  if (bestRunLen >= 4) {
    // Ordinary least-squares slope of sample[k] vs k over [bestRunStart..bestRunStart+bestRunLen-1].
    final m = bestRunLen;
    final meanX = (m - 1) / 2.0;
    var meanY = 0.0;
    for (var k = 0; k < m; k++) {
      meanY += candidates[bestRunStart + k].sample;
    }
    meanY /= m;

    var num = 0.0;
    var den = 0.0;
    for (var k = 0; k < m; k++) {
      final dx = k - meanX;
      final dy = candidates[bestRunStart + k].sample - meanY;
      num += dx * dy;
      den += dx * dx;
    }
    if (den > 0 && num > 0) {
      fittedPeriodSamples = num / den;
    }
  }

  final rawBpm = (sampleRate * 60.0) / fittedPeriodSamples;
  return (rawBpm * 10.0).round() / 10.0;
}

/// Combines autocorrelation periodicity confidence with the pulse contrast of
/// the tracked beats so non-rhythmic signals (white noise, sustained chords)
/// reliably score below the steady-beat threshold.
double _computeCombinedConfidence({
  required double autocorrConfidence,
  required Float32List onsetEnv,
  required List<int> trackedFrames,
  required double periodFrames,
}) {
  if (trackedFrames.length < 8 || onsetEnv.isEmpty) return 0.0;
  var beatMean = 0.0;
  for (final f in trackedFrames) {
    beatMean += onsetEnv[f];
  }
  beatMean /= trackedFrames.length;
  // In a rhythmic track, beat peaks average > 2.5 std above the moving mean,
  // whereas in stationary noise or beatings they stay near ~1.8 std.
  if (beatMean < 2.2) {
    return autocorrConfidence * ((beatMean - 1.5) / 0.7).clamp(0.0, 1.0);
  }
  return autocorrConfidence;
}
