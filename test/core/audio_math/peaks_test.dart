import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/peaks.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';

/// Deterministic noisy stereo signal with a loud burst in the middle.
Int16List stereoSignal(int frames, {int seed = 1}) {
  final rnd = math.Random(seed);
  final out = Int16List(frames * 2);
  for (var f = 0; f < frames; f++) {
    final amp = (f > frames ~/ 2 && f < frames ~/ 2 + 300) ? 30000 : 8000;
    out[2 * f] = rnd.nextInt(2 * amp) - amp;
    out[2 * f + 1] = rnd.nextInt(2 * amp) - amp;
  }
  return out;
}

Int16List monoMix(Int16List stereo) => Int16List.fromList([
  for (var f = 0; f < stereo.length ~/ 2; f++)
    ((stereo[2 * f] + stereo[2 * f + 1]) / 2).round(),
]);

(int, int) bruteMinMax(Int16List mono, int from, int to) {
  var lo = 32767, hi = -32768;
  for (var i = from; i < to; i++) {
    lo = math.min(lo, mono[i]);
    hi = math.max(hi, mono[i]);
  }
  return (lo, hi);
}

void main() {
  const frames = 100003; // not a multiple of any bucket size
  final stereo = stereoSignal(frames);
  final mono = monoMix(stereo);
  final pyramid = peaksFromPcm(stereo, 2);

  test('every level matches brute force over its buckets', () {
    expect(pyramid.frameCount, frames);
    expect(pyramid.levels.map((l) => l.framesPerBucket), peakLevelFrames);
    for (final level in pyramid.levels) {
      final fpb = level.framesPerBucket;
      expect(level.bucketCount, (frames + fpb - 1) ~/ fpb);
      for (var b = 0; b < level.bucketCount; b++) {
        final (lo, hi) = bruteMinMax(
          mono,
          b * fpb,
          math.min(frames, (b + 1) * fpb),
        );
        expect(level.data[2 * b], lo, reason: 'level $fpb bucket $b min');
        expect(level.data[2 * b + 1], hi, reason: 'level $fpb bucket $b max');
      }
    }
  });

  test('levelFor picks the coarsest level no wider than a column', () {
    expect(pyramid.levelFor(10), isNull);
    expect(pyramid.levelFor(64)!.framesPerBucket, 64);
    expect(pyramid.levelFor(300)!.framesPerBucket, 256);
    expect(pyramid.levelFor(5000)!.framesPerBucket, 4096);
    expect(pyramid.levelFor(1e9)!.framesPerBucket, 16384);
  });

  test('bucket-aligned columns are exact', () {
    const cols = 40;
    final mn = Float32List(cols), mx = Float32List(cols);
    pyramid.fillColumns(
      fromFrame: 1024.0 * 3,
      framesPerColumn: 1024,
      columns: cols,
      outMin: mn,
      outMax: mx,
    );
    for (var k = 0; k < cols; k++) {
      final a = 1024 * (3 + k);
      final (lo, hi) = bruteMinMax(mono, a, math.min(frames, a + 1024));
      expect(mn[k], closeTo(lo / 32768, 1e-6));
      expect(mx[k], closeTo(hi / 32768, 1e-6));
    }
  });

  test('unaligned columns bound the true range within one bucket', () {
    const cols = 50;
    const fpc = 777.3;
    const start = 1234.5;
    final mn = Float32List(cols), mx = Float32List(cols);
    pyramid.fillColumns(
      fromFrame: start,
      framesPerColumn: fpc,
      columns: cols,
      outMin: mn,
      outMax: mx,
    );
    for (var k = 0; k < cols; k++) {
      final a = (start + k * fpc).floor();
      final b = (start + (k + 1) * fpc).ceil();
      final (lo, hi) = bruteMinMax(mono, a, b);
      // Never narrower than the truth...
      expect(mn[k], lessThanOrEqualTo(lo / 32768 + 1e-6));
      expect(mx[k], greaterThanOrEqualTo(hi / 32768 - 1e-6));
      // ...and no wider than the truth padded by one 256-frame bucket.
      final (plo, phi) = bruteMinMax(
        mono,
        math.max(0, a - 256),
        math.min(frames, b + 256),
      );
      expect(mn[k], greaterThanOrEqualTo(plo / 32768 - 1e-6));
      expect(mx[k], lessThanOrEqualTo(phi / 32768 + 1e-6));
    }
  });

  test('columns outside the song are NaN', () {
    final mn = Float32List(4), mx = Float32List(4);
    pyramid.fillColumns(
      fromFrame: -200,
      framesPerColumn: 100,
      columns: 4,
      outMin: mn,
      outMax: mx,
    );
    expect(mn[0].isNaN && mn[1].isNaN, isTrue);
    expect(mn[2].isNaN, isFalse);
    pyramid.fillColumns(
      fromFrame: frames + 10.0,
      framesPerColumn: 100,
      columns: 1,
      outMin: mn,
      outMax: mx,
    );
    expect(mx[0].isNaN, isTrue);
  });

  test('deep zoom uses raw PCM when the window covers it', () {
    const from = 50000;
    final raw = PcmWindow(
      from - 100,
      Int16List.sublistView(mono, from - 100, from + 2000),
    );
    const cols = 100;
    final mn = Float32List(cols), mx = Float32List(cols);
    pyramid.fillColumns(
      fromFrame: from.toDouble(),
      framesPerColumn: 3,
      columns: cols,
      outMin: mn,
      outMax: mx,
      raw: raw,
    );
    for (var k = 0; k < cols; k++) {
      final (lo, hi) = bruteMinMax(mono, from + 3 * k, from + 3 * k + 3);
      expect(mn[k], closeTo(lo / 32768, 1e-6));
      expect(mx[k], closeTo(hi / 32768, 1e-6));
    }
  });

  test('without raw PCM, deep zoom falls back to the finest level', () {
    final mn = Float32List(1), mx = Float32List(1);
    pyramid.fillColumns(
      fromFrame: 640,
      framesPerColumn: 3,
      columns: 1,
      outMin: mn,
      outMax: mx,
    );
    final (lo, hi) = bruteMinMax(mono, 640, 704);
    expect(mn[0], closeTo(lo / 32768, 1e-6));
    expect(mx[0], closeTo(hi / 32768, 1e-6));
  });

  test('encode/decode round trip and rejects garbage', () {
    final back = decodePeaks(encodePeaks(pyramid));
    expect(back.frameCount, frames);
    for (var i = 0; i < pyramid.levels.length; i++) {
      expect(back.levels[i].framesPerBucket, pyramid.levels[i].framesPerBucket);
      expect(back.levels[i].data, pyramid.levels[i].data);
    }
    expect(
      () => decodePeaks(Uint8List.fromList('nope'.codeUnits)),
      throwsFormatException,
    );
    final truncated = encodePeaks(pyramid);
    expect(
      () => decodePeaks(
        Uint8List.sublistView(truncated, 0, truncated.length - 3),
      ),
      throwsFormatException,
    );
  });

  test('computePeaks on a WAV file matches the in-memory build', () async {
    final dir = Directory.systemTemp.createTempSync('peaks_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final wav = File('${dir.path}/song.wav');
    final bytes = BytesBuilder()
      ..add(buildWavHeader(sampleRate: 44100, channels: 2, frameCount: frames))
      ..add(
        stereo.buffer.asUint8List(stereo.offsetInBytes, stereo.lengthInBytes),
      );
    wav.writeAsBytesSync(bytes.toBytes());

    // Small chunks so reads split mid-bucket.
    final fromFile = await computePeaks(wav.path, chunkBytes: 1000);
    expect(fromFile.frameCount, frames);
    for (var i = 0; i < pyramid.levels.length; i++) {
      expect(fromFile.levels[i].data, pyramid.levels[i].data);
    }
  });

  test('mono input is used as is', () {
    final p = peaksFromPcm(Int16List.fromList([5, -7, 3, 9]), 1);
    expect(p.levels.first.data, [-7, 9]);
  });
}
