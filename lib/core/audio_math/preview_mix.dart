import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'click_synth.dart';
import 'wav_header.dart';

/// Fixed song attenuation (~-3.1 dB) in the preview mix so -3 dBFS clicks stay
/// clearly audible even on loud mastered tracks, while remaining deterministic
/// so tests can subtract `round(song * kPreviewSongGain)` to locate clicks.
const double kPreviewSongGain = 0.7;

/// Frames processed per streaming chunk (~256 KB raw read for 16-bit stereo).
const int kPreviewMixChunkFrames = 65536;

/// Thrown when a preview mix render is cancelled cooperatively.
class PreviewMixCancelledException implements Exception {
  const PreviewMixCancelledException();

  @override
  String toString() => 'PreviewMixCancelledException';
}

/// Summary statistics from [renderPreviewMix].
class PreviewMixStats {
  const PreviewMixStats({
    required this.sampleRate,
    required this.channels,
    required this.frameCount,
    required this.peakBufferBytes,
  });

  final int sampleRate;
  final int channels;
  final int frameCount;
  final int peakBufferBytes;
}

/// Renders a pre-rendered preview mix (`song * songGain + clicks`) to
/// [outputWavPath] by streaming `song.wav` in bounded chunks.
///
/// **Why pre-rendered preview mix (instead of a second click player):**
/// Clicks are baked directly into the same PCM buffer as the song at exact
/// integer sample indices. That makes them sample-accurate by construction at
/// every playback speed (0.5×, 0.75×, 1×) and regardless of device output
/// latency; a second audio player scheduling clicks cannot guarantee sample
/// sync between two streams and drifts under time-stretching.
///
/// Writes to `<outputWavPath>.part`, closes both file handles in `finally`
/// (critical on Windows so the project directory can be deleted immediately),
/// deletes `.part` on cancel/error, and atomically renames on completion.
Future<PreviewMixStats> renderPreviewMix({
  required String songWavPath,
  required String outputWavPath,
  required List<int> beatSamples,
  ClickStyle style = ClickStyle.snap,
  double songGain = kPreviewSongGain,
  bool Function()? isCancelled,
  void Function(double fraction)? onProgress,
}) async {
  if (isCancelled?.call() == true) {
    throw const PreviewMixCancelledException();
  }

  final songFile = File(songWavPath);
  final info = await readWavInfo(songFile);
  if (info.bitsPerSample != 16) {
    throw WavFormatException(
      'Expected 16-bit PCM WAV, got ${info.bitsPerSample}-bit',
    );
  }

  final frameCount = info.frameCount;
  final channels = info.channels;
  final sampleRate = info.sampleRate;
  final bytesPerFrame = info.bytesPerFrame;

  final click = renderClick(style, sampleRate);
  final chunkFrames = math.min(kPreviewMixChunkFrames, math.max(1, frameCount));
  final readBuf = Uint8List(chunkFrames * bytesPerFrame);
  final outPcm = Int16List(chunkFrames * channels);
  final outBytes = Uint8List.view(outPcm.buffer);
  final clickMono = Float64List(chunkFrames);

  final peakBufferBytes =
      readBuf.lengthInBytes +
      outPcm.lengthInBytes +
      clickMono.lengthInBytes +
      click.lengthInBytes;

  final partPath = '$outputWavPath.part';
  final partFile = File(partPath);
  await partFile.parent.create(recursive: true);

  RandomAccessFile? rafIn;
  RandomAccessFile? rafOut;
  var succeeded = false;

  try {
    rafIn = await songFile.open(mode: FileMode.read);
    await rafIn.setPosition(info.dataOffset);

    rafOut = await partFile.open(mode: FileMode.write);
    await rafOut.writeFrom(
      buildWavHeader(
        sampleRate: sampleRate,
        channels: channels,
        frameCount: frameCount,
      ),
    );

    var frameOffset = 0;
    while (frameOffset < frameCount) {
      if (isCancelled?.call() == true) {
        throw const PreviewMixCancelledException();
      }

      final count = math.min(chunkFrames, frameCount - frameOffset);
      final expectedBytes = count * bytesPerFrame;
      final readBytes = await rafIn.readInto(readBuf, 0, expectedBytes);
      if (readBytes < expectedBytes) {
        // Zero-fill any short tail so frame count matches header.
        readBuf.fillRange(readBytes, expectedBytes, 0);
      }

      // Clear and populate click buffer for this chunk.
      clickMono.fillRange(0, count, 0.0);
      addClicksToChunk(
        monoOut: clickMono,
        chunkStart: frameOffset,
        chunkLength: count,
        beatSamples: beatSamples,
        click: click,
        totalSampleCount: frameCount,
      );

      final inView = ByteData.sublistView(readBuf, 0, expectedBytes);
      var bytePos = 0;
      var outIdx = 0;
      for (var f = 0; f < count; f++) {
        final clickSample = clickMono[f] * 32767.0;
        for (var c = 0; c < channels; c++) {
          final songSample = inView.getInt16(bytePos, Endian.little);
          bytePos += 2;
          final mixed = (songSample * songGain).round() + clickSample;
          outPcm[outIdx++] = clipInt16(mixed);
        }
      }

      await rafOut.writeFrom(outBytes, 0, expectedBytes);
      frameOffset += count;
      onProgress?.call(frameCount == 0 ? 1.0 : frameOffset / frameCount);
    }

    await rafOut.flush();
    succeeded = true;
  } finally {
    // Always close both handles before deleting .part or renaming (Windows).
    await rafIn?.close();
    await rafOut?.close();
    if (!succeeded) {
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
    }
  }

  await partFile.rename(outputWavPath);
  return PreviewMixStats(
    sampleRate: sampleRate,
    channels: channels,
    frameCount: frameCount,
    peakBufferBytes: peakBufferBytes,
  );
}
