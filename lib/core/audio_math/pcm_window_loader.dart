import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'peaks.dart';
import 'wav_header.dart';

/// Loads small mono windows of `song.wav` on demand for deep zoom, where
/// the peak pyramid is too coarse. Reads are async and tiny (a few
/// thousand frames); listeners are notified when a new window lands.
class PcmWindowLoader extends ChangeNotifier {
  PcmWindowLoader._(this._file, this.info);

  /// Opens [wavPath] and reads its header.
  static Future<PcmWindowLoader> open(String wavPath) async {
    final file = File(wavPath);
    return PcmWindowLoader._(file, await readWavInfo(file));
  }

  final File _file;
  final WavInfo info;
  RandomAccessFile? _raf;

  PcmWindow? _window;
  PcmWindow? get window => _window;

  (int, int)? _wanted;
  bool _loading = false;
  bool _disposed = false;

  /// Largest window kept, in frames.
  static const maxWindowFrames = 1 << 16;

  /// Makes sure frames `[from, to)` will be available, loading a window
  /// with the same span again on each side so small scrubs don't reload.
  void ensure(int from, int to) {
    from = math.max(0, from);
    to = math.min(info.frameCount, to);
    if (to <= from || _disposed) return;
    if (_window?.covers(from, to) ?? false) return;
    _wanted = (from, to);
    if (!_loading) _pump();
  }

  Future<void> _pump() async {
    _loading = true;
    try {
      while (_wanted != null && !_disposed) {
        final (from, to) = _wanted!;
        _wanted = null;
        if (_window?.covers(from, to) ?? false) continue;
        final span = to - from;
        final start = math.max(0, from - span);
        final end = math.min(info.frameCount, math.max(to + span, start + 1));
        final clampedEnd = math.min(end, start + maxWindowFrames);
        final w = await _read(start, clampedEnd);
        if (_disposed) return;
        _window = w;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PcmWindowLoader: $e');
    } finally {
      _loading = false;
    }
  }

  Future<PcmWindow> _read(int start, int end) async {
    final raf = _raf ??= await _file.open();
    final bpf = info.bytesPerFrame;
    final bytes = Uint8List((end - start) * bpf);
    await raf.setPosition(info.dataOffset + start * bpf);
    var got = 0;
    while (got < bytes.length) {
      final n = await raf.readInto(bytes, got);
      if (n == 0) break;
      got += n;
    }
    final frames = got ~/ bpf;
    final bd = ByteData.sublistView(bytes);
    final ch = info.channels;
    final mono = Int16List(frames);
    for (var f = 0; f < frames; f++) {
      var sum = 0;
      for (var c = 0; c < ch; c++) {
        sum += bd.getInt16((f * ch + c) * 2, Endian.little);
      }
      mono[f] = ch == 1 ? sum : (sum / ch).round();
    }
    return PcmWindow(start, mono);
  }

  @override
  void dispose() {
    _disposed = true;
    _raf?.close();
    _raf = null;
    super.dispose();
  }
}
