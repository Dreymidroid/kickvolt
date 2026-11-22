import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/overview.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('overview_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File writeWav(
    String name, {
    required int sampleRate,
    required int channels,
    required List<int> samples,
  }) {
    final frameCount = samples.length ~/ channels;
    final header = buildWavHeader(
      sampleRate: sampleRate,
      channels: channels,
      frameCount: frameCount,
    );
    final pcm = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      pcm.setInt16(i * 2, samples[i], Endian.little);
    }
    return File('${tmp.path}/$name')
      ..writeAsBytesSync([...header, ...pcm.buffer.asUint8List()]);
  }

  test('computes mono overview with odd final bin and scales to 0..255', () async {
    // sampleRate = 1000 Hz => binFrames = round(1000 / 100) = 10 frames/bin.
    // 23 frames => 3 bins (10, 10, 3).
    final samples = <int>[
      // Bin 0: max abs is 16384 => (16384 * 255) ~/ 32767 = 127
      0, -16384, 100, 200, 0, 0, 0, 0, 0, 0,
      // Bin 1: max abs is 32767 => 255
      1000, -32767, 0, 0, 0, 0, 0, 0, 0, 0,
      // Bin 2 (odd final bin, 3 frames): max abs is 32768 (-32768) => 255
      0, -32768, 50,
    ];
    final wav = writeWav(
      'mono.wav',
      sampleRate: 1000,
      channels: 1,
      samples: samples,
    );

    final ov = await computeOverview(wav.path, maxChunkBytes: 16);
    expect(ov.binFrames, 10);
    expect(ov.binCount, 3);
    expect(ov.bins, [(16384 * 255) ~/ 32767, 255, 255]);
  });

  test('computes stereo overview taking max-abs across both channels', () async {
    // 44100 Hz => binFrames = 441.
    // Create 2 full bins + 50 trailing stereo frames = 932 frames.
    const binFrames = 441;
    const totalFrames = binFrames * 2 + 50;
    final samples = List<int>.filled(totalFrames * 2, 0);

    // Bin 0: left channel has 8000, right channel has -20000 => maxAbs = 20000
    samples[10 * 2] = 8000;
    samples[10 * 2 + 1] = -20000;

    // Bin 1: left channel has -30000, right channel has 12000 => maxAbs = 30000
    samples[(binFrames + 5) * 2] = -30000;
    samples[(binFrames + 5) * 2 + 1] = 12000;

    // Bin 2 (odd final bin): right channel has 10000 => maxAbs = 10000
    samples[(binFrames * 2 + 49) * 2 + 1] = 10000;

    final wav = writeWav(
      'stereo.wav',
      sampleRate: 44100,
      channels: 2,
      samples: samples,
    );

    final ov = await computeOverview(wav.path, maxChunkBytes: 512);
    expect(ov.binFrames, 441);
    expect(ov.binCount, 3);
    expect(ov.bins, [
      (20000 * 255) ~/ 32767,
      (30000 * 255) ~/ 32767,
      (10000 * 255) ~/ 32767,
    ]);
  });

  test('encodeOverview and decodeOverview round-trip with KVOV header', () {
    final original = Overview(
      binFrames: 480,
      bins: Uint8List.fromList([0, 12, 128, 255, 42]),
    );
    final bytes = encodeOverview(original);
    expect(bytes.length, 14 + 5);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'KVOV');

    final bd = ByteData.sublistView(bytes);
    expect(bd.getUint16(4, Endian.little), 1); // version
    expect(bd.getUint32(6, Endian.little), 480); // binFrames
    expect(bd.getUint32(10, Endian.little), 5); // binCount

    final decoded = decodeOverview(bytes);
    expect(decoded, original);
  });

  test('decodeOverview rejects corrupt headers and mismatched lengths', () {
    expect(
      () => decodeOverview(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    final valid = encodeOverview(
      Overview(binFrames: 441, bins: Uint8List.fromList([10, 20])),
    );
    final badMagic = Uint8List.fromList(valid)..[0] = 0x58;
    expect(() => decodeOverview(badMagic), throwsFormatException);

    final badVersion = Uint8List.fromList(valid);
    ByteData.sublistView(badVersion).setUint16(4, 99, Endian.little);
    expect(() => decodeOverview(badVersion), throwsFormatException);

    final truncated = valid.sublist(0, valid.length - 1);
    expect(() => decodeOverview(truncated), throwsFormatException);
  });

  test('thumbnail returns 64 values and preserves local maxima', () {
    final bins = Uint8List(640); // 10 bins per thumbnail bucket
    for (var i = 0; i < bins.length; i++) {
      bins[i] = 20;
    }
    // Put distinct spikes inside specific buckets.
    bins[7] = 210; // bucket 0 (0..9)
    bins[325] = 250; // bucket 32 (320..329)
    bins[639] = 180; // bucket 63 (630..639)

    final ov = Overview(binFrames: 441, bins: bins);
    final thumb = thumbnail(ov, 64);
    expect(thumb.length, 64);
    expect(thumb[0], 210);
    expect(thumb[32], 250);
    expect(thumb[63], 180);
    expect(thumb[1], 20);

    // Also works on shorter inputs and empty inputs.
    final shortThumb = thumbnail(
      Overview(binFrames: 441, bins: Uint8List.fromList([10, 200])),
      64,
    );
    expect(shortThumb.length, 64);
    expect(shortThumb.first, 10);
    expect(shortThumb.last, 200);

    final emptyThumb = thumbnail(Overview.empty, 64);
    expect(emptyThumb, List<int>.filled(64, 0));
  });
}
