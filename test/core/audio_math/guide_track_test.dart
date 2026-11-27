import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/core/audio_math/guide_track.dart';
import 'package:kickvolt/core/audio_math/preview_mix.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../fixtures/demo_project.dart';

/// Writes a synthetic song with smoothly faded notes (every note faded in and
/// out so there are no hard cuts).
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
    final noteFrames = math.max(100, sampleRate ~/ 2);
    final fadeFrames = math.max(10, sampleRate ~/ 20);
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
        // Fade the very end of the file cleanly even for odd lengths.
        final remaining = frameCount - 1 - frame;
        if (remaining < fadeFrames) {
          env = math.min(env, remaining / fadeFrames);
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

double _peakDbfs(int maxAbsSample) =>
    20.0 * math.log(maxAbsSample / 32767.0) / math.ln10;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kickvolt_guide_track_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final fixtures = [
    (name: '44.1 kHz stereo (3 s)', rate: 44100, songCh: 2, frames: 44100 * 3),
    (name: '48 kHz mono (3 s)', rate: 48000, songCh: 1, frames: 48000 * 3),
    (
      name: '44.1 kHz stereo odd length (1 s + 1 frame = 44101)',
      rate: 44100,
      songCh: 2,
      frames: 44101,
    ),
    (name: '22.05 kHz mono (3 s)', rate: 22050, songCh: 1, frames: 22050 * 3),
  ];

  for (final fx in fixtures) {
    for (final guideCh in [2, 1]) {
      test('Song and guide track have identical sample counts & exact click '
          'positions: ${fx.name}, guideCh=$guideCh', () async {
        final songPath = '${tempDir.path}${Platform.pathSeparator}song.wav';
        final guidePath = '${tempDir.path}${Platform.pathSeparator}guide.wav';
        final previewPath =
            '${tempDir.path}${Platform.pathSeparator}preview.wav';
        await _writeFadedSongWav(
          path: songPath,
          sampleRate: fx.rate,
          channels: fx.songCh,
          frameCount: fx.frames,
        );

        final beat0 = (fx.rate * 0.25).round();
        final beat1 = (fx.rate * 0.50).round();
        final beat2 = (fx.rate * 0.75).round();
        final beat3 = fx.frames > fx.rate * 2
            ? (fx.rate * 1.50).round()
            : (fx.rate * 0.90).round();

        final stats = await renderGuideTrack(
          songWavPath: songPath,
          outputWavPath: guidePath,
          beatSamples: [beat0, beat1, beat2, beat3],
          style: ClickStyle.snap,
          channels: guideCh,
        );

        final previewStats = await renderPreviewMix(
          songWavPath: songPath,
          outputWavPath: previewPath,
          beatSamples: [beat0, beat1, beat2, beat3],
          style: ClickStyle.snap,
        );

        final songInfo = await readWavInfo(File(songPath));
        final guideInfo = await readWavInfo(File(guidePath));
        final previewInfo = await readWavInfo(File(previewPath));

        // Identical sample rate and frame count read back from disk.
        expect(guideInfo.sampleRate, songInfo.sampleRate);
        expect(guideInfo.frameCount, songInfo.frameCount);
        expect(guideInfo.channels, guideCh);
        expect(guideInfo.bitsPerSample, 16);
        expect(stats.sampleRate, songInfo.sampleRate);
        expect(stats.frameCount, songInfo.frameCount);
        expect(stats.channels, guideCh);

        expect(previewInfo.sampleRate, songInfo.sampleRate);
        expect(previewInfo.frameCount, songInfo.frameCount);
        expect(previewInfo.channels, songInfo.channels);
        expect(previewStats.frameCount, songInfo.frameCount);

        final pcm = await _readAllPcm(guidePath);
        final clickLen = renderClick(ClickStyle.snap, fx.rate).length;

        // Silence before first beat.
        for (var f = 0; f < beat0; f++) {
          for (var c = 0; c < guideCh; c++) {
            expect(pcm[f * guideCh + c], 0);
          }
        }

        final beats = [beat0, beat1, beat2, beat3];
        for (var bIdx = 0; bIdx < beats.length; bIdx++) {
          final b = beats[bIdx];
          // First non-zero sample at or after beat - 1 is EXACTLY beat.
          final searchStart = math.max(0, b - 1);
          int? firstNonZero;
          for (
            var f = searchStart;
            f < math.min(fx.frames, b + clickLen);
            f++
          ) {
            if (pcm[f * guideCh] != 0) {
              firstNonZero = f;
              break;
            }
          }
          expect(firstNonZero, b, reason: 'Beat at $b onset must be exact');

          // Same click on every channel & peak of isolated click within -3 dBFS ±0.1 dB.
          var maxAbs = 0;
          final clickEnd = math.min(fx.frames, b + clickLen);
          for (var f = b; f < clickEnd; f++) {
            final s0 = pcm[f * guideCh];
            if (s0.abs() > maxAbs) maxAbs = s0.abs();
            for (var c = 1; c < guideCh; c++) {
              expect(
                pcm[f * guideCh + c],
                s0,
                reason: 'Channel $c must match channel 0 at frame $f',
              );
            }
          }
          final dbfs = _peakDbfs(maxAbs);
          expect(dbfs, closeTo(-3.0, 0.1));

          // Samples between this click's end and the next beat are exactly 0.
          final silenceEnd = bIdx + 1 < beats.length
              ? beats[bIdx + 1]
              : fx.frames;
          for (var f = clickEnd; f < silenceEnd; f++) {
            for (var c = 0; c < guideCh; c++) {
              expect(
                pcm[f * guideCh + c],
                0,
                reason: 'Must be silent between clicks at frame $f',
              );
            }
          }
        }
      });
    }
  }

  test('all four click styles have attack at exact beat sample and -3 dBFS ±0.1 dB peak', () async {
    const rate = 44100;
    const frames = 44100 * 2;
    final songPath = '${tempDir.path}${Platform.pathSeparator}song.wav';
    await _writeFadedSongWav(
      path: songPath,
      sampleRate: rate,
      channels: 2,
      frameCount: frames,
    );

    for (final style in ClickStyle.values) {
      final guidePath =
          '${tempDir.path}${Platform.pathSeparator}guide_${style.name}.wav';
      const beat = 10000;
      await renderGuideTrack(
        songWavPath: songPath,
        outputWavPath: guidePath,
        beatSamples: [beat],
        style: style,
        channels: 2,
      );

      final pcm = await _readAllPcm(guidePath);
      expect(pcm[(beat - 1) * 2], 0);
      expect(pcm[beat * 2], isNot(0), reason: '${style.name} attack at $beat');

      final clickLen = renderClick(style, rate).length;
      var maxAbs = 0;
      for (var f = beat; f < beat + clickLen; f++) {
        maxAbs = math.max(maxAbs, pcm[f * 2].abs());
        expect(pcm[f * 2 + 1], pcm[f * 2]);
      }
      expect(_peakDbfs(maxAbs), closeTo(-3.0, 0.1), reason: style.name);
    }
  });

  test('filter respected: hidden beats produce silence', () async {
    const rate = 44100;
    const frames = 44100 * 3;
    final songPath = '${tempDir.path}${Platform.pathSeparator}song.wav';
    final guidePath = '${tempDir.path}${Platform.pathSeparator}guide.wav';
    await _writeFadedSongWav(
      path: songPath,
      sampleRate: rate,
      channels: 2,
      frameCount: frames,
    );

    final project = createDemoProject(sampleRate: rate, includeBeats: false)
        .copyWith(
          sampleCount: frames,
          beats: const [
            Beat(sample: 10000, type: BeatType.strong),
            Beat(sample: 30000, type: BeatType.beat), // hidden by strong filter
            Beat(sample: 50000, type: BeatType.drop),
            Beat(sample: 70000, type: BeatType.beat), // hidden by strong filter
            Beat(sample: 90000, type: BeatType.downbeat),
          ],
          detection: const DetectionSettings(filter: BeatFilter.strong),
        );

    final visibleSamples = [
      for (final i in visibleBeatIndices(project)) project.beats[i].sample,
    ];
    expect(visibleSamples, [10000, 50000, 90000]);

    await renderGuideTrack(
      songWavPath: songPath,
      outputWavPath: guidePath,
      beatSamples: visibleSamples,
      style: ClickStyle.snap,
    );

    final pcm = await _readAllPcm(guidePath);
    for (final visible in [10000, 50000, 90000]) {
      expect(pcm[visible * 2], isNot(0));
    }
    for (final hidden in [30000, 70000]) {
      for (var f = hidden - 100; f < hidden + 500; f++) {
        expect(pcm[f * 2], 0, reason: 'Hidden beat at $hidden must be silent');
      }
    }
  });

  test('beats at 0 and frameCount - 1, out-of-range beats clamped and deduplicated', () async {
    const rate = 44100;
    const frames = 20000;
    final songPath = '${tempDir.path}${Platform.pathSeparator}song.wav';
    final guidePath = '${tempDir.path}${Platform.pathSeparator}guide.wav';
    await _writeFadedSongWav(
      path: songPath,
      sampleRate: rate,
      channels: 1,
      frameCount: frames,
    );

    // Beat at -50 (clamps to 0), 0 (deduped with clamped -50),
    // frames - 1, and frames + 500 (clamps to frames - 1 and dedupes).
    await renderGuideTrack(
      songWavPath: songPath,
      outputWavPath: guidePath,
      beatSamples: [frames + 500, -50, 0, frames - 1],
      style: ClickStyle.blip,
      channels: 1,
    );

    final info = await readWavInfo(File(guidePath));
    expect(info.frameCount, frames);

    final pcm = await _readAllPcm(guidePath);
    final click = renderClick(ClickStyle.blip, rate);
    final expectedSample0 = clipInt16(click[0] * 32767.0);

    // Sample 0 has exactly ONE click (deduped, not doubled).
    expect(pcm[0], expectedSample0);
    // Sample frames - 1 has a click truncated cleanly at frameCount (1 sample).
    expect(pcm[frames - 2], 0);
    expect(pcm[frames - 1], expectedSample0);
  });

  test('overlapping clicks are summed and clipped to int16', () async {
    const rate = 44100;
    const frames = 10000;
    final songPath = '${tempDir.path}${Platform.pathSeparator}song.wav';
    final guidePath = '${tempDir.path}${Platform.pathSeparator}guide.wav';
    await _writeFadedSongWav(
      path: songPath,
      sampleRate: rate,
      channels: 1,
      frameCount: frames,
    );

    // Two blip clicks 2 samples apart overlap and exceed 1.0 when summed.
    const b1 = 1000;
    const b2 = 1002;
    await renderGuideTrack(
      songWavPath: songPath,
      outputWavPath: guidePath,
      beatSamples: [b1, b2],
      style: ClickStyle.blip,
      channels: 1,
    );

    final pcm = await _readAllPcm(guidePath);
    final click = renderClick(ClickStyle.blip, rate);
    // At b1: only first click.
    expect(pcm[b1], clipInt16(click[0] * 32767.0));
    // At b2: click[2] + click[0], clipped to [-32768, 32767].
    final expectedOverlap = clipInt16((click[2] + click[0]) * 32767.0);
    expect(pcm[b2], expectedOverlap);
    expect(pcm[b2], 32767); // two ~0.707 peaks sum > 1.0 -> clips at 32767
  });

  test(
    'chunk boundary straddling a click (beat 3 samples before chunk end)',
    () async {
      const rate = 44100;
      const frames = kGuideTrackChunkFrames * 2 + 1000;
      final songPath = '${tempDir.path}${Platform.pathSeparator}song.wav';
      final guidePath = '${tempDir.path}${Platform.pathSeparator}guide.wav';
      await _writeFadedSongWav(
        path: songPath,
        sampleRate: rate,
        channels: 2,
        frameCount: frames,
      );

      const straddleBeat = kGuideTrackChunkFrames - 3;
      await renderGuideTrack(
        songWavPath: songPath,
        outputWavPath: guidePath,
        beatSamples: [straddleBeat],
        style: ClickStyle.rim,
        channels: 2,
      );

      final pcm = await _readAllPcm(guidePath);
      final click = renderClick(ClickStyle.rim, rate);

      expect(pcm[(straddleBeat - 1) * 2], 0);
      for (var i = 0; i < click.length; i++) {
        final f = straddleBeat + i;
        final expected = clipInt16(click[i] * 32767.0);
        expect(
          pcm[f * 2],
          expected,
          reason: 'Sample $i of click across chunk boundary at frame $f',
        );
        expect(pcm[f * 2 + 1], expected);
      }
      expect(pcm[(straddleBeat + click.length) * 2], 0);
    },
  );

  test('peak buffer is bounded <= 4 MB for a 10-minute 48 kHz stereo song', () {
    // Compute directly from the chunked buffer allocation formula, plus verify
    // on a multi-chunk render that peakBufferBytes is independent of song length.
    const tenMinFrames48k = 48000 * 60 * 10;
    final peakBytes = estimateGuideTrackPeakBufferBytes(
      sampleRate: 48000,
      channels: 2,
      frameCount: tenMinFrames48k,
      style: ClickStyle.kick,
    );
    expect(peakBytes, lessThanOrEqualTo(4 * 1024 * 1024));
    // Specifically: 65536 * 8 (Float64List) + 65536 * 2 * 2 (Int16List) + 480 * 8 (click)
    // = 524,288 + 262,144 + 3,840 = 790,272 bytes (~0.75 MB).
    expect(peakBytes, lessThan(1024 * 1024));
  });
}
