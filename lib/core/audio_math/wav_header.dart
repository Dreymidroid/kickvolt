import 'dart:io';
import 'dart:typed_data';

/// Thrown when a file isn't a PCM WAV we can use.
class WavFormatException implements Exception {
  const WavFormatException(this.message);
  final String message;

  @override
  String toString() => 'WavFormatException: $message';
}

/// Layout of a PCM WAV file. All positions are in bytes.
class WavInfo {
  const WavInfo({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataBytes,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  /// Byte offset of the first sample in the file.
  final int dataOffset;

  /// Size of the `data` chunk payload.
  final int dataBytes;

  int get bytesPerFrame => channels * (bitsPerSample ~/ 8);

  /// Sample frames (one sample per channel). The project timebase.
  int get frameCount => dataBytes ~/ bytesPerFrame;

  @override
  String toString() =>
      'WavInfo($sampleRate Hz, $channels ch, $bitsPerSample-bit, '
      '$frameCount frames @ $dataOffset)';
}

const _formatPcm = 1;
const _formatExtensible = 0xFFFE;
const wavHeaderBytes = 44;

/// Walks the RIFF chunks of [file] and returns the PCM layout. Reads only
/// the chunk headers, never the audio.
Future<WavInfo> readWavInfo(File file) async {
  final raf = await file.open();
  try {
    final length = await raf.length();
    final riff = await raf.read(12);
    if (riff.length < 12 ||
        _ascii(riff, 0) != 'RIFF' ||
        _ascii(riff, 8) != 'WAVE') {
      throw const WavFormatException('Not a RIFF/WAVE file');
    }
    int? sampleRate, channels, bits;
    var pos = 12;
    while (pos + 8 <= length) {
      await raf.setPosition(pos);
      final head = await raf.read(8);
      if (head.length < 8) break;
      final id = _ascii(head, 0);
      final size = ByteData.sublistView(head).getUint32(4, Endian.little);
      final body = pos + 8;
      if (id == 'fmt ') {
        final fmt = ByteData.sublistView(await raf.read(16));
        final format = fmt.getUint16(0, Endian.little);
        if (format != _formatPcm && format != _formatExtensible) {
          throw WavFormatException('Unsupported WAV format tag $format');
        }
        channels = fmt.getUint16(2, Endian.little);
        sampleRate = fmt.getUint32(4, Endian.little);
        bits = fmt.getUint16(14, Endian.little);
      } else if (id == 'data') {
        if (sampleRate == null || channels == null || bits == null) {
          throw const WavFormatException('data chunk before fmt chunk');
        }
        if (channels == 0 || bits % 8 != 0) {
          throw const WavFormatException('Invalid channel count or bit depth');
        }
        // Clamp a size larger than the file (truncated or still being written).
        final dataBytes = size > length - body ? length - body : size;
        return WavInfo(
          sampleRate: sampleRate,
          channels: channels,
          bitsPerSample: bits,
          dataOffset: body,
          dataBytes: dataBytes,
        );
      }
      pos = body + size + (size.isOdd ? 1 : 0); // chunks are word-aligned
    }
    throw const WavFormatException('No data chunk');
  } finally {
    await raf.close();
  }
}

/// Canonical 44-byte PCM WAV header for [frameCount] frames.
Uint8List buildWavHeader({
  required int sampleRate,
  required int channels,
  required int frameCount,
  int bitsPerSample = 16,
}) {
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataBytes = frameCount * blockAlign;
  final b = ByteData(wavHeaderBytes);
  void ascii(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, _formatPcm, Endian.little);
  b.setUint16(22, channels, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * blockAlign, Endian.little);
  b.setUint16(32, blockAlign, Endian.little);
  b.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  return b.buffer.asUint8List();
}

String _ascii(Uint8List bytes, int at) =>
    String.fromCharCodes(bytes.sublist(at, at + 4));
