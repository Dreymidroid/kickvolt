import 'dart:io';
import 'dart:typed_data';

import 'wav_header.dart';

/// Streaming pure-Dart 16-bit PCM WAV writer (§4.2).
///
/// Opens a `RandomAccessFile` on `<outputPath>.part`, writes the 44-byte header
/// with the known [frameCount] up front via [buildWavHeader], streams PCM frames
/// in chunks, and verifies the total number of frames written equals
/// [frameCount] before closing and renaming `.part` → [outputPath].
///
/// Guarantees that the file handle is closed on every exit path and `.part` is
/// deleted on abort or error (critical on Windows where open handles block
/// directory deletion).
class WavWriter {
  WavWriter._({
    required this.outputPath,
    required this.partPath,
    required this.sampleRate,
    required this.channels,
    required this.frameCount,
    required this._raf,
  });

  final String outputPath;
  final String partPath;
  final int sampleRate;
  final int channels;
  final int frameCount;

  RandomAccessFile? _raf;
  int _framesWritten = 0;
  bool _closed = false;

  int get framesWritten => _framesWritten;

  static Future<WavWriter> open({
    required String outputPath,
    required int sampleRate,
    required int channels,
    required int frameCount,
  }) async {
    if (channels < 1 || channels > 2) {
      throw ArgumentError.value(channels, 'channels', 'Must be 1 or 2');
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive');
    }
    if (frameCount < 0) {
      throw ArgumentError.value(frameCount, 'frameCount', 'Must be >= 0');
    }

    final partPath = '$outputPath.part';
    final partFile = File(partPath);
    await partFile.parent.create(recursive: true);
    final raf = await partFile.open(mode: FileMode.write);
    try {
      await raf.writeFrom(
        buildWavHeader(
          sampleRate: sampleRate,
          channels: channels,
          frameCount: frameCount,
        ),
      );
      return WavWriter._(
        outputPath: outputPath,
        partPath: partPath,
        sampleRate: sampleRate,
        channels: channels,
        frameCount: frameCount,
        raf: raf,
      );
    } catch (_) {
      await raf.close();
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Writes [frames] sample frames (`frames * channels` int16 samples) from
  /// [interleavedPcm].
  Future<void> writeFrames(Int16List interleavedPcm, int frames) async {
    final raf = _raf;
    if (_closed || raf == null) {
      throw StateError('WavWriter is already closed.');
    }
    if (frames < 0 || frames * channels > interleavedPcm.length) {
      throw ArgumentError('Invalid frame count $frames for buffer length.');
    }
    if (_framesWritten + frames > frameCount) {
      await abort();
      throw StateError(
        'WavWriter overflow: attempted to write ${_framesWritten + frames} '
        'frames, declared $frameCount.',
      );
    }
    if (frames == 0) return;

    final byteView = Uint8List.view(
      interleavedPcm.buffer,
      interleavedPcm.offsetInBytes,
      frames * channels * 2,
    );
    try {
      await raf.writeFrom(byteView);
      _framesWritten += frames;
    } catch (_) {
      await abort();
      rethrow;
    }
  }

  /// Verifies that [_framesWritten] == [frameCount], flushes and closes the
  /// `.part` file, then atomically renames it to [outputPath].
  Future<void> finish() async {
    final raf = _raf;
    if (_closed || raf == null) {
      throw StateError('WavWriter is already closed.');
    }
    var ok = false;
    try {
      if (_framesWritten != frameCount) {
        throw StateError(
          'WavWriter frame count mismatch: wrote $_framesWritten, '
          'declared $frameCount.',
        );
      }
      await raf.flush();
      ok = true;
    } finally {
      _closed = true;
      _raf = null;
      await raf.close();
      if (!ok) {
        await _deletePart();
      }
    }
    await File(partPath).rename(outputPath);
  }

  /// Closes the `.part` file if still open and deletes it. Safe to call
  /// multiple times.
  Future<void> abort() async {
    final raf = _raf;
    _closed = true;
    _raf = null;
    try {
      await raf?.close();
    } catch (_) {}
    await _deletePart();
  }

  Future<void> _deletePart() async {
    try {
      final f = File(partPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
