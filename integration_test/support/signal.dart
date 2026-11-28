import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';

/// A 16-bit PCM WAV read fully into memory.
class PcmFile {
  PcmFile(this.info, this.pcm);

  final WavInfo info;

  /// Interleaved samples.
  final Int16List pcm;

  int get frames => info.frameCount;
  int get channels => info.channels;

  /// The raw bytes of the `data` chunk.
  Uint8List get dataBytes =>
      pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.length * 2);
}

Future<PcmFile> readPcm16(String path) async {
  final file = File(path);
  final info = await readWavInfo(file);
  if (info.bitsPerSample != 16) {
    throw StateError('$path is ${info.bitsPerSample}-bit, expected 16');
  }
  final raf = await file.open();
  try {
    await raf.setPosition(info.dataOffset);
    final bytes = await raf.read(info.frameCount * info.bytesPerFrame);
    // Copy so the Int16List view is 2-byte aligned.
    final aligned = Uint8List(bytes.length)..setAll(0, bytes);
    return PcmFile(info, aligned.buffer.asInt16List());
  } finally {
    await raf.close();
  }
}

/// Result of [crossCorrelationLag].
class LagResult {
  const LagResult(this.lag, this.fractionalLag, this.peak, this.normalised);

  /// Integer lag (samples) maximising the correlation: positive means
  /// `a` is late relative to `b` (`a[n + lag] ≈ b[n]`).
  final int lag;

  /// Lag refined with parabolic interpolation around the peak.
  final double fractionalLag;
  final double peak;

  /// Peak divided by sqrt(energy(a) * energy(b)); 1 = identical shape.
  final double normalised;

  @override
  String toString() =>
      'lag=$lag (${fractionalLag.toStringAsFixed(2)}) '
      'r=${normalised.toStringAsFixed(4)}';
}

/// Finds the lag of [a] relative to [b] within ±[maxLag] samples by FFT
/// cross-correlation.
LagResult crossCorrelationLag(
  Float64List a,
  Float64List b, {
  int maxLag = 8192,
}) {
  var n = 1;
  while (n < a.length + b.length) {
    n <<= 1;
  }
  final fft = FFT(n);
  final fa = Float64x2List(n);
  final fb = Float64x2List(n);
  for (var i = 0; i < a.length; i++) {
    fa[i] = Float64x2(a[i], 0);
  }
  for (var i = 0; i < b.length; i++) {
    fb[i] = Float64x2(b[i], 0);
  }
  fft
    ..inPlaceFft(fa)
    ..inPlaceFft(fb);
  // A · conj(B)
  for (var i = 0; i < n; i++) {
    final x = fa[i], y = fb[i];
    fa[i] = Float64x2(x.x * y.x + x.y * y.y, x.y * y.x - x.x * y.y);
  }
  final r = fft.realInverseFft(fa);
  double at(int lag) => r[lag >= 0 ? lag : n + lag];

  var best = 0;
  var bestVal = double.negativeInfinity;
  for (var lag = -maxLag; lag <= maxLag; lag++) {
    final v = at(lag);
    if (v > bestVal) {
      bestVal = v;
      best = lag;
    }
  }
  final y0 = at(best - 1), y1 = bestVal, y2 = at(best + 1);
  final denom = y0 - 2 * y1 + y2;
  final frac = denom == 0 ? 0.0 : 0.5 * (y0 - y2) / denom;
  var ea = 0.0, eb = 0.0;
  for (final v in a) {
    ea += v * v;
  }
  for (final v in b) {
    eb += v * v;
  }
  final norm = (ea > 0 && eb > 0) ? bestVal / math.sqrt(ea * eb) : 0.0;
  return LagResult(best, best + frac, bestVal, norm);
}
