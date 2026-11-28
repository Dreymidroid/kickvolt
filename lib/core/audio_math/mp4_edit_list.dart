import 'dart:io';
import 'dart:typed_data';

/// Encoder delay ("priming") of the AAC-LC encoders KickVolt uses on Android
/// (`c2.android.aac.encoder` / FDK), in sample frames. Measured on a device
/// (Xiaomi 23106RN0DA, Android 14) by cross-correlating an encoded fixture
/// with its source: exactly 2048 at 44.1 and 48 kHz.
///
/// HEURISTIC: other vendors' AAC encoders may prime differently (Apple's is
/// 2112). A wrong value shifts the song and the guide track by the same
/// amount, so beat packs stay in sync; only the absolute alignment against
/// the original PCM is off by the difference.
const int kAndroidAacPrimingFrames = 2048;

/// Result of [addAudioPrimingEditList].
enum EditListResult {
  /// An `edts/elst` box was added to the audio track.
  added,

  /// The audio track already had an edit list (for example written by
  /// AVAssetWriter); the file was left untouched.
  alreadyPresent,

  /// The file has no audio track or a layout this writer doesn't handle
  /// (64-bit box sizes in `moov`); the file was left untouched.
  unsupported,
}

/// Adds an ISO-BMFF edit list to the audio track of the MP4/M4A at [path]
/// so players and decoders skip the encoder's [primingFrames] and play
/// exactly [validFrames] frames (iTunes/ffmpeg-style gapless metadata).
///
/// Android's `MediaMuxer` writes no edit list, so an AAC file it produces
/// starts with ~46 ms of encoder priming in every decoder. Android's
/// `MPEG4Extractor` turns this edit list into `encoder-delay` /
/// `encoder-padding`, which `WavDecoder` trims; AVFoundation, CapCut and VN
/// honour it directly.
///
/// The `moov` box is rewritten in place. When it sits before `mdat` (the
/// muxer's usual layout), the 36 extra bytes come out of a following `free`
/// box if there is room; otherwise every `stco`/`co64` chunk offset is
/// shifted and the file is rewritten through a temporary file.
Future<EditListResult> addAudioPrimingEditList(
  String path, {
  required int primingFrames,
  required int validFrames,
  required int sampleRate,
}) async {
  if (primingFrames < 0 || validFrames <= 0 || sampleRate <= 0) {
    throw ArgumentError('Invalid frame counts or sample rate');
  }
  final file = File(path);
  final raf = await file.open(mode: FileMode.append);
  try {
    final length = await raf.length();
    final top = await _readTopLevelBoxes(raf, length);
    final moovIndex = top.indexWhere((b) => b.type == 'moov');
    if (moovIndex < 0) return EditListResult.unsupported;
    final moov = top[moovIndex];
    if (moov.headerSize != 8) return EditListResult.unsupported;

    await raf.setPosition(moov.offset);
    final moovBytes = Uint8List.fromList(await raf.read(moov.size));
    final patch = _buildPatchedMoov(
      moovBytes,
      primingFrames: primingFrames,
      validFrames: validFrames,
      sampleRate: sampleRate,
    );
    if (patch.result != EditListResult.added) return patch.result;

    final delta = patch.moov.length - moov.size;
    final moovEnd = moov.offset + moov.size;
    final mdatAfterMoov = top.any(
      (b) => b.type == 'mdat' && b.offset >= moovEnd,
    );

    if (!mdatAfterMoov) {
      // moov after the media data: nothing points past it, so rewrite moov
      // and whatever small boxes follow it.
      await raf.setPosition(moovEnd);
      final tail = await raf.read(length - moovEnd);
      await raf.setPosition(moov.offset);
      await raf.writeFrom(patch.moov);
      await raf.writeFrom(tail);
      await raf.flush();
      return EditListResult.added;
    }

    final next = moovIndex + 1 < top.length ? top[moovIndex + 1] : null;
    if (next != null &&
        next.type == 'free' &&
        next.headerSize == 8 &&
        (next.size == delta || next.size >= delta + 8)) {
      // Take the bytes out of the free box: mdat doesn't move.
      await raf.setPosition(moov.offset);
      await raf.writeFrom(patch.moov);
      final remaining = next.size - delta;
      if (remaining > 0) {
        final header = ByteData(8)
          ..setUint32(0, remaining)
          ..setUint8(4, 0x66) // f
          ..setUint8(5, 0x72) // r
          ..setUint8(6, 0x65) // e
          ..setUint8(7, 0x65); // e
        await raf.writeFrom(header.buffer.asUint8List());
      }
      await raf.flush();
      return EditListResult.added;
    }

    // No room: shift chunk offsets and rewrite the file after moov.
    final shifted = _shiftChunkOffsets(patch.moov, delta);
    if (shifted == null) return EditListResult.unsupported;
    await raf.close();
    await _rewriteWithNewMoov(file, moov, shifted, length);
    return EditListResult.added;
  } finally {
    try {
      await raf.close();
    } catch (_) {
      // Already closed on the rewrite path.
    }
  }
}

class _Box {
  _Box(this.type, this.offset, this.size, this.headerSize);

  final String type;
  final int offset;
  final int size;
  final int headerSize;
}

Future<List<_Box>> _readTopLevelBoxes(RandomAccessFile raf, int length) async {
  final boxes = <_Box>[];
  var pos = 0;
  while (pos + 8 <= length) {
    await raf.setPosition(pos);
    final h = ByteData.sublistView(Uint8List.fromList(await raf.read(16)));
    var size = h.getUint32(0);
    final type = String.fromCharCodes(h.buffer.asUint8List(4, 4));
    var headerSize = 8;
    if (size == 1) {
      if (h.lengthInBytes < 16) break;
      size = h.getUint64(8);
      headerSize = 16;
    } else if (size == 0) {
      size = length - pos;
    }
    if (size < headerSize || pos + size > length) break;
    boxes.add(_Box(type, pos, size, headerSize));
    pos += size;
  }
  return boxes;
}

/// Children of the box at [start] (header included) inside [data], assuming
/// 32-bit sizes. Returns null on a malformed or 64-bit layout.
List<_Box>? _children(Uint8List data, int start, int size, {int skip = 0}) {
  final view = ByteData.sublistView(data);
  final out = <_Box>[];
  var pos = start + 8 + skip;
  final end = start + size;
  while (pos + 8 <= end) {
    final s = view.getUint32(pos);
    if (s < 8 || pos + s > end) return null;
    out.add(
      _Box(String.fromCharCodes(data.sublist(pos + 4, pos + 8)), pos, s, 8),
    );
    pos += s;
  }
  return out;
}

_Box? _find(List<_Box> boxes, String type) {
  for (final b in boxes) {
    if (b.type == type) return b;
  }
  return null;
}

/// Timescale of an `mvhd` or `mdhd` full box.
int _timescale(Uint8List data, _Box box) {
  final view = ByteData.sublistView(data);
  final version = data[box.offset + 8];
  // fullbox header (4) + creation/modification (2×4 or 2×8).
  final at = box.offset + 12 + (version == 1 ? 16 : 8);
  return view.getUint32(at);
}

class _Patch {
  _Patch(this.result, [Uint8List? moov]) : moov = moov ?? Uint8List(0);

  final EditListResult result;
  final Uint8List moov;
}

_Patch _buildPatchedMoov(
  Uint8List moov, {
  required int primingFrames,
  required int validFrames,
  required int sampleRate,
}) {
  final top = _children(moov, 0, moov.length);
  if (top == null) return _Patch(EditListResult.unsupported);
  final mvhd = _find(top, 'mvhd');
  if (mvhd == null) return _Patch(EditListResult.unsupported);
  final movieTimescale = _timescale(moov, mvhd);

  for (final trak in top.where((b) => b.type == 'trak')) {
    final kids = _children(moov, trak.offset, trak.size);
    if (kids == null) continue;
    final mdia = _find(kids, 'mdia');
    final tkhd = _find(kids, 'tkhd');
    if (mdia == null || tkhd == null) continue;
    final mdiaKids = _children(moov, mdia.offset, mdia.size);
    if (mdiaKids == null) continue;
    final hdlr = _find(mdiaKids, 'hdlr');
    final mdhd = _find(mdiaKids, 'mdhd');
    if (hdlr == null || mdhd == null) continue;
    // hdlr: header(8) + fullbox(4) + pre_defined(4) + handler_type(4).
    final handler = String.fromCharCodes(
      moov.sublist(hdlr.offset + 16, hdlr.offset + 20),
    );
    if (handler != 'soun') continue;
    if (_find(kids, 'edts') != null) {
      return _Patch(EditListResult.alreadyPresent);
    }

    final mediaTimescale = _timescale(moov, mdhd);
    final mediaTime = (primingFrames * mediaTimescale) ~/ sampleRate;
    final segment =
        (validFrames * movieTimescale + sampleRate ~/ 2) ~/ sampleRate;
    final edts = _edts(segmentDuration: segment, mediaTime: mediaTime);

    final insertAt = tkhd.offset + tkhd.size;
    final out = Uint8List(moov.length + edts.length)
      ..setRange(0, insertAt, moov)
      ..setRange(insertAt, insertAt + edts.length, edts)
      ..setRange(
        insertAt + edts.length,
        moov.length + edts.length,
        moov,
        insertAt,
      );
    final view = ByteData.sublistView(out);
    view.setUint32(0, moov.length + edts.length); // moov
    view.setUint32(trak.offset, trak.size + edts.length); // trak
    return _Patch(EditListResult.added, out);
  }
  return _Patch(EditListResult.unsupported);
}

Uint8List _edts({required int segmentDuration, required int mediaTime}) {
  final v1 = segmentDuration > 0xFFFFFFFF;
  final entryBytes = v1 ? 20 : 12;
  final elstSize = 16 + entryBytes;
  final b = ByteData(8 + elstSize);
  var p = 0;
  void u32(int v) {
    b.setUint32(p, v);
    p += 4;
  }

  void tag(String t) {
    for (final c in t.codeUnits) {
      b.setUint8(p++, c);
    }
  }

  u32(8 + elstSize);
  tag('edts');
  u32(elstSize);
  tag('elst');
  u32(v1 ? 0x01000000 : 0); // version, flags
  u32(1); // entry_count
  if (v1) {
    b.setUint64(p, segmentDuration);
    p += 8;
    b.setInt64(p, mediaTime);
    p += 8;
  } else {
    u32(segmentDuration);
    b.setInt32(p, mediaTime);
    p += 4;
  }
  b.setInt16(p, 1); // media_rate_integer
  b.setInt16(p + 2, 0); // media_rate_fraction
  return b.buffer.asUint8List();
}

/// Adds [delta] to every chunk offset in every `stco`/`co64` of [moov].
/// Returns null if a 32-bit offset would overflow.
Uint8List? _shiftChunkOffsets(Uint8List moov, int delta) {
  final out = Uint8List.fromList(moov);
  final view = ByteData.sublistView(out);
  const containers = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts', 'dinf'};

  bool walk(int start, int size, int skip) {
    final kids = _children(out, start, size, skip: skip);
    if (kids == null) return false;
    for (final k in kids) {
      if (containers.contains(k.type)) {
        if (!walk(k.offset, k.size, 0)) return false;
      } else if (k.type == 'stco' || k.type == 'co64') {
        final count = view.getUint32(k.offset + 12);
        final wide = k.type == 'co64';
        for (var i = 0; i < count; i++) {
          final at = k.offset + 16 + i * (wide ? 8 : 4);
          if (wide) {
            view.setUint64(at, view.getUint64(at) + delta);
          } else {
            final v = view.getUint32(at) + delta;
            if (v > 0xFFFFFFFF) return false;
            view.setUint32(at, v);
          }
        }
      }
    }
    return true;
  }

  return walk(0, out.length, 0) ? out : null;
}

Future<void> _rewriteWithNewMoov(
  File file,
  _Box moov,
  Uint8List newMoov,
  int length,
) async {
  final tmp = File('${file.path}.elst.tmp');
  final src = await file.open();
  final dst = await tmp.open(mode: FileMode.write);
  try {
    Future<void> copy(int from, int to) async {
      const chunk = 1 << 20;
      await src.setPosition(from);
      var pos = from;
      while (pos < to) {
        final n = (to - pos) < chunk ? to - pos : chunk;
        await dst.writeFrom(await src.read(n));
        pos += n;
      }
    }

    await copy(0, moov.offset);
    await dst.writeFrom(newMoov);
    await copy(moov.offset + moov.size, length);
    await dst.flush();
  } finally {
    await src.close();
    await dst.close();
  }
  await tmp.rename(file.path);
}

/// Reads the audio track's edit list (first entry), for tests and probes.
/// Returns `(mediaTime, segmentDuration)` in the track's media and movie
/// timescales, or null when there is none.
Future<({int mediaTime, int segmentDuration})?> readAudioEditList(
  String path,
) async {
  final raf = await File(path).open();
  try {
    final length = await raf.length();
    final top = await _readTopLevelBoxes(raf, length);
    final moovBox = _find(top, 'moov');
    if (moovBox == null) return null;
    await raf.setPosition(moovBox.offset);
    final moov = Uint8List.fromList(await raf.read(moovBox.size));
    final view = ByteData.sublistView(moov);
    final kids = _children(moov, 0, moov.length) ?? const [];
    for (final trak in kids.where((b) => b.type == 'trak')) {
      final tk = _children(moov, trak.offset, trak.size) ?? const [];
      final mdia = _find(tk, 'mdia');
      final edts = _find(tk, 'edts');
      if (mdia == null || edts == null) continue;
      final md = _children(moov, mdia.offset, mdia.size) ?? const [];
      final hdlr = _find(md, 'hdlr');
      if (hdlr == null) continue;
      final handler = String.fromCharCodes(
        moov.sublist(hdlr.offset + 16, hdlr.offset + 20),
      );
      if (handler != 'soun') continue;
      final elst = _find(
        _children(moov, edts.offset, edts.size) ?? const [],
        'elst',
      );
      if (elst == null) return null;
      final v1 = moov[elst.offset + 8] == 1;
      final e = elst.offset + 16;
      return v1
          ? (
              segmentDuration: view.getUint64(e),
              mediaTime: view.getInt64(e + 8),
            )
          : (
              segmentDuration: view.getUint32(e),
              mediaTime: view.getInt32(e + 4),
            );
    }
    return null;
  } finally {
    await raf.close();
  }
}
