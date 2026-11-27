import 'dart:typed_data';

/// Rewraps the AAC access units of a single-track `.m4a` (as written by the
/// app's own `encodeM4a`) as an ADTS `.aac` stream.
///
/// There is no ffmpeg on the test host, so this is how the `.aac` fixture is
/// made: same encoder, different container (and no MP4 edit list, so the
/// decoder sees the encoder priming).
Uint8List m4aToAdts(
  Uint8List mp4, {
  required int sampleRate,
  required int channels,
}) {
  final boxes = _Boxes(mp4);
  final stbl = boxes.path(['moov', 'trak', 'mdia', 'minf', 'stbl']);
  if (stbl == null) throw const FormatException('No moov/trak/.../stbl box');
  final stsz = boxes.child(stbl, 'stsz')!;
  final stsc = boxes.child(stbl, 'stsc')!;
  final stco = boxes.child(stbl, 'stco');
  final co64 = boxes.child(stbl, 'co64');

  final d = ByteData.sublistView(mp4);
  // stsz: version/flags(4) sample_size(4) count(4) [sizes]
  final fixedSize = d.getUint32(stsz.body + 4);
  final count = d.getUint32(stsz.body + 8);
  final sizes = [
    for (var i = 0; i < count; i++)
      fixedSize != 0 ? fixedSize : d.getUint32(stsz.body + 12 + 4 * i),
  ];
  // Chunk offsets.
  final offsets = <int>[];
  if (stco != null) {
    final n = d.getUint32(stco.body + 4);
    for (var i = 0; i < n; i++) {
      offsets.add(d.getUint32(stco.body + 8 + 4 * i));
    }
  } else {
    final n = d.getUint32(co64!.body + 4);
    for (var i = 0; i < n; i++) {
      offsets.add(d.getUint64(co64.body + 8 + 8 * i));
    }
  }
  // stsc: (first_chunk, samples_per_chunk, desc_index), 1-based chunks.
  final entries = d.getUint32(stsc.body + 4);
  final firstChunk = <int>[], perChunk = <int>[];
  for (var i = 0; i < entries; i++) {
    firstChunk.add(d.getUint32(stsc.body + 8 + 12 * i));
    perChunk.add(d.getUint32(stsc.body + 12 + 12 * i));
  }

  final sfIndex = const [
    96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000,
    11025, 8000, 7350, //
  ].indexOf(sampleRate);
  if (sfIndex < 0) throw FormatException('No ADTS index for $sampleRate Hz');

  final out = BytesBuilder(copy: false);
  var sample = 0;
  for (var c = 0; c < offsets.length && sample < count; c++) {
    var e = 0;
    while (e + 1 < entries && firstChunk[e + 1] <= c + 1) {
      e++;
    }
    var pos = offsets[c];
    for (var k = 0; k < perChunk[e] && sample < count; k++, sample++) {
      final size = sizes[sample];
      final frameLen = size + 7;
      out.add([
        0xFF,
        0xF1, // MPEG-4, layer 0, no CRC
        (1 << 6) | (sfIndex << 2) | (channels >> 2), // profile LC
        ((channels & 3) << 6) | (frameLen >> 11),
        (frameLen >> 3) & 0xFF,
        ((frameLen & 7) << 5) | 0x1F,
        0xFC,
      ]);
      out.add(Uint8List.sublistView(mp4, pos, pos + size));
      pos += size;
    }
  }
  return out.toBytes();
}

class _Box {
  const _Box(this.type, this.start, this.end, this.body);
  final String type;
  final int start, end, body;
}

class _Boxes {
  _Boxes(this.bytes) : _d = ByteData.sublistView(bytes);
  final Uint8List bytes;
  final ByteData _d;

  List<_Box> _list(int from, int to) {
    final out = <_Box>[];
    var pos = from;
    while (pos + 8 <= to) {
      var size = _d.getUint32(pos);
      final type = String.fromCharCodes(bytes, pos + 4, pos + 8);
      var header = 8;
      if (size == 1) {
        size = _d.getUint64(pos + 8);
        header = 16;
      } else if (size == 0) {
        size = to - pos;
      }
      if (size < header) break;
      out.add(_Box(type, pos, pos + size, pos + header));
      pos += size;
    }
    return out;
  }

  _Box? child(_Box parent, String type) {
    for (final b in _list(parent.body, parent.end)) {
      if (b.type == type) return b;
    }
    return null;
  }

  _Box? path(List<String> types) {
    _Box? cur;
    for (final t in types) {
      final list = cur == null
          ? _list(0, bytes.length)
          : _list(cur.body, cur.end);
      cur = null;
      for (final b in list) {
        if (b.type == t) {
          cur = b;
          break;
        }
      }
      if (cur == null) return null;
    }
    return cur;
  }
}
