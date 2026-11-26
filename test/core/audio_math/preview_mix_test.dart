import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/core/audio_math/preview_mix.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/click_preview/click_preview.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../fixtures/demo_project.dart';

/// Writes a synthetic song with smoothly faded notes (no hard cuts).
Future<void> _writeFadedSongWav({
  required String path,
  required int sampleRate,
  required int channels,
  required int frameCount,
}) async {
  final header = buildWavHeader(
    sampleRate: sampleRate,
    channels: channels,
    frameCount: frameCount,
  );
  final raf = await File(path).open(mode: FileMode.write);
  try {
    await raf.writeFrom(header);
    const chunkFrames = 16384;
    final pcm = Int16List(chunkFrames * channels);
    final bytes = Uint8List.view(pcm.buffer);
    final noteFrames = sampleRate ~/ 2; // 0.5 s notes with fade in/out
    final fadeFrames = sampleRate ~/ 20; // 50 ms fade
    var offset = 0;
    while (offset < frameCount) {
      final count = math.min(chunkFrames, frameCount - offset);
      for (var i = 0; i < count; i++) {
        final frame = offset + i;
        final posInNote = frame % noteFrames;
        var env = 1.0;
        if (posInNote < fadeFrames) {
          env = posInNote / fadeFrames;
        } else if (posInNote > noteFrames - fadeFrames) {
          env = (noteFrames - posInNote) / fadeFrames;
        }
        final v =
            (0.35 *
                    env *
                    math.sin(2 * math.pi * 220.0 * frame / sampleRate) *
                    32767.0)
                .round()
                .clamp(-32768, 32767);
        for (var c = 0; c < channels; c++) {
          pcm[i * channels + c] = v;
        }
      }
      await raf.writeFrom(bytes, 0, count * channels * 2);
      offset += count;
    }
  } finally {
    await raf.close();
  }
}

Future<Int16List> _readAllPcm(String path) async {
  final file = File(path);
  final info = await readWavInfo(file);
  final bytes = await file.readAsBytes();
  final data = bytes.sublist(info.dataOffset, info.dataOffset + info.dataBytes);
  return data.buffer.asInt16List(data.offsetInBytes, info.dataBytes ~/ 2);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kickvolt_preview_mix_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  for (final spec in const [
    (name: '44.1 kHz stereo', rate: 44100, channels: 2),
    (name: '48 kHz mono', rate: 48000, channels: 1),
  ]) {
    test('exact click placement and filter respect at ${spec.name}', () async {
      final frameCount = spec.rate * 4; // 4 s
      final songPath = '${tempDir.path}${Platform.pathSeparator}song.wav';
      final previewPath = '${tempDir.path}${Platform.pathSeparator}preview.wav';
      await _writeFadedSongWav(
        path: songPath,
        sampleRate: spec.rate,
        channels: spec.channels,
        frameCount: frameCount,
      );

      // Visible vs hidden beats via filter (BeatFilter.strong hides BeatType.beat).
      final beats = [
        Beat(sample: (spec.rate * 0.5).round(), type: BeatType.strong),
        Beat(sample: (spec.rate * 1.0).round(), type: BeatType.beat), // hidden
        Beat(sample: (spec.rate * 1.5).round(), type: BeatType.drop),
        Beat(sample: (spec.rate * 2.0).round(), type: BeatType.beat), // hidden
        Beat(sample: (spec.rate * 2.5).round(), type: BeatType.downbeat),
      ];
      final project =
          createDemoProject(
            sampleRate: spec.rate,
            includeBeats: false,
          ).copyWith(
            channels: spec.channels,
            sampleCount: frameCount,
            beats: beats,
            detection: const DetectionSettings(filter: BeatFilter.strong),
          );
      final visibleSamples = [
        for (final idx in visibleBeatIndices(project))
          project.beats[idx].sample,
      ];
      expect(visibleSamples.length, 3);

      final stats = await renderPreviewMix(
        songWavPath: songPath,
        outputWavPath: previewPath,
        beatSamples: visibleSamples,
        style: ClickStyle.snap,
      );

      // Bounded memory (peak buffer <= 4 MB).
      expect(stats.peakBufferBytes, lessThanOrEqualTo(4 * 1024 * 1024));

      // Header matches song.wav exactly.
      final songInfo = await readWavInfo(File(songPath));
      final previewInfo = await readWavInfo(File(previewPath));
      expect(previewInfo.sampleRate, songInfo.sampleRate);
      expect(previewInfo.channels, songInfo.channels);
      expect(previewInfo.frameCount, songInfo.frameCount);

      final songPcm = await _readAllPcm(songPath);
      final prevPcm = await _readAllPcm(previewPath);
      final ch = spec.channels;

      // For every visible beat, first sample in a window around it where
      // preview - round(song * songGain) != 0 is EXACTLY the beat sample.
      for (final beatSample in visibleSamples) {
        final searchStart = math.max(0, beatSample - 500);
        final searchEnd = math.min(frameCount, beatSample + 500);
        int? firstDiff;
        for (var f = searchStart; f < searchEnd; f++) {
          final expectedSong = (songPcm[f * ch] * kPreviewSongGain).round();
          if (prevPcm[f * ch] != expectedSong) {
            firstDiff = f;
            break;
          }
        }
        expect(firstDiff, beatSample, reason: 'click onset at $beatSample');
        // Verify all channels received the same click at the onset.
        for (var c = 1; c < ch; c++) {
          final expectedSong = (songPcm[beatSample * ch + c] * kPreviewSongGain)
              .round();
          expect(prevPcm[beatSample * ch + c], isNot(expectedSong));
        }
      }

      // Hidden beats produce NO click.
      for (final hidden in [beats[1].sample, beats[3].sample]) {
        for (var f = hidden - 100; f < hidden + 500; f++) {
          final expectedSong = (songPcm[f * ch] * kPreviewSongGain).round();
          expect(
            prevPcm[f * ch],
            expectedSong,
            reason: 'hidden beat at $hidden',
          );
        }
      }
    });
  }

  test('cancel mid-render leaves no .part file and project folder deletes immediately', () async {
    final projDir = Directory('${tempDir.path}${Platform.pathSeparator}proj');
    await projDir.create(recursive: true);
    final songPath = '${projDir.path}${Platform.pathSeparator}song.wav';
    final previewPath = '${projDir.path}${Platform.pathSeparator}preview-1.wav';

    // 10 s stereo so isolate runs across multiple chunks.
    await _writeFadedSongWav(
      path: songPath,
      sampleRate: 44100,
      channels: 2,
      frameCount: 44100 * 10,
    );

    final token = ClickPreviewCancelToken();
    var cancelled = false;
    final future = runPreviewMixInIsolate(
      songWavPath: songPath,
      outputWavPath: previewPath,
      beatSamples: [for (var i = 0; i < 20; i++) i * 22050],
      style: ClickStyle.snap,
      cancelToken: token,
      onProgress: (_) {
        if (!cancelled) {
          cancelled = true;
          token.cancel();
        }
      },
    );

    await expectLater(future, throwsA(isA<ClickPreviewCancelledException>()));

    // No .part file left.
    expect(await File('$previewPath.part').exists(), isFalse);
    // Project folder can be deleted immediately on Windows (no leaked handles).
    await projDir.delete(recursive: true);
    expect(await projDir.exists(), isFalse);
  });

  test('cancel while the isolate is still spawning stops the worker and frees '
      'the folder', () async {
    final projDir = Directory('${tempDir.path}${Platform.pathSeparator}early');
    await projDir.create(recursive: true);
    final songPath = '${projDir.path}${Platform.pathSeparator}song.wav';
    await _writeFadedSongWav(
      path: songPath,
      sampleRate: 44100,
      channels: 2,
      frameCount: 44100 * 20,
    );

    // Cancel at different moments: synchronously (during spawn), after a
    // microtask, and after the event queue has turned.
    for (var i = 0; i < 9; i++) {
      final token = ClickPreviewCancelToken();
      final out = '${projDir.path}${Platform.pathSeparator}preview-$i.wav';
      final future = runPreviewMixInIsolate(
        songWavPath: songPath,
        outputWavPath: out,
        beatSamples: [for (var b = 0; b < 40; b++) b * 22050],
        cancelToken: token,
      );
      if (i % 3 == 1) await Future<void>.value();
      if (i % 3 == 2) await pumpEventQueue();
      await token.cancel();
      await expectLater(future, throwsA(isA<ClickPreviewCancelledException>()));
      expect(await File(out).exists(), isFalse, reason: 'case $i');
      expect(await File('$out.part').exists(), isFalse, reason: 'case $i');
    }

    await projDir.delete(recursive: true);
    expect(await projDir.exists(), isFalse);
  });
}
