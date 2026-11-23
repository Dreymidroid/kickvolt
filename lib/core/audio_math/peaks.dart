import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'wav_header.dart';

/// Frames per bucket at each pyramid level, finest first. Each level merges
/// four buckets of the one below it.
const peakLevelFrames = [64, 256, 1024, 4096, 16384];
const peaksFormatVersion = 1;

/// Min/max of the mono mixdown, one pair per bucket.
class PeakLevel {
  PeakLevel(this.framesPerBucket, this.data)
    : assert(data.length.isEven, 'data holds min/max pairs');

  final int framesPerBucket;

  /// `[min0, max0, min1, max1, ...]` as signed 16-bit samples.
  final Int16List data;

  int get bucketCount => data.length >> 1;
}

/// Mono samples for a range of frames, read straight from `song.wav`. Used
/// when zoomed in past the finest pyramid level.
class PcmWindow {
  const PcmWindow(this.startFrame, this.mono);

  final int startFrame;
  final Int16List mono;

  int get endFrame => startFrame + mono.length;

  bool covers(int from, int to) => from >= startFrame && to <= endFrame;
}

/// Multi-resolution min/max peaks of a song (`peaks.bin`).
class PeakPyramid {
  PeakPyramid({required this.frameCount, required this.levels});

  static final empty = PeakPyramid(frameCount: 0, levels: const []);

  /// Builds every level from the finest one (`peakLevelFrames.first` frames
  /// per bucket, min/max pairs) by merging buckets.
  factory PeakPyramid.fromFinest({
    required int frameCount,
    required Int16List finest,
  }) {
    final levels = <PeakLevel>[PeakLevel(peakLevelFrames.first, finest)];
    for (var i = 1; i < peakLevelFrames.length; i++) {
      final prev = levels.last;
      final ratio = peakLevelFrames[i] ~/ prev.framesPerBucket;
      final count = (prev.bucketCount + ratio - 1) ~/ ratio;
      final data = Int16List(2 * count);
      for (var j = 0; j < count; j++) {
        var lo = 32767;
        var hi = -32768;
        final end = math.min(prev.bucketCount, (j + 1) * ratio);
        for (var k = j * ratio; k < end; k++) {
          lo = math.min(lo, prev.data[2 * k]);
          hi = math.max(hi, prev.data[2 * k + 1]);
        }
        data[2 * j] = lo;
        data[2 * j + 1] = hi;
      }
      levels.add(PeakLevel(peakLevelFrames[i], data));
    }
    return PeakPyramid(frameCount: frameCount, levels: levels);
  }

  final int frameCount;

  /// Finest first.
  final List<PeakLevel> levels;

  bool get isEmpty => frameCount == 0 || levels.isEmpty;

  /// The coarsest level whose buckets are no wider than [framesPerColumn],
  /// or null when even the finest level is too coarse (use raw PCM).
  PeakLevel? levelFor(double framesPerColumn) {
    PeakLevel? best;
    for (final l in levels) {
      if (l.framesPerBucket <= framesPerColumn) best = l;
    }
    return best;
  }

  /// Fills [outMin]/[outMax] (each at least [columns] long) with the
  /// normalised (-1..1) range of each column. Column `k` covers frames
  /// `[fromFrame + k*framesPerColumn, fromFrame + (k+1)*framesPerColumn)`.
  /// Columns outside the song get NaN. When [raw] covers a column and the
  /// column is finer than the finest level, exact samples are used.
  ///
  /// Allocation-free so it can run every frame.
  void fillColumns({
    required double fromFrame,
    required double framesPerColumn,
    required int columns,
    required Float32List outMin,
    required Float32List outMax,
    PcmWindow? raw,
  }) {
    final fine = levels.isEmpty ? null : levels.first;
    final level = levelFor(framesPerColumn) ?? fine;
    final useRaw =
        raw != null && (fine == null || framesPerColumn < fine.framesPerBucket);
    for (var k = 0; k < columns; k++) {
      final a = fromFrame + k * framesPerColumn;
      final b = a + framesPerColumn;
      final from = math.max(0, a.floor());
      final to = math.min(frameCount, math.max(from + 1, b.ceil()));
      if (from >= frameCount || to <= 0 || b <= 0) {
        outMin[k] = double.nan;
        outMax[k] = double.nan;
        continue;
      }
      var lo = 32767;
      var hi = -32768;
      if (useRaw && raw.covers(from, to)) {
        final mono = raw.mono;
        for (var f = from - raw.startFrame; f < to - raw.startFrame; f++) {
          final v = mono[f];
          if (v < lo) lo = v;
          if (v > hi) hi = v;
        }
      } else if (level != null) {
        final fpb = level.framesPerBucket;
        final data = level.data;
        final b0 = from ~/ fpb;
        final b1 = math.min(level.bucketCount, (to + fpb - 1) ~/ fpb);
        for (var i = b0; i < b1; i++) {
          final mn = data[2 * i];
          final mx = data[2 * i + 1];
          if (mn < lo) lo = mn;
          if (mx > hi) hi = mx;
        }
      }
      if (hi < lo) {
        outMin[k] = 0;
        outMax[k] = 0;
      } else {
        outMin[k] = lo / 32768.0;
        outMax[k] = hi / 32768.0;
      }
    }
  }
}

/// Builds the pyramid from interleaved 16-bit PCM already in memory (tests,
/// and the isolate below via [PeakPyramidBuilder]).
PeakPyramid peaksFromPcm(Int16List interleaved, int channels) {
  final b = PeakPyramidBuilder(channels: channels);
  b.add(interleaved);
  return b.finish();
}

/// Streams PCM into the finest level, then derives the coarser ones.
class PeakPyramidBuilder {
  PeakPyramidBuilder({required this.channels, int expectedFrames = 0})
    : _level0 = Int16List(
        2 *
            ((expectedFrames + peakLevelFrames.first - 1) ~/
                peakLevelFrames.first),
      );

  final int channels;
  Int16List _level0;
  int _buckets = 0;
  int _frames = 0;
  int _inBucket = 0;
  int _lo = 32767;
  int _hi = -32768;

  /// [interleaved] must hold whole frames.
  void add(Int16List interleaved) {
    final fpb = peakLevelFrames.first;
    final n = interleaved.length ~/ channels;
    var o = 0;
    for (var f = 0; f < n; f++) {
      var sum = 0;
      for (var c = 0; c < channels; c++) {
        sum += interleaved[o++];
      }
      final v = channels == 1 ? sum : (sum / channels).round();
      if (v < _lo) _lo = v;
      if (v > _hi) _hi = v;
      if (++_inBucket == fpb) _closeBucket();
    }
    _frames += n;
  }

  void _closeBucket() {
    if (2 * _buckets + 1 >= _level0.length) {
      final grown = Int16List(math.max(64, _level0.length * 2));
      grown.setRange(0, 2 * _buckets, _level0);
      _level0 = grown;
    }
    _level0[2 * _buckets] = _lo;
    _level0[2 * _buckets + 1] = _hi;
    _buckets++;
    _inBucket = 0;
    _lo = 32767;
    _hi = -32768;
  }

  PeakPyramid finish() {
    if (_inBucket > 0) _closeBucket();
    return PeakPyramid.fromFinest(
      frameCount: _frames,
      finest: Int16List.fromList(
        Int16List.sublistView(_level0, 0, 2 * _buckets),
      ),
    );
  }
}

/// Computes the pyramid for a 16-bit WAV in a background isolate, reading
/// at most [chunkBytes] at a time.
Future<PeakPyramid> computePeaks(
  String wavPath, {
  int chunkBytes = 256 * 1024,
}) => Isolate.run(() => _computePeaks(wavPath, chunkBytes));

Future<PeakPyramid> _computePeaks(String wavPath, int chunkBytes) async {
  final file = File(wavPath);
  final info = await readWavInfo(file);
  if (info.bitsPerSample != 16) {
    throw WavFormatException(
      'Expected 16-bit PCM, got ${info.bitsPerSample}-bit',
    );
  }
  final builder = PeakPyramidBuilder(
    channels: info.channels,
    expectedFrames: info.frameCount,
  );
  final bpf = info.bytesPerFrame;
  final buf = Uint8List(math.max(1, chunkBytes ~/ bpf) * bpf);
  final raf = await file.open();
  try {
    await raf.setPosition(info.dataOffset);
    var remaining = info.frameCount * bpf;
    while (remaining > 0) {
      final want = math.min(remaining, buf.length);
      var got = 0;
      while (got < want) {
        final n = await raf.readInto(buf, got, want);
        if (n == 0) break;
        got += n;
      }
      final whole = got - got % bpf;
      if (whole == 0) break;
      builder.add(_le16(buf, whole));
      remaining -= whole;
      if (got < want) break;
    }
  } finally {
    await raf.close();
  }
  return builder.finish();
}

/// Little-endian bytes → host-order Int16 view (copies only on big-endian
/// hosts, which Flutter doesn't ship on).
Int16List _le16(Uint8List bytes, int length) {
  if (Endian.host == Endian.little) {
    return Int16List.sublistView(bytes, 0, length);
  }
  final bd = ByteData.sublistView(bytes, 0, length);
  return Int16List.fromList([
    for (var i = 0; i < length; i += 2) bd.getInt16(i, Endian.little),
  ]);
}

/// `peaks.bin`: ASCII `KVPK`, u16 version, u16 levelCount, u32 frameCount,
/// then per level u32 framesPerBucket + u32 bucketCount, then each level's
/// int16 min/max pairs, all little-endian.
Uint8List encodePeaks(PeakPyramid p) {
  final header = 12 + 8 * p.levels.length;
  final dataBytes = p.levels.fold<int>(0, (s, l) => s + l.data.lengthInBytes);
  final out = Uint8List(header + dataBytes);
  final bd = ByteData.sublistView(out);
  out.setRange(0, 4, 'KVPK'.codeUnits);
  bd.setUint16(4, peaksFormatVersion, Endian.little);
  bd.setUint16(6, p.levels.length, Endian.little);
  bd.setUint32(8, p.frameCount, Endian.little);
  var o = 12;
  for (final l in p.levels) {
    bd.setUint32(o, l.framesPerBucket, Endian.little);
    bd.setUint32(o + 4, l.bucketCount, Endian.little);
    o += 8;
  }
  for (final l in p.levels) {
    for (final v in l.data) {
      bd.setInt16(o, v, Endian.little);
      o += 2;
    }
  }
  return out;
}

PeakPyramid decodePeaks(Uint8List bytes) {
  if (bytes.length < 12 || String.fromCharCodes(bytes, 0, 4) != 'KVPK') {
    throw const FormatException('Not a peaks.bin file');
  }
  final bd = ByteData.sublistView(bytes);
  final version = bd.getUint16(4, Endian.little);
  if (version != peaksFormatVersion) {
    throw FormatException('Unsupported peaks.bin version $version');
  }
  final levelCount = bd.getUint16(6, Endian.little);
  final frameCount = bd.getUint32(8, Endian.little);
  var o = 12;
  final shapes = <(int, int)>[];
  for (var i = 0; i < levelCount; i++) {
    if (o + 8 > bytes.length) {
      throw const FormatException('Truncated peaks.bin');
    }
    shapes.add((
      bd.getUint32(o, Endian.little),
      bd.getUint32(o + 4, Endian.little),
    ));
    o += 8;
  }
  final levels = <PeakLevel>[];
  for (final (fpb, count) in shapes) {
    if (fpb == 0 || o + 4 * count > bytes.length) {
      throw const FormatException('Truncated or invalid peaks.bin');
    }
    final data = Int16List(2 * count);
    for (var i = 0; i < data.length; i++) {
      data[i] = bd.getInt16(o, Endian.little);
      o += 2;
    }
    levels.add(PeakLevel(fpb, data));
  }
  if (o != bytes.length) {
    throw const FormatException('Trailing bytes in peaks.bin');
  }
  return PeakPyramid(frameCount: frameCount, levels: levels);
}
