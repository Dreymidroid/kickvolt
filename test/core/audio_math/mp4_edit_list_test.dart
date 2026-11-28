import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/mp4_edit_list.dart';

/// Minimal ISO-BMFF builder: just the boxes [addAudioPrimingEditList] reads.
Uint8List _box(String type, List<Uint8List> children, [Uint8List? payload]) {
  final body = BytesBuilder();
  if (payload != null) body.add(payload);
  for (final c in children) {
    body.add(c);
  }
  final b = ByteData(8)..setUint32(0, 8 + body.length);
  for (var i = 0; i < 4; i++) {
    b.setUint8(4 + i, type.codeUnitAt(i));
  }
  return (BytesBuilder()
        ..add(b.buffer.asUint8List())
        ..add(body.toBytes()))
      .toBytes();
}

Uint8List _u32s(List<int> v) {
  final b = ByteData(v.length * 4);
  for (var i = 0; i < v.length; i++) {
    b.setUint32(i * 4, v[i]);
  }
  return b.buffer.asUint8List();
}

/// mvhd/mdhd version 0: fullbox, creation, modification, timescale, duration.
Uint8List _header(String type, int timescale, int duration) =>
    _box(type, const [], _u32s([0, 0, 0, timescale, duration]));

Uint8List _hdlr(String handler) {
  final p = BytesBuilder()
    ..add(_u32s([0, 0]))
    ..add(handler.codeUnits)
    ..add(_u32s([0, 0, 0]))
    ..addByte(0);
  return _box('hdlr', const [], p.toBytes());
}

Uint8List _stco(List<int> offsets) =>
    _box('stco', const [], _u32s([0, offsets.length, ...offsets]));

Uint8List _trak(
  String handler,
  int mediaTimescale,
  List<int> chunkOffsets, {
  bool withEdts = false,
}) {
  return _box('trak', [
    _box('tkhd', const [], _u32s(List.filled(21, 0))),
    if (withEdts)
      _box('edts', [
        _box('elst', const [], _u32s([0, 1, 1000, 1024, 0x00010000])),
      ]),
    _box('mdia', [
      _header('mdhd', mediaTimescale, 441000),
      _hdlr(handler),
      _box('minf', [
        _box('stbl', [_stco(chunkOffsets)]),
      ]),
    ]),
  ]);
}

const _sr = 44100;
const _frames = 441000; // 10 s

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('kv_elst_'));
  tearDown(() => dir.deleteSync(recursive: true));

  final ftyp = _box('ftyp', const [], Uint8List.fromList('M4A '.codeUnits));
  final mdatPayload = Uint8List.fromList(List.generate(4000, (i) => i & 0xFF));

  /// Builds `ftyp, moov, [free], mdat` (moov first, like MediaMuxer) with
  /// the stco pointing at the real mdat payload.
  ({File file, int mdatPayloadOffset}) moovFirst({
    int freeSize = 0,
    bool withVideo = false,
    bool withEdts = false,
  }) {
    Uint8List build(int payloadAt) {
      final moov = _box('moov', [
        _header('mvhd', 1000, 10000),
        if (withVideo) _trak('vide', 30, [payloadAt]),
        _trak('soun', _sr, [payloadAt + 100], withEdts: withEdts),
      ]);
      final free = freeSize > 0
          ? _box('free', const [], Uint8List(freeSize - 8))
          : Uint8List(0);
      return (BytesBuilder()
            ..add(ftyp)
            ..add(moov)
            ..add(free))
          .toBytes();
    }

    // Two passes so the stco offsets point at the actual payload.
    final head = build(0);
    final payloadAt = head.length + 8;
    final bytes =
        (BytesBuilder()
              ..add(build(payloadAt))
              ..add(_box('mdat', const [], mdatPayload)))
            .toBytes();
    final f = File('${dir.path}/a.m4a')..writeAsBytesSync(bytes);
    return (file: f, mdatPayloadOffset: payloadAt);
  }

  /// Reads the first stco entry of the given handler's track by scanning.
  List<int> stcoEntries(Uint8List bytes) {
    final out = <int>[];
    final v = ByteData.sublistView(bytes);
    for (var i = 0; i + 16 <= bytes.length; i++) {
      if (bytes[i + 4] == 0x73 &&
          bytes[i + 5] == 0x74 &&
          bytes[i + 6] == 0x63 &&
          bytes[i + 7] == 0x6f) {
        out.add(v.getUint32(i + 16));
      }
    }
    return out;
  }

  Future<EditListResult> patch(File f) => addAudioPrimingEditList(
    f.path,
    primingFrames: kAndroidAacPrimingFrames,
    validFrames: _frames,
    sampleRate: _sr,
  );

  test('moov before mdat with a roomy free box: mdat does not move', () async {
    final fx = moovFirst(freeSize: 200);
    final before = fx.file.readAsBytesSync();
    expect(await patch(fx.file), EditListResult.added);
    final after = fx.file.readAsBytesSync();
    expect(after.length, before.length, reason: 'free box absorbs 36 bytes');
    // mdat payload untouched at the same offset.
    expect(
      after.sublist(fx.mdatPayloadOffset, fx.mdatPayloadOffset + 4000),
      mdatPayload,
    );
    expect(stcoEntries(after), [fx.mdatPayloadOffset + 100]);
    final elst = await readAudioEditList(fx.file.path);
    expect(elst, isNotNull);
    expect(elst!.mediaTime, 2048);
    expect(elst.segmentDuration, 10000); // 10 s in the 1000 Hz movie timescale
  });

  test('free box of exactly 36 bytes is consumed entirely', () async {
    final fx = moovFirst(freeSize: 36);
    final before = fx.file.readAsBytesSync();
    expect(await patch(fx.file), EditListResult.added);
    final after = fx.file.readAsBytesSync();
    expect(after.length, before.length);
    expect(
      after.sublist(fx.mdatPayloadOffset, fx.mdatPayloadOffset + 4000),
      mdatPayload,
    );
    expect((await readAudioEditList(fx.file.path))!.mediaTime, 2048);
  });

  test('no free box: chunk offsets of every track shift by 36', () async {
    final fx = moovFirst(withVideo: true);
    expect(await patch(fx.file), EditListResult.added);
    final after = fx.file.readAsBytesSync();
    final shifted = fx.mdatPayloadOffset + 36;
    expect(after.sublist(shifted, shifted + 4000), mdatPayload);
    expect(stcoEntries(after), [shifted, shifted + 100]);
    expect(File('${fx.file.path}.elst.tmp').existsSync(), isFalse);
  });

  test('only the sound track gets the edit list', () async {
    final fx = moovFirst(freeSize: 100, withVideo: true);
    expect(await patch(fx.file), EditListResult.added);
    final bytes = fx.file.readAsBytesSync();
    final edtsCount = RegExp('edts')
        .allMatches(String.fromCharCodes(bytes))
        .length;
    expect(edtsCount, 1);
    expect((await readAudioEditList(fx.file.path))!.mediaTime, 2048);
  });

  test('an existing edit list (AVAssetWriter) is left alone', () async {
    final fx = moovFirst(freeSize: 100, withEdts: true);
    final before = fx.file.readAsBytesSync();
    expect(await patch(fx.file), EditListResult.alreadyPresent);
    expect(fx.file.readAsBytesSync(), before);
  });

  test('moov after mdat: moov rewritten at the end, mdat untouched', () async {
    // ftyp, mdat, moov.
    final mdat = _box('mdat', const [], mdatPayload);
    final payloadAt = ftyp.length + 8;
    final moov = _box('moov', [
      _header('mvhd', 1000, 10000),
      _trak('soun', _sr, [payloadAt]),
    ]);
    final f = File('${dir.path}/b.m4a')
      ..writeAsBytesSync(
        (BytesBuilder()
              ..add(ftyp)
              ..add(mdat)
              ..add(moov))
            .toBytes(),
      );
    final before = f.lengthSync();
    expect(await patch(f), EditListResult.added);
    final after = f.readAsBytesSync();
    expect(after.length, before + 36);
    expect(after.sublist(payloadAt, payloadAt + 4000), mdatPayload);
    expect(stcoEntries(after), [payloadAt]);
    expect((await readAudioEditList(f.path))!.mediaTime, 2048);
  });

  test('media time is scaled to the track timescale', () async {
    final fx = moovFirst(freeSize: 100);
    // mdhd timescale 44100 == sample rate, so priming maps 1:1; a 48 kHz
    // source in a 44.1 kHz track would scale (checked via the formula).
    await addAudioPrimingEditList(
      fx.file.path,
      primingFrames: 2048,
      validFrames: 480000,
      sampleRate: 48000,
    );
    final elst = await readAudioEditList(fx.file.path);
    expect(elst!.mediaTime, 2048 * _sr ~/ 48000);
    expect(elst.segmentDuration, 10000);
  });

  test('no audio track: unsupported, untouched', () async {
    final moov = _box('moov', [
      _header('mvhd', 1000, 10000),
      _trak('vide', 30, [100]),
    ]);
    final f = File('${dir.path}/v.mp4')
      ..writeAsBytesSync(
        (BytesBuilder()
              ..add(ftyp)
              ..add(moov))
            .toBytes(),
      );
    final before = f.readAsBytesSync();
    expect(await patch(f), EditListResult.unsupported);
    expect(f.readAsBytesSync(), before);
  });
}
