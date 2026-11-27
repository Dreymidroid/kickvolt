import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'click_synth.dart';
import 'wav_header.dart';
import 'wav_writer.dart';

/// Frames processed per streaming chunk in [renderGuideTrack] (~256 KB output
/// buffer for 16-bit stereo).
const int kGuideTrackChunkFrames = 65536;

/// Thrown when a guide track render is cancelled cooperatively.
class GuideTrackCancelledException implements Exception {
  const GuideTrackCancelledException();

  @override
  String toString() => 'GuideTrackCancelledException';
}

/// Summary statistics from [renderGuideTrack].
class GuideTrackStats {
  const GuideTrackStats({
    required this.sampleRate,
    required this.channels,
    required this.frameCount,
    required this.clickCount,
    required this.peakBufferBytes,
  });

  final int sampleRate;
  final int channels;
  final int frameCount;
  final int clickCount;
  final int peakBufferBytes;
}

/// Computes the exact peak buffer bytes allocated by [renderGuideTrack] for a
/// song with [sampleRate], [channels], and [frameCount].
int estimateGuideTrackPeakBufferBytes({
  required int sampleRate,
  required int channels,
  required int frameCount,
  ClickStyle style = ClickStyle.snap,
}) {
  final click = renderClick(style, sampleRate);
  final chunkFrames = math.min(kGuideTrackChunkFrames, math.max(1, frameCount));
  final clickMonoBytes = chunkFrames * Float64List.bytesPerElement;
  final outPcmBytes = chunkFrames * channels * Int16List.bytesPerElement;
  return clickMonoBytes + outPcmBytes + click.lengthInBytes;
}

/// Normalises a list of beat sample indices against [frameCount]:
/// clamps every beat to `[0, frameCount - 1]`, sorts ascending, and removes
/// duplicates. Returns an empty list if [frameCount] <= 0.
List<int> clampAndDeduplicateBeats(List<int> beatSamples, int frameCount) {
  if (frameCount <= 0 || beatSamples.isEmpty) return const <int>[];
  final maxFrame = frameCount - 1;
  final clamped = <int>[for (final s in beatSamples) s.clamp(0, maxFrame)]
    ..sort();
  final unique = <int>[clamped.first];
  for (var i = 1; i < clamped.length; i++) {
    if (clamped[i] != unique.last) {
      unique.add(clamped[i]);
    }
  }
  return unique;
}

/// Renders a 16-bit PCM WAV guide track to [outputWavPath] (§4.3):
/// - Reads ONLY the header of [songWavPath] (`readWavInfo`) for `sampleRate`
///   and `frameCount`; never reads the song's audio samples.
/// - Same `sampleRate` and `frameCount` as `song.wav`.
/// - `channels` = 2 (default) or 1 when "Mono guide track" is enabled; same
///   click on every channel.
/// - Silence everywhere except clicks (`renderClick` + `addClicksToChunk`,
///   then `clipInt16`).
/// - Beats are sorted, de-duplicated, and clamped to `[0, frameCount - 1]`.
/// - Streams through [WavWriter] (`<outputWavPath>.part` then rename) with
///   bounded memory (≤ 4 MB peak buffers for any song length).
Future<GuideTrackStats> renderGuideTrack({
  required String songWavPath,
  required String outputWavPath,
  required List<int> beatSamples,
  ClickStyle style = ClickStyle.snap,
  int channels = 2,
  int? expectedProjectSampleCount,
  bool Function()? isCancelled,
  void Function(double fraction)? onProgress,
}) async {
  if (channels != 1 && channels != 2) {
    throw ArgumentError.value(channels, 'channels', 'Must be 1 or 2');
  }
  if (isCancelled?.call() == true) {
    throw const GuideTrackCancelledException();
  }

  final songFile = File(songWavPath);
  final info = await readWavInfo(songFile);
  final sampleRate = info.sampleRate;
  final frameCount = info.frameCount;

  if (expectedProjectSampleCount != null &&
      expectedProjectSampleCount != frameCount) {
    developer.log(
      'Project sampleCount ($expectedProjectSampleCount) disagrees with '
      'song.wav frameCount ($frameCount); song.wav wins.',
      name: 'renderGuideTrack',
    );
  }

  final normalizedBeats = clampAndDeduplicateBeats(beatSamples, frameCount);
  final click = renderClick(style, sampleRate);
  final chunkFrames = math.min(kGuideTrackChunkFrames, math.max(1, frameCount));
  final clickMono = Float64List(chunkFrames);
  final outPcm = Int16List(chunkFrames * channels);

  final peakBufferBytes =
      clickMono.lengthInBytes + outPcm.lengthInBytes + click.lengthInBytes;

  final writer = await WavWriter.open(
    outputPath: outputWavPath,
    sampleRate: sampleRate,
    channels: channels,
    frameCount: frameCount,
  );

  var succeeded = false;
  try {
    var frameOffset = 0;
    while (frameOffset < frameCount) {
      if (isCancelled?.call() == true) {
        throw const GuideTrackCancelledException();
      }

      final count = math.min(chunkFrames, frameCount - frameOffset);
      clickMono.fillRange(0, count, 0.0);
      addClicksToChunk(
        monoOut: clickMono,
        chunkStart: frameOffset,
        chunkLength: count,
        beatSamples: normalizedBeats,
        click: click,
        totalSampleCount: frameCount,
      );

      if (channels == 1) {
        for (var f = 0; f < count; f++) {
          final v = clickMono[f];
          outPcm[f] = v == 0.0 ? 0 : clipInt16(v * 32767.0);
        }
      } else {
        var outIdx = 0;
        for (var f = 0; f < count; f++) {
          final v = clickMono[f];
          final sample = v == 0.0 ? 0 : clipInt16(v * 32767.0);
          outPcm[outIdx++] = sample;
          outPcm[outIdx++] = sample;
        }
      }

      await writer.writeFrames(outPcm, count);
      frameOffset += count;
      onProgress?.call(frameCount == 0 ? 1.0 : frameOffset / frameCount);
    }

    if (frameCount == 0) {
      onProgress?.call(1.0);
    }

    await writer.finish();
    succeeded = true;
  } finally {
    if (!succeeded) {
      await writer.abort();
    }
  }

  return GuideTrackStats(
    sampleRate: sampleRate,
    channels: channels,
    frameCount: frameCount,
    clickCount: normalizedBeats.length,
    peakBufferBytes: peakBufferBytes,
  );
}

/// Streams a byte-exact copy of `song.wav` into `<outputWavPath>.part` in
/// chunks, closes handles in `finally`, renames to [outputWavPath], and
/// verifies with [readWavInfo] that sample rate, channels, and frame count
/// match the source (§4.4).
Future<WavInfo> copySongWavStreaming({
  required String songWavPath,
  required String outputWavPath,
  bool Function()? isCancelled,
  void Function(double fraction)? onProgress,
}) async {
  if (isCancelled?.call() == true) {
    throw const GuideTrackCancelledException();
  }

  final srcFile = File(songWavPath);
  final srcInfo = await readWavInfo(srcFile);
  final totalBytes = await srcFile.length();

  final partPath = '$outputWavPath.part';
  final partFile = File(partPath);
  await partFile.parent.create(recursive: true);

  RandomAccessFile? rafIn;
  RandomAccessFile? rafOut;
  var succeeded = false;

  try {
    rafIn = await srcFile.open(mode: FileMode.read);
    rafOut = await partFile.open(mode: FileMode.write);

    const chunkBytes = 256 * 1024;
    final buf = Uint8List(chunkBytes);
    var copied = 0;

    while (copied < totalBytes) {
      if (isCancelled?.call() == true) {
        throw const GuideTrackCancelledException();
      }
      final toRead = math.min(chunkBytes, totalBytes - copied);
      final n = await rafIn.readInto(buf, 0, toRead);
      if (n <= 0) break;
      await rafOut.writeFrom(buf, 0, n);
      copied += n;
      onProgress?.call(totalBytes == 0 ? 1.0 : copied / totalBytes);
    }

    await rafOut.flush();
    succeeded = true;
  } finally {
    await rafIn?.close();
    await rafOut?.close();
    if (!succeeded) {
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
    }
  }

  await partFile.rename(outputWavPath);
  final destInfo = await readWavInfo(File(outputWavPath));
  if (destInfo.sampleRate != srcInfo.sampleRate ||
      destInfo.channels != srcInfo.channels ||
      destInfo.frameCount != srcInfo.frameCount) {
    try {
      await File(outputWavPath).delete();
    } catch (_) {}
    throw StateError(
      'Copied song.wav header mismatch: expected $srcInfo, got $destInfo',
    );
  }
  return destInfo;
}
