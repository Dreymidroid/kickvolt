import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import '../../../core/audio_math/wav_header.dart';
import '../../projects/domain/entities/detection_settings.dart';
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
  // Flux of bins below 4 kHz only: kick and snare hits without hi-hats.
  // Used to decide which pulse level is the beat (§4.3).
  final rawLowMidFlux = Float32List(totalHops);
  final frameLowEnergy = Float32List(totalHops);
  final frameOverallEnergy = Float32List(totalHops);

  final fft = FFT(stftWindowSize);
  final hann = Window.hanning(stftWindowSize);
  final fftBuf = Float64x2List(stftWindowSize);
  final numBins = (stftWindowSize >> 1) + 1; // 1025 positive-frequency bins
  final prevLogMag = Float32List(numBins);

  final maxLowMidBin = math.min(
    numBins - 1,
    (4000.0 * stftWindowSize / sampleRate).floor(),
  );

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
    var lowMidFlux = 0.0;
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
        if (diff > 0.0) {
          flux += diff;
          if (k <= maxLowMidBin) lowMidFlux += diff;
        }
      }
      prevLogMag[k] = logMag;
    }

    rawFlux[hopIndex] = flux;
    rawLowMidFlux[hopIndex] = lowMidFlux;
    frameLowEnergy[hopIndex] = lowE;
    frameOverallEnergy[hopIndex] = totalE;
    hopIndex++;

    // Shift ring left by stftHopSize (512) samples.
    ring.setRange(0, stftWindowSize - stftHopSize, ring, stftHopSize);
    ringFill = stftWindowSize - stftHopSize; // 1536
  }

  // `song.wav` is held open only while reading it (the envelope pass and
  // the refinement pass), never during the CPU-heavy tempo/tracking steps.
  // A cancelled isolate may be killed mid-step, and a killed isolate never
  // runs its `finally`, so an open handle would linger (and on Windows keep
  // the project folder from being deleted).
  var raf = await file.open();
  var rafOpen = true;
  Future<void> closeRaf() async {
    if (!rafOpen) return;
    rafOpen = false;
    await raf.close();
  }

  try {
    // Loudness normalisation: scale the mono mix so the song peaks at
    // [_normalizedPeak]. The log compression, the flux gate and the low-band
    // energies all depend on absolute level, so without this the same song
    // detects differently when it's mastered quieter.
    final peak = await _scanMonoPeak(raf, info, checkCancel);
    if (peak == 0) {
      return BeatAnalysis(
        sampleRate: sampleRate,
        sampleCount: totalFrames,
        hopSize: stftHopSize,
        bpm: 0,
        confidence: 0,
        beatPhaseSample: 0,
        candidates: const <CandidateBeat>[],
        frameLowEnergy: Float32List(totalHops),
        frameOverallEnergy: Float32List(totalHops),
      );
    }
    final gain = math.min(_maxNormalizeGain, _normalizedPeak * 32768 / peak);

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
      final scale = gain / 32768.0;

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
    await closeRaf();

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

    if (rawLowMidFlux.length > 4) {
      rawLowMidFlux[0] = 0.0;
      rawLowMidFlux[1] = 0.0;
      rawLowMidFlux[rawLowMidFlux.length - 1] = 0.0;
    }
    final lowMidEnv = _computeOnsetEnvelope(
      rawLowMidFlux,
      sampleRate: sampleRate,
      hopSize: stftHopSize,
    );

    final tempoEst = _estimateTempo(
      onsetEnv,
      lowMidOnset: lowMidEnv,
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
        onsetEnvelope: onsetEnv,
        lowMidOnsetEnvelope: lowMidEnv,
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
    raf = await file.open();
    rafOpen = true;
    final candidates = await _refineBeatsToSample(
      raf: raf,
      info: info,
      trackedFrames: trackedFrames,
      onsetEnv: onsetEnv,
      frameLowEnergy: frameLowEnergy,
      periodFrames: tempoEst.periodFrames,
      checkCancel: checkCancel,
    );
    await closeRaf();

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

    // M4b §4.3: Local tempo curve & stability (1 s step, 6 s window, Viterbi
    // smoothed, constrained to the global octave around the refined beat period
    // `finalBpm` rather than the raw autocorrelation lag, which can sit on a 2x
    // sub-harmonic when a song steps between two distant tempos).
    final refinedPeriodFrames = finalBpm > 0
        ? (sampleRate / stftHopSize) * 60.0 / finalBpm
        : tempoEst.periodFrames;
    final localTempoResult = _computeLocalTempoCurve(
      onsetEnv,
      lowMidOnset: lowMidEnv,
      sampleRate: sampleRate,
      hopSize: stftHopSize,
      anchorPeriodFrames: refinedPeriodFrames,
    );

    // M4b §4.4: Estimate swing ratio and confidence from onset peaks between
    // consecutive tracked beats.
    final swingEst = _estimateSwingFromBeats(
      onsetEnv: onsetEnv,
      trackedFrames: trackedFrames,
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
      onsetEnvelope: onsetEnv,
      lowMidOnsetEnvelope: lowMidEnv,
      tempoCandidates: tempoEst.candidates,
      localTempo: localTempoResult.blockPeriods,
      tempoStability: localTempoResult.stability,
      swing: swingEst,
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
    await closeRaf();
  }
}

/// Peak level (of 1.0 full scale) every song is normalised to before analysis.
const double _normalizedPeak = 0.9;

/// Don't amplify near-silent files by more than this (+60 dB).
const double _maxNormalizeGain = 1000;

/// Largest absolute value of the mono mix, in 16-bit units. Streams the file
/// in [maxPcmChunkBytes] chunks.
Future<int> _scanMonoPeak(
  RandomAccessFile raf,
  WavInfo info,
  void Function() checkCancel,
) async {
  await raf.setPosition(info.dataOffset);
  final bpf = info.bytesPerFrame;
  final channels = info.channels;
  final buf = Uint8List((maxPcmChunkBytes ~/ bpf) * bpf);
  var remaining = info.frameCount * bpf;
  var peak = 0;
  while (remaining > 0) {
    checkCancel();
    final want = math.min(remaining, buf.length);
    var got = 0;
    while (got < want) {
      final n = await raf.readInto(buf, got, want);
      if (n == 0) break;
      got += n;
    }
    final frames = got ~/ bpf;
    if (frames == 0) break;
    final bd = ByteData.sublistView(buf, 0, frames * bpf);
    var o = 0;
    for (var f = 0; f < frames; f++) {
      var sum = 0;
      for (var c = 0; c < channels; c++) {
        sum += bd.getInt16(o, Endian.little);
        o += 2;
      }
      final v = (sum / channels).abs().round();
      if (v > peak) peak = v;
    }
    remaining -= frames * bpf;
    if (got < want) break;
  }
  return peak;
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
    this.candidates = const <TempoCandidate>[],
  });

  final double bpm;
  final double periodFrames;
  final double confidence;
  final List<TempoCandidate> candidates;
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
  required Float32List lowMidOnset,
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

  // Centered kick/snare (below 4 kHz) onset envelope. Its periodicity marks
  // the beat level: kick and snare land on beats, hi-hats subdivide them.
  // Using bass *energy* here instead rewarded half tempo on kick-on-1-and-3
  // grooves (the kick alone repeats every two beats).
  var meanL = 0.0;
  for (var i = 0; i < n; i++) {
    meanL += lowMidOnset[i];
  }
  meanL /= n;
  final lowFlux = Float32List(n);
  var lowR0 = 0.0;
  for (var i = 0; i < n; i++) {
    final v = lowMidOnset[i] - meanL;
    lowFlux[i] = v;
    lowR0 += v * v;
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
  // M4b §4.4 Swing rule (HEURISTIC):
  // When a track has swung eighth notes at ~2/3 of the beat period T_beat,
  // the autocorrelation has a sub-peak near 2/3 * T_beat (which corresponds to
  // 3/2 * BPM_beat). If bestLag landed on the triplet/swung lag (so 1.5 * bestLag
  // is the true beat period T_beat), or if we are evaluating the 2/3 * T_beat
  // multiplier of a beat lag, we check whether the beat lag T_beat has strong
  // kick/snare periodicity (`lowAcf[T_beat]`) AND explains the swung off-beat
  // (`rawAcf[round(2/3 * T_beat)]`). When it does, we penalise the ×3/2 tempo
  // (2/3 lag) and ×2/3 tempo (3/2 lag) candidates so a 90 BPM shuffle never
  // reads 135 or 60.
  int snapLag(int lagInt, int hiLag) {
    var pk = lagInt;
    for (var d = -1; d <= 1; d++) {
      final k = lagInt + d;
      if (k >= minLag && k <= hiLag && rawAcf[k] > rawAcf[pk]) {
        pk = k;
      }
    }
    return pk;
  }

  // HEURISTIC: Check if a candidate beat lag `beatPk` exhibits swing/shuffle
  // structure (strong kick/snare beat correlation + secondary onset correlation
  // near 2/3 of `beatPk` that is stronger than straight 1/2 subdivision).
  bool isSwingSupportedBeatLag(int beatPk) {
    if (beatPk < minLag || beatPk > maxLag) return false;
    final twoThirds = (beatPk * (2.0 / 3.0)).round();
    final half = (beatPk * 0.5).round();
    if (twoThirds < 2 || twoThirds > maxLag || half < 2) return false;
    final swPk = snapLag(twoThirds, maxLag);
    final halfAcf = rawAcf[half];
    return lowAcf[beatPk] > 0.22 &&
        rawAcf[beatPk] > 0.25 &&
        rawAcf[swPk] > 0.15 &&
        rawAcf[swPk] > halfAcf + 0.04;
  }

  final multipliers = <double>[1.0, 2.0, 0.5, 1.5, 2.0 / 3.0];
  var chosenLag = bestLag;
  var bestCandidateScore = -1.0;

  final bestLagIsBeatWithSwing = isSwingSupportedBeatLag(
    snapLag(bestLag, maxLag),
  );
  final threeHalvesLag = (bestLag * 1.5).round();
  final threeHalvesIsBeatWithSwing =
      threeHalvesLag >= minLag &&
      threeHalvesLag <= maxLag &&
      isSwingSupportedBeatLag(snapLag(threeHalvesLag, maxLag));

  for (final m in multipliers) {
    final cand = bestLag * m;
    final lagInt = cand.round();
    if (lagInt < minLag || lagInt > maxLag) continue;
    final pk = snapLag(lagInt, maxLag);
    var sc = scoreCandidateLag(pk.toDouble());
    // Apply M4b §4.4 swing penalty to ternary (3/2 and 2/3) tempo errors when
    // the beat-level candidate explains both the beat and the swung off-beat.
    if (bestLagIsBeatWithSwing && (m == 1.5 || m == 2.0 / 3.0)) {
      sc *= 0.65;
    } else if (threeHalvesIsBeatWithSwing && m == 1.0) {
      sc *= 0.65;
    }
    if (sc > bestCandidateScore) {
      bestCandidateScore = sc;
      chosenLag = pk;
    }
  }

  // Parabolic interpolation around chosenLag peak for sub-frame period (§4.3).
  double refineLagPeriod(int lagPk) {
    var period = lagPk.toDouble();
    if (lagPk > minLag && lagPk < maxLag) {
      final y0 = rawAcf[lagPk - 1];
      final y1 = rawAcf[lagPk];
      final y2 = rawAcf[lagPk + 1];
      final denom = y0 - 2.0 * y1 + y2;
      if (denom.abs() > 1e-9 && y1 >= y0 && y1 >= y2) {
        final delta = 0.5 * (y0 - y2) / denom;
        if (delta.abs() <= 0.5) {
          period = lagPk + delta;
        }
      }
    }
    return period;
  }

  final refinedPeriod = refineLagPeriod(chosenLag);

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

  // M4b §4.1: Build up to 5 distinct tempoCandidates in 40–240 BPM, best first,
  // including the octave relatives of the winner (×2, ×½, ×3/2, ×2/3).
  final tempoCandidates = _buildTempoCandidates(
    chosenLag: chosenLag,
    winnerPeriod: refinedPeriod,
    winnerBpm: bpm,
    winnerScore: math.max(1e-6, bestCandidateScore),
    framesPerSec: framesPerSec,
    minLag40To240: math.max(2, (framesPerSec * 60.0 / 240.0).floor()),
    maxLag: maxLag,
    rawAcf: rawAcf,
    lowAcf: lowAcf,
    priorWeight: priorWeight,
  );

  return _TempoEstimate(
    bpm: bpm,
    periodFrames: refinedPeriod,
    confidence: confidence,
    candidates: tempoCandidates,
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

// =============================================================================
// M4b (§4.1–§4.4): Tempo candidates, Re-tracking, Varying tempo, Swing feel
// =============================================================================

/// Builds up to 5 distinct [TempoCandidate]s in 40–240 BPM, best first,
/// including the octave relatives of the winner (×2, ×½, ×3/2, ×2/3) when in
/// 40–240 BPM (§4.1).
List<TempoCandidate> _buildTempoCandidates({
  required int chosenLag,
  required double winnerPeriod,
  required double winnerBpm,
  required double winnerScore,
  required double framesPerSec,
  required int minLag40To240,
  required int maxLag,
  required Float64List rawAcf,
  required Float64List lowAcf,
  required double Function(double lag) priorWeight,
}) {
  final rawList =
      <({double bpm, double period, double rawScore, bool isWinner})>[
        (
          bpm: (winnerBpm * 10.0).round() / 10.0,
          period: winnerPeriod,
          rawScore: winnerScore,
          isWinner: true,
        ),
      ];

  double scorePeriod(double period) {
    final pk = period.round().clamp(minLag40To240, maxLag);
    final w = priorWeight(period);
    final acf = pk < rawAcf.length ? math.max(0.0, rawAcf[pk]) : 0.0;
    final low = pk < lowAcf.length ? math.max(0.0, lowAcf[pk]) : 0.0;
    final h2 = (2 * pk <= maxLag && 2 * pk < rawAcf.length)
        ? 0.25 * math.max(0.0, rawAcf[2 * pk])
        : 0.0;
    return math.max(0.05, (acf + h2 + 0.30 * low) * w);
  }

  // Octave relatives of the winner in BPM: ×2, ×1/2, ×3/2, ×2/3.
  const bpmMultipliers = <double>[2.0, 0.5, 1.5, 2.0 / 3.0];
  for (final mult in bpmMultipliers) {
    final relBpm = winnerBpm * mult;
    if (relBpm < 40.0 || relBpm > 240.0) continue;
    final relPeriod = (framesPerSec * 60.0) / relBpm;
    final roundedBpm = (relBpm * 10.0).round() / 10.0;
    if (rawList.any((c) => (c.bpm - roundedBpm).abs() <= 1.5)) continue;
    rawList.add((
      bpm: roundedBpm,
      period: relPeriod,
      rawScore: scorePeriod(relPeriod),
      isWinner: false,
    ));
  }

  // If fewer than 5 candidates (e.g. a relative was outside 40–240), fill from
  // the strongest distinct local autocorrelation peaks in 40–240 BPM.
  if (rawList.length < 5) {
    final peakLags = <({int lag, double score})>[];
    for (var lag = minLag40To240 + 1; lag < maxLag; lag++) {
      if (rawAcf[lag] >= rawAcf[lag - 1] &&
          rawAcf[lag] >= rawAcf[lag + 1] &&
          rawAcf[lag] > 0.05) {
        peakLags.add((lag: lag, score: scorePeriod(lag.toDouble())));
      }
    }
    peakLags.sort((a, b) => b.score.compareTo(a.score));
    for (final pk in peakLags) {
      if (rawList.length >= 5) break;
      final candBpm = ((framesPerSec * 60.0 / pk.lag) * 10.0).round() / 10.0;
      if (candBpm < 40.0 || candBpm > 240.0) continue;
      if (rawList.any((c) => (c.bpm - candBpm).abs() <= 2.0)) continue;
      rawList.add((
        bpm: candBpm,
        period: pk.lag.toDouble(),
        rawScore: pk.score,
        isWinner: false,
      ));
    }
  }

  // Keep winner first (score 1.0), sort the rest by rawScore descending.
  final winner = rawList.first;
  final others = rawList.skip(1).toList()
    ..sort((a, b) => b.rawScore.compareTo(a.rawScore));
  final maxScore = math.max(
    winner.rawScore,
    others.isEmpty ? 0.0 : others.first.rawScore,
  );

  final out = <TempoCandidate>[
    TempoCandidate(bpm: winner.bpm, periodFrames: winner.period, score: 1.0),
    for (final c in others.take(4))
      TempoCandidate(
        bpm: c.bpm,
        periodFrames: c.period,
        score: maxScore > 1e-9
            ? (c.rawScore / maxScore).clamp(0.01, 0.99)
            : 0.5,
      ),
  ];
  return out;
}

/// Pure function that re-tracks beats on a cached [BeatAnalysis] with the
/// user's [TrackingOptions] (chosen tempo and steady/varying mode) and refines
/// each beat to sample accuracy from [wavPath] (§4.2, §4.3).
///
/// When [options] is the default (`targetBpm == null`, `tempoMode == steady`)
/// and [analysis] already has tracked candidates, returns [analysis] unchanged
/// so steady-song results and ½×/2× round-trips are identical to `main` (§4.5).
Future<BeatAnalysis> retrack(
  BeatAnalysis analysis,
  TrackingOptions options, {
  required String wavPath,
  bool Function()? isCancelled,
}) async {
  void checkCancel() {
    if (isCancelled != null && isCancelled()) {
      throw const AnalysisCancelledException();
    }
  }

  checkCancel();
  final onsetEnv = analysis.onsetEnvelope;
  if (onsetEnv.isEmpty || analysis.sampleRate <= 0 || analysis.hopSize <= 0) {
    return analysis;
  }

  // Default option round-trip guarantee (§4.2, §4.5, §8):
  // If steady mode is selected and targetBpm is null (Auto) or matches the
  // analyser's default BPM (when no override is active), return the original
  // analysis if targetBpm is null.
  if (options.tempoMode == TempoMode.steady &&
      options.targetBpm == null &&
      analysis.candidates.isNotEmpty) {
    // Re-running on a cached analysis without an override returns the exact
    // same beats, BPM, and phase as the initial analysis.
    final framesPerSec = analysis.sampleRate / analysis.hopSize;
    final basePeriod = analysis.tempoCandidates.isNotEmpty
        ? analysis.tempoCandidates.first.periodFrames
        : (analysis.bpm > 0 ? framesPerSec * 60.0 / analysis.bpm : 0.0);
    if (basePeriod <= 0) return analysis;

    final trackedFrames = _trackBeatsEllis(onsetEnv, periodFrames: basePeriod);
    checkCancel();

    final file = File(wavPath);
    final info = await readWavInfo(file);
    final raf = await file.open();
    List<CandidateBeat> candidates;
    try {
      candidates = await _refineBeatsToSample(
        raf: raf,
        info: info,
        trackedFrames: trackedFrames,
        onsetEnv: onsetEnv,
        frameLowEnergy: analysis.frameLowEnergy,
        periodFrames: basePeriod,
        checkCancel: checkCancel,
      );
    } finally {
      await raf.close();
    }

    final prelimBpm =
        ((framesPerSec * 60.0 / basePeriod) * 10.0).round() / 10.0;
    final finalBpm = _computeFinalBpmFromBeats(
      candidates,
      sampleRate: analysis.sampleRate,
      fallbackBpm: prelimBpm,
    );
    final gridPeriodSamples = finalBpm > 0
        ? (analysis.sampleRate * 60.0 / finalBpm).round()
        : 1;
    final beatPhaseSample = candidates.isNotEmpty && gridPeriodSamples > 0
        ? candidates.first.sample % gridPeriodSamples
        : 0;
    final swing = _estimateSwingFromBeats(
      onsetEnv: onsetEnv,
      trackedFrames: trackedFrames,
    );

    return analysis.copyWithTracking(
      bpm: finalBpm,
      beatPhaseSample: beatPhaseSample,
      candidates: candidates,
      swing: swing,
    );
  }

  final framesPerSec = analysis.sampleRate / analysis.hopSize;
  final requestedBpm =
      (options.targetBpm ?? (analysis.bpm > 0 ? analysis.bpm : 120.0)).clamp(
        40.0,
        240.0,
      );

  // If the requested BPM matches one of the precomputed tempoCandidates (within
  // 0.15 BPM) AND that candidate's period agrees with `requestedBpm` within 5%
  // (in case `analysis.bpm` was refined by beat intervals away from a sub-harmonic
  // autocorrelation lag), use its parabolically refined periodFrames; otherwise
  // compute directly from requestedBpm.
  double targetPeriodFrames = (framesPerSec * 60.0) / requestedBpm;
  for (final tc in analysis.tempoCandidates) {
    final tcBpmFromPeriod = tc.periodFrames > 0
        ? (framesPerSec * 60.0) / tc.periodFrames
        : 0.0;
    if ((tc.bpm - requestedBpm).abs() <= 0.15 &&
        (tcBpmFromPeriod - requestedBpm).abs() <= 1.5) {
      targetPeriodFrames = tc.periodFrames;
      break;
    }
  }

  final List<int> trackedFrames;
  double medianBpmForVarying = requestedBpm;

  if (options.tempoMode == TempoMode.steady) {
    trackedFrames = _trackBeatsEllis(
      onsetEnv,
      periodFrames: targetPeriodFrames,
    );
  } else {
    // Varying tempo mode (§4.3):
    // Compute or scale the local tempo curve constrained to the chosen octave
    // around `targetPeriodFrames`, interpolate to a per-frame period `P(t)`,
    // and run the varying-period Ellis DP tracker.
    final localCurve = _resolveLocalTempoBlocksForTarget(
      analysis: analysis,
      targetPeriodFrames: targetPeriodFrames,
    );
    final framePeriods = _interpolateBlockPeriodsToFrames(
      blockPeriods: localCurve,
      hopCount: onsetEnv.length,
      framesPerBlock: math.max(1, framesPerSec.round()),
      defaultPeriod: targetPeriodFrames,
    );
    trackedFrames = _trackBeatsEllisVarying(
      onsetEnv,
      framePeriods: framePeriods,
    );
    medianBpmForVarying = _computeMedianBpmFromBlockPeriods(
      localCurve,
      framesPerSec: framesPerSec,
      fallbackBpm: requestedBpm,
    );
  }

  checkCancel();

  final file = File(wavPath);
  final info = await readWavInfo(file);
  final raf = await file.open();
  List<CandidateBeat> candidates;
  try {
    candidates = await _refineBeatsToSample(
      raf: raf,
      info: info,
      trackedFrames: trackedFrames,
      onsetEnv: onsetEnv,
      frameLowEnergy: analysis.frameLowEnergy,
      periodFrames: targetPeriodFrames,
      checkCancel: checkCancel,
    );
  } finally {
    await raf.close();
  }

  final double finalBpm;
  if (options.tempoMode == TempoMode.varying) {
    // §4.3: In varying mode the project's bpm is the median local tempo.
    finalBpm = medianBpmForVarying;
  } else {
    final prelimBpm = (requestedBpm * 10.0).round() / 10.0;
    finalBpm = _computeFinalBpmFromBeats(
      candidates,
      sampleRate: analysis.sampleRate,
      fallbackBpm: prelimBpm,
    );
  }

  final gridPeriodSamples = finalBpm > 0
      ? (analysis.sampleRate * 60.0 / finalBpm).round()
      : 1;
  final beatPhaseSample = candidates.isNotEmpty && gridPeriodSamples > 0
      ? candidates.first.sample % gridPeriodSamples
      : 0;
  final swing = _estimateSwingFromBeats(
    onsetEnv: onsetEnv,
    trackedFrames: trackedFrames,
  );

  return analysis.copyWithTracking(
    bpm: finalBpm,
    beatPhaseSample: beatPhaseSample,
    candidates: candidates,
    swing: swing,
  );
}

/// Output of the sliding-window tempogram and Viterbi path (§4.3).
class _LocalTempoCurve {
  const _LocalTempoCurve({required this.blockPeriods, required this.stability});

  /// One smoothed period value (in hop frames) per ~1 s block.
  final Float32List blockPeriods;

  /// Relative spread of [blockPeriods] after outlier removal.
  final double stability;
}

// HEURISTIC: Viterbi transition penalty weight for local tempo tracking (§4.3).
// Penalises frame-period jumps by `viterbiJumpPenalty * (log(P_k / P_prev))^2`
// so a genuine step change (e.g. 100 -> 140 BPM) transitions cleanly within
// 1–2 blocks while random per-window noise is smoothed out.
const double _viterbiJumpPenalty = 18.0;

/// Computes a smoothed local tempo period curve over 1 s steps using 6 s
/// sliding windows of [onsetEnv], constrained to the global octave around
/// [anchorPeriodFrames] (`[0.62 * P, 1.62 * P]`) so a window cannot flip to
/// half or double tempo (§4.3).
_LocalTempoCurve _computeLocalTempoCurve(
  Float32List onsetEnv, {
  required Float32List lowMidOnset,
  required int sampleRate,
  required int hopSize,
  required double anchorPeriodFrames,
}) {
  final n = onsetEnv.length;
  final framesPerSec = sampleRate / hopSize;
  final blockStep = math.max(1, framesPerSec.round()); // ~1 s step
  final winLen = math.max(
    blockStep * 4,
    (framesPerSec * 6.0).round(),
  ); // ~6 s window

  if (n < blockStep * 3 || anchorPeriodFrames < 2.0) {
    return _LocalTempoCurve(
      blockPeriods: Float32List.fromList([anchorPeriodFrames]),
      stability: 0.0,
    );
  }

  final numBlocks = math.max(1, (n + blockStep - 1) ~/ blockStep);

  // Constrain candidate lags to the global octave around the song's local-period
  // center: first do a quick per-block fundamental-lag scan in
  // `[0.65 * anchor, 1.35 * anchor]` (ratio = 1.35 / 0.65 = 2.07), using the
  // same 2x-harmonic + low-band scoring and sub-harmonic suppression so each
  // window identifies its true fundamental beat lag rather than a 2x sub-harmonic.
  final scanMin = math.max(3, (anchorPeriodFrames * 0.65).floor());
  final scanMax = math.min(winLen ~/ 2, (anchorPeriodFrames * 1.35).ceil());
  final coarseBestLags = <int>[];
  for (var b = 0; b < numBlocks; b++) {
    final center = b * blockStep + (blockStep ~/ 2);
    final wStart = math.max(
      0,
      math.min(math.max(0, n - winLen), center - winLen ~/ 2),
    );
    final wEnd = math.min(n, wStart + winLen);
    final wCount = wEnd - wStart;
    if (wCount <= scanMax + 2) continue;
    var meanO = 0.0;
    for (var t = wStart; t < wEnd; t++) {
      meanO += onsetEnv[t];
    }
    meanO /= wCount;
    var r0 = 0.0;
    for (var t = wStart; t < wEnd; t++) {
      final c = onsetEnv[t] - meanO;
      r0 += c * c;
    }
    if (r0 <= 1e-6) continue;

    final acfLim = math.min(wCount - 2, scanMax * 2 + 1);
    final acfTmp = Float64List(acfLim + 1);
    for (var lag = math.max(2, scanMin ~/ 2); lag <= acfLim; lag++) {
      var sum = 0.0;
      final limit = wEnd - lag;
      for (var t = wStart; t < limit; t++) {
        sum += (onsetEnv[t] - meanO) * (onsetEnv[t + lag] - meanO);
      }
      final cnt = limit - wStart;
      acfTmp[lag] = cnt > 0 ? (sum / cnt) / (r0 / wCount) : 0.0;
    }

    var bestL = anchorPeriodFrames.round().clamp(scanMin, scanMax);
    var bestScore = -1e9;
    for (var lag = scanMin; lag <= scanMax; lag++) {
      var val = math.max(0.0, acfTmp[lag]);
      if (2 * lag <= acfLim) {
        val += 0.25 * math.max(0.0, acfTmp[2 * lag]);
      }
      final halfL = (lag * 0.5).round();
      if (halfL >= scanMin && halfL <= acfLim && acfTmp[halfL] > 0.20) {
        val = math.max(0.0, val - 0.65 * acfTmp[halfL]);
      }
      final bpmHere = (framesPerSec * 60.0) / lag;
      final lr = math.log(bpmHere / 120.0) / math.ln2;
      final w = math.exp(-0.5 * lr * lr);
      final sc = val * w;
      if (sc > bestScore) {
        bestScore = sc;
        bestL = lag;
      }
    }
    coarseBestLags.add(bestL);
  }

  var octaveCenterPeriod = anchorPeriodFrames;
  if (coarseBestLags.length >= 4) {
    final sortedCoarse = [...coarseBestLags]..sort();
    final p20 = sortedCoarse[(sortedCoarse.length * 0.20).floor()];
    final p80 = sortedCoarse[(sortedCoarse.length * 0.80).floor()];
    // Geometric mean of 20th and 80th percentile local periods centers the
    // octave window symmetrically between the slowest and fastest sections.
    final geoMid = math.sqrt(p20 * p80);
    octaveCenterPeriod = geoMid.clamp(
      anchorPeriodFrames * 0.78,
      anchorPeriodFrames * 1.28,
    );
  }

  // Span `[0.73 * center, 1.32 * center]` (ratio = 1.81 < 2.0, strictly under
  // one octave so no 2x harmonic exists in the state space).
  final minLag = math.max(3, (octaveCenterPeriod * 0.73).floor());
  final maxLag = math.min(winLen ~/ 2, (octaveCenterPeriod * 1.32).ceil());
  if (maxLag <= minLag) {
    final flat = Float32List(numBlocks);
    for (var i = 0; i < numBlocks; i++) {
      flat[i] = anchorPeriodFrames;
    }
    return _LocalTempoCurve(blockPeriods: flat, stability: 0.0);
  }

  final numStates = maxLag - minLag + 1;
  // Per-block emission score for each candidate integer lag in [minLag..maxLag].
  final emissions = List<Float64List>.generate(
    numBlocks,
    (_) => Float64List(numStates),
  );
  // Also keep raw window ACF per block for sub-frame parabolic refinement.
  final blockAcf = List<Float64List>.generate(
    numBlocks,
    (_) => Float64List(maxLag + 2),
  );

  for (var b = 0; b < numBlocks; b++) {
    final center = b * blockStep + (blockStep ~/ 2);
    final wStart = math.max(
      0,
      math.min(math.max(0, n - winLen), center - winLen ~/ 2),
    );
    final wEnd = math.min(n, wStart + winLen);
    final wCount = wEnd - wStart;

    if (wCount <= maxLag + 2) {
      for (var s = 0; s < numStates; s++) {
        final lag = minLag + s;
        final dist = math.log(lag / anchorPeriodFrames);
        emissions[b][s] = -2.0 * dist * dist;
      }
      continue;
    }

    var meanO = 0.0;
    for (var t = wStart; t < wEnd; t++) {
      meanO += onsetEnv[t];
    }
    meanO /= wCount;

    var r0 = 0.0;
    for (var t = wStart; t < wEnd; t++) {
      final c = onsetEnv[t] - meanO;
      r0 += c * c;
    }

    if (r0 <= 1e-6) {
      for (var s = 0; s < numStates; s++) {
        final lag = minLag + s;
        final dist = math.log(lag / anchorPeriodFrames);
        emissions[b][s] = -2.0 * dist * dist;
      }
      continue;
    }

    final acf = blockAcf[b];
    final acfMaxLag = math.min(wCount - 2, maxLag * 2 + 2);
    final acfMinLag = math.max(2, minLag ~/ 2);
    final fullAcf = Float64List(acfMaxLag + 1);
    for (var lag = acfMinLag; lag <= acfMaxLag; lag++) {
      var sum = 0.0;
      final limit = wEnd - lag;
      for (var t = wStart; t < limit; t++) {
        sum += (onsetEnv[t] - meanO) * (onsetEnv[t + lag] - meanO);
      }
      final count = limit - wStart;
      final val = count > 0 ? (sum / count) / (r0 / wCount) : 0.0;
      fullAcf[lag] = val;
      if (lag < acf.length) acf[lag] = val;
    }

    for (var s = 0; s < numStates; s++) {
      final lag = minLag + s;
      // Include 2x-lag harmonic support (same as global scoreCandidateLag in §4.3)
      // and penalise sub-harmonic lags when `lag / 2` has strong periodicity.
      final h2 = (2 * lag <= acfMaxLag)
          ? 0.25 * math.max(0.0, fullAcf[2 * lag])
          : 0.0;
      var baseScore = math.max(0.0, acf[lag]) + h2;
      final halfLag = (lag * 0.5).round();
      if (halfLag >= minLag && halfLag <= acfMaxLag) {
        final halfVal = math.max(0.0, fullAcf[halfLag]);
        if (halfVal > 0.20) {
          baseScore = math.max(0.0, baseScore - 0.55 * halfVal);
        }
      }
      // Also penalise 1.5x ternary sub-harmonic lags (e.g. 3/2 * T_100 = 66.7 BPM
      // or 5/4 * T_100 = 80 BPM) when a stronger shorter beat lag `2/3 * lag`
      // exists inside the band.
      final twoThirdsLag = (lag * (2.0 / 3.0)).round();
      if (twoThirdsLag >= minLag && twoThirdsLag <= acfMaxLag) {
        final ttVal = math.max(0.0, fullAcf[twoThirdsLag]);
        if (ttVal > 0.20) {
          baseScore = math.max(0.0, baseScore - 0.45 * ttVal);
        }
      }
      // Also use the global log-normal prior on BPM centered on 120 BPM (§4.3)
      // combined with a gentle anchor prior so windows stay near the true beat level.
      final bpmHere = (framesPerSec * 60.0) / lag;
      final logRatio120 = math.log(bpmHere / 120.0) / math.ln2;
      final prior120 = math.exp(-0.5 * logRatio120 * logRatio120);
      final anchorDist = math.log(lag / anchorPeriodFrames);
      final anchorPrior = math.exp(
        -0.5 * (anchorDist / 0.35) * (anchorDist / 0.35),
      );
      emissions[b][s] =
          baseScore * (0.55 + 0.25 * prior120 + 0.20 * anchorPrior);
    }
  }

  // Viterbi dynamic programming path over candidate lags (§4.3).
  final dp = Float64List(numStates);
  final prevDp = Float64List(numStates);
  final backptr = List<Int32List>.generate(
    numBlocks,
    (_) => Int32List(numStates),
  );

  final logLags = Float64List(numStates);
  for (var s = 0; s < numStates; s++) {
    logLags[s] = math.log(minLag + s);
    prevDp[s] = emissions[0][s];
  }

  for (var b = 1; b < numBlocks; b++) {
    for (var s = 0; s < numStates; s++) {
      final lgS = logLags[s];
      var bestVal = -1e18;
      var bestPrev = s;
      for (var p = 0; p < numStates; p++) {
        final dLog = lgS - logLags[p];
        final val = prevDp[p] - _viterbiJumpPenalty * dLog * dLog;
        if (val > bestVal) {
          bestVal = val;
          bestPrev = p;
        }
      }
      dp[s] = emissions[b][s] + bestVal;
      backptr[b][s] = bestPrev;
    }
    for (var s = 0; s < numStates; s++) {
      prevDp[s] = dp[s];
    }
  }

  var bestLastState = 0;
  var bestLastScore = -1e18;
  for (var s = 0; s < numStates; s++) {
    if (prevDp[s] > bestLastScore) {
      bestLastScore = prevDp[s];
      bestLastState = s;
    }
  }

  final statePath = Int32List(numBlocks);
  var curState = bestLastState;
  for (var b = numBlocks - 1; b >= 0; b--) {
    statePath[b] = curState;
    if (b > 0) {
      curState = backptr[b][curState];
    }
  }

  // Refine each block's integer lag using parabolic interpolation on blockAcf[b].
  final blockPeriods = Float32List(numBlocks);
  for (var b = 0; b < numBlocks; b++) {
    final lag = minLag + statePath[b];
    var refined = lag.toDouble();
    final acf = blockAcf[b];
    if (lag - 1 >= 2 && lag + 1 < acf.length) {
      final y0 = acf[lag - 1];
      final y1 = acf[lag];
      final y2 = acf[lag + 1];
      final denom = y0 - 2.0 * y1 + y2;
      if (denom.abs() > 1e-9 && y1 >= y0 && y1 >= y2) {
        final delta = 0.5 * (y0 - y2) / denom;
        if (delta.abs() <= 0.5) {
          refined = lag + delta;
        }
      }
    }
    blockPeriods[b] = refined;
  }

  // Light 3-point moving average on continuous periods within continuous runs
  // (where consecutive integer states differ by <= 1 frame) so ramps and drifts
  // have smooth sub-frame periods without blurring sharp step changes.
  final smoothed = Float32List(numBlocks);
  for (var b = 0; b < numBlocks; b++) {
    var sum = blockPeriods[b];
    var weight = 1.0;
    if (b > 0 && (statePath[b] - statePath[b - 1]).abs() <= 1) {
      sum += 0.5 * blockPeriods[b - 1];
      weight += 0.5;
    }
    if (b + 1 < numBlocks && (statePath[b + 1] - statePath[b]).abs() <= 1) {
      sum += 0.5 * blockPeriods[b + 1];
      weight += 0.5;
    }
    smoothed[b] = sum / weight;
  }

  final stability = _computeTempoStability(smoothed);
  return _LocalTempoCurve(blockPeriods: smoothed, stability: stability);
}

/// Computes `tempoStability` as the relative spread (`(P85 - P15) / median`)
/// of local periods after trimming the top and bottom 15% as outliers (§4.1, §4.3).
double _computeTempoStability(Float32List blockPeriods) {
  if (blockPeriods.length < 4) return 0.0;
  // Drop first and last block (edge windows) when there are enough blocks.
  final start = blockPeriods.length > 6 ? 1 : 0;
  final end = blockPeriods.length > 6
      ? blockPeriods.length - 1
      : blockPeriods.length;
  final sorted = Float64List.fromList(blockPeriods.sublist(start, end))..sort();
  if (sorted.isEmpty) return 0.0;

  double quantile(double q) {
    final pos = q * (sorted.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] * (1.0 - (pos - lo)) + sorted[hi] * (pos - lo);
  }

  final median = quantile(0.50);
  if (median <= 1e-6) return 0.0;
  final p15 = quantile(0.15);
  final p85 = quantile(0.85);
  return (p85 - p15) / median;
}

/// Resolves the per-block local tempo curve for [targetPeriodFrames] during
/// [retrack] in varying mode.
Float32List _resolveLocalTempoBlocksForTarget({
  required BeatAnalysis analysis,
  required double targetPeriodFrames,
}) {
  if (analysis.onsetEnvelope.isNotEmpty) {
    return _computeLocalTempoCurve(
      analysis.onsetEnvelope,
      lowMidOnset: analysis.lowMidOnsetEnvelope,
      sampleRate: analysis.sampleRate,
      hopSize: analysis.hopSize,
      anchorPeriodFrames: targetPeriodFrames,
    ).blockPeriods;
  }
  if (analysis.localTempo.isEmpty) {
    return Float32List.fromList([targetPeriodFrames]);
  }
  final sorted = Float64List.fromList(analysis.localTempo)..sort();
  final median = sorted[sorted.length ~/ 2];
  final scale = median > 1e-6 ? targetPeriodFrames / median : 1.0;
  final out = Float32List(analysis.localTempo.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = analysis.localTempo[i] * scale;
  }
  return out;
}

/// Linearly interpolates per-block periods to a per-hop-frame period `P(t)` (§4.3).
Float32List _interpolateBlockPeriodsToFrames({
  required Float32List blockPeriods,
  required int hopCount,
  required int framesPerBlock,
  required double defaultPeriod,
}) {
  final out = Float32List(hopCount);
  if (blockPeriods.isEmpty) {
    out.fillRange(0, hopCount, defaultPeriod);
    return out;
  }
  if (blockPeriods.length == 1) {
    out.fillRange(0, hopCount, blockPeriods[0]);
    return out;
  }

  final halfBlock = framesPerBlock * 0.5;
  final lastBlock = blockPeriods.length - 1;
  for (var t = 0; t < hopCount; t++) {
    final pos = (t - halfBlock) / framesPerBlock;
    if (pos <= 0.0) {
      out[t] = blockPeriods[0];
    } else if (pos >= lastBlock) {
      out[t] = blockPeriods[lastBlock];
    } else {
      final b0 = pos.floor();
      final frac = pos - b0;
      out[t] = blockPeriods[b0] * (1.0 - frac) + blockPeriods[b0 + 1] * frac;
    }
  }
  return out;
}

/// Computes median BPM from [blockPeriods], rounded to 0.1 BPM (§4.3).
double _computeMedianBpmFromBlockPeriods(
  Float32List blockPeriods, {
  required double framesPerSec,
  required double fallbackBpm,
}) {
  if (blockPeriods.isEmpty) {
    return (fallbackBpm * 10.0).round() / 10.0;
  }
  final sorted = Float64List.fromList(blockPeriods)..sort();
  final mid = sorted.length ~/ 2;
  final medianPeriod = sorted.length.isOdd
      ? sorted[mid]
      : 0.5 * (sorted[mid - 1] + sorted[mid]);
  if (medianPeriod <= 1e-6) {
    return (fallbackBpm * 10.0).round() / 10.0;
  }
  final bpm = (framesPerSec * 60.0) / medianPeriod;
  return (bpm * 10.0).round() / 10.0;
}

/// Varying-period dynamic-programming beat tracker (Ellis 2007 with local
/// period `P(t)`, §4.3):
/// `C[t] = O[t] + max over tau in [t - 2*P(t), t - P(t)/2] of (C[tau] - alpha * (log((t - tau)/P(t)))^2)`
/// Same `alpha = 100.0` as M4, same backtracking, same `±P(t)/8` peak snapping.
List<int> _trackBeatsEllisVarying(
  Float32List onsetEnv, {
  required Float32List framePeriods,
}) {
  final n = onsetEnv.length;
  if (n == 0 || framePeriods.length != n) return const <int>[];

  const alpha = 100.0;
  const onsetWeight = 12.0;

  // Precompute log(dt) table for fast inner-loop transition penalty evaluation.
  var maxPossibleStep = 4;
  for (var t = 0; t < n; t++) {
    final s = (framePeriods[t] * 2.0).round();
    if (s > maxPossibleStep) maxPossibleStep = s;
  }
  final logDt = Float64List(maxPossibleStep + 2);
  for (var dt = 1; dt < logDt.length; dt++) {
    logDt[dt] = math.log(dt);
  }

  final cScore = Float64List(n);
  final backlink = Int32List(n);

  for (var t = 0; t < n; t++) {
    backlink[t] = -1;
    final pT = math.max(2.0, framePeriods[t]);
    final logPt = math.log(pT);
    final minStep = math.max(1, (pT * 0.5).round());
    final maxStep = math.min(
      logDt.length - 1,
      math.max(minStep + 1, (pT * 2.0).round()),
    );

    final localO = onsetEnv[t] * onsetWeight;
    var bestPrev = 0.0;
    var bestTau = -1;

    final tauMin = math.max(0, t - maxStep);
    final tauMax = t - minStep;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      final dt = t - tau;
      final lg = logDt[dt] - logPt;
      final candidate = cScore[tau] - alpha * lg * lg;
      if (candidate > bestPrev) {
        bestPrev = candidate;
        bestTau = tau;
      }
    }
    cScore[t] = localO + bestPrev;
    backlink[t] = bestTau;
  }

  var lastActive = n - 1;
  for (var t = n - 1; t >= 0; t--) {
    if (onsetEnv[t] > 1.5) {
      lastActive = t;
      break;
    }
  }
  final endPeriod = math.max(2.0, framePeriods[lastActive]);
  final searchEnd = math.min(n - 1, lastActive + (endPeriod * 0.25).round());
  final searchStart = math.max(0, searchEnd - endPeriod.ceil());

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

  // Snap each tracked beat to the strongest O peak within ±P(t)/8 frames (§4.3).
  final snapped = <int>[];
  for (final f in ordered) {
    final pF = math.max(2.0, framePeriods[f]);
    final snapRadius = math.max(1, (pF / 8.0).round());
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

  while (snapped.isNotEmpty && onsetEnv[snapped.first] < 0.35) {
    snapped.removeAt(0);
  }
  while (snapped.isNotEmpty && onsetEnv[snapped.last] < 0.35) {
    snapped.removeLast();
  }

  return snapped;
}

// HEURISTIC: Swing ratio estimation from inter-beat onset peak phases (§4.4).
// After tracking, for each consecutive pair of tracked beats `[f0, f1]`, we
// locate interior onset peaks at fraction `phi = (f - f0) / (f1 - f0)` in
// `[0.25, 0.82]` and accumulate their onset strengths into a smoothed phase
// histogram. A dominant peak near 0.50 = straight; 0.60–0.75 = swung.
SwingEstimate _estimateSwingFromBeats({
  required Float32List onsetEnv,
  required List<int> trackedFrames,
}) {
  if (trackedFrames.length < 8 || onsetEnv.isEmpty) {
    return const SwingEstimate();
  }

  // 60 phase bins spanning [0.25, 0.85] (step 0.01 of a beat).
  const minPhi = 0.25;
  const maxPhi = 0.85;
  const numBins = 60;
  const binWidth = (maxPhi - minPhi) / numBins; // 0.01
  final hist = Float64List(numBins);

  var intervalsWithSubdivision = 0;
  var totalIntervals = 0;

  for (var i = 0; i < trackedFrames.length - 1; i++) {
    final f0 = trackedFrames[i];
    final f1 = trackedFrames[i + 1];
    final span = f1 - f0;
    if (span < 6) continue;
    totalIntervals++;

    var hasInteriorPeak = false;
    final kStart = f0 + math.max<int>(2, (span * 0.25).floor());
    final kEnd = f0 + math.min<int>(span - 2, (span * 0.82).ceil());

    for (var k = kStart; k <= kEnd; k++) {
      final val = onsetEnv[k];
      if (val < 0.35) continue;
      if (val >= onsetEnv[k - 1] && val >= onsetEnv[k + 1]) {
        // Parabolic interpolation of the onset peak frame for sub-frame phase precision.
        var peakFrame = k.toDouble();
        final y0 = onsetEnv[k - 1];
        final y1 = val;
        final y2 = onsetEnv[k + 1];
        final denom = y0 - 2.0 * y1 + y2;
        if (denom.abs() > 1e-6) {
          final delta = 0.5 * (y0 - y2) / denom;
          if (delta.abs() <= 0.5) peakFrame = k + delta;
        }
        final phi = (peakFrame - f0) / span;
        if (phi >= minPhi && phi < maxPhi) {
          hasInteriorPeak = true;
          final centerBin = (phi - minPhi) / binWidth;
          // Deposit with a Gaussian kernel (sigma = 1.5 bins = 0.015 beat)
          // so frame discretization doesn't split a peak across neighbouring bins.
          final bLo = math.max(0, (centerBin - 4).floor());
          final bHi = math.min(numBins - 1, (centerBin + 4).ceil());
          for (var b = bLo; b <= bHi; b++) {
            final d = (b + 0.5 - centerBin) / 1.5;
            hist[b] += val * math.exp(-0.5 * d * d);
          }
        }
      }
    }
    if (hasInteriorPeak) intervalsWithSubdivision++;
  }

  if (totalIntervals < 4 || intervalsWithSubdivision < totalIntervals ~/ 4) {
    return const SwingEstimate();
  }

  var bestBin = 0;
  var peakWeight = 0.0;
  var totalWeight = 0.0;
  for (var b = 0; b < numBins; b++) {
    totalWeight += hist[b];
    if (hist[b] > peakWeight) {
      peakWeight = hist[b];
      bestBin = b;
    }
  }
  if (totalWeight <= 1e-6) return const SwingEstimate();

  final dominantRatio = (minPhi + (bestBin + 0.5) * binWidth).clamp(0.25, 0.85);

  // Concentration of weight within ±0.04 around dominantRatio vs total interior weight.
  var nearPeakWeight = 0.0;
  for (
    var b = math.max(0, bestBin - 4);
    b <= math.min(numBins - 1, bestBin + 4);
    b++
  ) {
    nearPeakWeight += hist[b];
  }
  final concentration = (nearPeakWeight / totalWeight).clamp(0.0, 1.0);
  final coverage = (intervalsWithSubdivision / totalIntervals).clamp(0.0, 1.0);
  final confidence = (concentration * math.min(1.0, coverage * 1.4)).clamp(
    0.0,
    1.0,
  );

  return SwingEstimate(ratio: dominantRatio, confidence: confidence);
}
