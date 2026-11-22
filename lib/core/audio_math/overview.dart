import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'wav_header.dart';

const int overviewFormatVersion = 1;
const int overviewHeaderBytes = 14;
const int overviewThumbnailLength = 64;

/// Coarse (~10 ms per bin) max-abs waveform envelope of a project's `song.wav`.
class Overview {
  const Overview({required this.binFrames, required this.bins});

  static final empty = Overview(binFrames: 441, bins: Uint8List(0));

  /// Number of PCM sample frames aggregated into each bin.
  final int binFrames;

  /// One byte (0–255) per bin: `(maxAbs * 255) ~/ 32767`.
  final Uint8List bins;

  int get binCount => bins.length;

  /// Maximum peak (0.0–1.0) in the sample range `[fromSample, toSample)`.
  double peakBetween(num fromSample, num toSample) {
    if (bins.isEmpty || binFrames <= 0) return 0;
    final a = (fromSample / binFrames).floor().clamp(0, bins.length - 1);
    final b = (toSample / binFrames).ceil().clamp(a + 1, bins.length);
    var m = 0;
    for (var i = a; i < b; i++) {
      if (bins[i] > m) m = bins[i];
    }
    return m / 255.0;
  }

  /// Mean peak (0.0–1.0) in the sample range `[fromSample, toSample)`.
  double meanBetween(num fromSample, num toSample) {
    if (bins.isEmpty || binFrames <= 0) return 0;
    final a = (fromSample / binFrames).floor().clamp(0, bins.length - 1);
    final b = (toSample / binFrames).ceil().clamp(a + 1, bins.length);
    var sum = 0;
    for (var i = a; i < b; i++) {
      sum += bins[i];
    }
    return sum / ((b - a) * 255.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Overview ||
        other.binFrames != binFrames ||
        other.bins.length != bins.length) {
      return false;
    }
    for (var i = 0; i < bins.length; i++) {
      if (other.bins[i] != bins[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(binFrames, Object.hashAll(bins));
}

/// Computes an [Overview] from a 16-bit PCM WAV file in a background isolate,
/// streaming in chunks of at most [maxChunkBytes] (≤ 1 MB).
Future<Overview> computeOverview(
  String wavPath, {
  int maxChunkBytes = 256 * 1024,
}) {
  assert(maxChunkBytes > 0 && maxChunkBytes <= 1024 * 1024);
  return Isolate.run(
    () => _computeOverviewInIsolate(wavPath, maxChunkBytes: maxChunkBytes),
  );
}

Future<Overview> _computeOverviewInIsolate(
  String wavPath, {
  required int maxChunkBytes,
}) async {
  final file = File(wavPath);
  final info = await readWavInfo(file);
  if (info.bitsPerSample != 16) {
    throw WavFormatException(
      'Expected 16-bit PCM WAV, got ${info.bitsPerSample}-bit',
    );
  }
  final binFrames = math.max(1, (info.sampleRate / 100).round());
  final totalFrames = info.frameCount;
  if (totalFrames <= 0) {
    return Overview(binFrames: binFrames, bins: Uint8List(0));
  }

  final binCount = (totalFrames + binFrames - 1) ~/ binFrames;
  final bins = Uint8List(binCount);
  final bytesPerFrame = info.bytesPerFrame;
  final chunkFrames = math.max(1, maxChunkBytes ~/ bytesPerFrame);
  final chunkBuffer = Uint8List(chunkFrames * bytesPerFrame);
  final chunkData = ByteData.sublistView(chunkBuffer);
  final channels = info.channels;

  final raf = await file.open();
  try {
    await raf.setPosition(info.dataOffset);
    var remainingFrames = totalFrames;
    var currentBin = 0;
    var framesInBin = 0;
    var maxAbs = 0;

    while (remainingFrames > 0) {
      final framesToRead = math.min(remainingFrames, chunkFrames);
      final bytesToRead = framesToRead * bytesPerFrame;
      var filled = 0;
      while (filled < bytesToRead) {
        final n = await raf.readInto(chunkBuffer, filled, bytesToRead);
        if (n == 0) break;
        filled += n;
      }
      final framesRead = filled ~/ bytesPerFrame;
      if (framesRead == 0) break;

      var byteOffset = 0;
      for (var f = 0; f < framesRead; f++) {
        for (var c = 0; c < channels; c++) {
          final sample = chunkData.getInt16(byteOffset, Endian.little);
          byteOffset += 2;
          final abs = sample < 0 ? -sample : sample;
          if (abs > maxAbs) maxAbs = abs;
        }
        framesInBin++;
        if (framesInBin == binFrames) {
          bins[currentBin++] = ((maxAbs * 255) ~/ 32767).clamp(0, 255);
          framesInBin = 0;
          maxAbs = 0;
        }
      }
      remainingFrames -= framesRead;
    }

    if (framesInBin > 0 && currentBin < binCount) {
      bins[currentBin++] = ((maxAbs * 255) ~/ 32767).clamp(0, 255);
    }
    return Overview(binFrames: binFrames, bins: bins);
  } finally {
    await raf.close();
  }
}

/// Encodes [overview] into the binary `overview.bin` format:
/// ASCII `KVOV`, `u16 version = 1`, `u32 binFrames`, `u32 binCount`,
/// followed by `binCount` bytes.
Uint8List encodeOverview(Overview overview) {
  final out = Uint8List(overviewHeaderBytes + overview.bins.length);
  out[0] = 0x4B; // K
  out[1] = 0x56; // V
  out[2] = 0x4F; // O
  out[3] = 0x56; // V
  final bd = ByteData.sublistView(out);
  bd.setUint16(4, overviewFormatVersion, Endian.little);
  bd.setUint32(6, overview.binFrames, Endian.little);
  bd.setUint32(10, overview.bins.length, Endian.little);
  out.setRange(overviewHeaderBytes, out.length, overview.bins);
  return out;
}

/// Decodes an [Overview] from `overview.bin` bytes.
Overview decodeOverview(Uint8List bytes) {
  if (bytes.length < overviewHeaderBytes) {
    throw const FormatException('overview.bin is too short');
  }
  if (bytes[0] != 0x4B ||
      bytes[1] != 0x56 ||
      bytes[2] != 0x4F ||
      bytes[3] != 0x56) {
    throw const FormatException('Invalid overview.bin magic');
  }
  final bd = ByteData.sublistView(bytes);
  final version = bd.getUint16(4, Endian.little);
  if (version != overviewFormatVersion) {
    throw FormatException('Unsupported overview.bin version $version');
  }
  final binFrames = bd.getUint32(6, Endian.little);
  final binCount = bd.getUint32(10, Endian.little);
  if (binFrames == 0) {
    throw const FormatException('overview.bin binFrames must be > 0');
  }
  if (bytes.length != overviewHeaderBytes + binCount) {
    throw FormatException(
      'overview.bin length ${bytes.length} does not match binCount $binCount',
    );
  }
  return Overview(
    binFrames: binFrames,
    bins: Uint8List.fromList(bytes.sublist(overviewHeaderBytes)),
  );
}

/// Max-preserving downsample of [overview] (or a raw bin list) to [count]
/// values in `0..255` for the Home card thumbnail.
List<int> thumbnail(Object overview, [int count = overviewThumbnailLength]) {
  final List<int> bins = switch (overview) {
    Overview(:final bins) => bins,
    List<int>() => overview,
    _ => throw ArgumentError.value(
      overview,
      'overview',
      'Expected Overview or List<int>',
    ),
  };
  if (count <= 0) return const <int>[];
  if (bins.isEmpty) return List<int>.filled(count, 0);

  final out = List<int>.filled(count, 0);
  final n = bins.length;
  for (var i = 0; i < count; i++) {
    final start = ((i * n) ~/ count).clamp(0, n - 1);
    final end = math.max(start + 1, ((i + 1) * n) ~/ count).clamp(start + 1, n);
    var maxVal = 0;
    for (var j = start; j < end; j++) {
      final v = bins[j].clamp(0, 255);
      if (v > maxVal) maxVal = v;
    }
    out[i] = maxVal;
  }
  return out;
}
