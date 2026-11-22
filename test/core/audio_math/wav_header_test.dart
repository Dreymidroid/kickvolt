import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wav_header_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File('${tmp.path}/$name')..writeAsBytesSync(bytes);

  Uint8List chunk(String id, List<int> body) {
    final b = BytesBuilder()
      ..add(id.codeUnits)
      ..add(_u32(body.length))
      ..add(body);
    if (body.length.isOdd) b.addByte(0);
    return b.toBytes();
  }

  test('buildWavHeader writes canonical RIFF/WAVE PCM fields', () {
    final h = buildWavHeader(sampleRate: 48000, channels: 2, frameCount: 1000);
    final d = ByteData.sublistView(h);
    expect(h.length, 44);
    expect(String.fromCharCodes(h.sublist(0, 4)), 'RIFF');
    expect(d.getUint32(4, Endian.little), 36 + 4000);
    expect(String.fromCharCodes(h.sublist(8, 16)), 'WAVEfmt ');
    expect(d.getUint32(16, Endian.little), 16);
    expect(d.getUint16(20, Endian.little), 1); // PCM
    expect(d.getUint16(22, Endian.little), 2);
    expect(d.getUint32(24, Endian.little), 48000);
    expect(d.getUint32(28, Endian.little), 48000 * 4); // byte rate
    expect(d.getUint16(32, Endian.little), 4); // block align
    expect(d.getUint16(34, Endian.little), 16);
    expect(String.fromCharCodes(h.sublist(36, 40)), 'data');
    expect(d.getUint32(40, Endian.little), 4000);
  });

  test('readWavInfo round-trips a written header', () async {
    final f = write('a.wav', [
      ...buildWavHeader(sampleRate: 44100, channels: 1, frameCount: 300),
      ...List.filled(600, 0),
    ]);
    final info = await readWavInfo(f);
    expect(info.sampleRate, 44100);
    expect(info.channels, 1);
    expect(info.bitsPerSample, 16);
    expect(info.dataOffset, 44);
    expect(info.frameCount, 300);
  });

  test('skips unknown and odd-sized chunks before data', () async {
    final fmt = ByteData(16)
      ..setUint16(0, 1, Endian.little)
      ..setUint16(2, 2, Endian.little)
      ..setUint32(4, 22050, Endian.little)
      ..setUint32(8, 22050 * 4, Endian.little)
      ..setUint16(12, 4, Endian.little)
      ..setUint16(14, 16, Endian.little);
    final body = BytesBuilder()
      ..add('WAVE'.codeUnits)
      ..add(chunk('LIST', List.filled(7, 1))) // odd: padded
      ..add(chunk('fmt ', fmt.buffer.asUint8List()))
      ..add(chunk('data', List.filled(40, 0)));
    final bytes = body.toBytes();
    final f = write(
      'b.wav',
      ['RIFF'.codeUnits, _u32(bytes.length), bytes].expand((e) => e).toList(),
    );

    final info = await readWavInfo(f);
    expect(info.channels, 2);
    expect(info.sampleRate, 22050);
    expect(info.frameCount, 10);
    expect(info.dataOffset, 12 + (8 + 8) + (8 + 16) + 8);
  });

  test('clamps a data size larger than the file', () async {
    final h = buildWavHeader(sampleRate: 8000, channels: 1, frameCount: 1000);
    final f = write('c.wav', [...h, ...List.filled(100, 0)]);
    expect((await readWavInfo(f)).frameCount, 50);
  });

  test('rejects non-WAV and non-PCM files', () async {
    expect(
      () => readWavInfo(write('d.wav', 'not a wav file at all'.codeUnits)),
      throwsA(isA<WavFormatException>()),
    );
    final h = buildWavHeader(sampleRate: 8000, channels: 1, frameCount: 1);
    ByteData.sublistView(h).setUint16(20, 3, Endian.little); // IEEE float
    expect(
      () => readWavInfo(write('e.wav', [...h, 0, 0])),
      throwsA(isA<WavFormatException>()),
    );
  });
}

List<int> _u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
