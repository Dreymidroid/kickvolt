import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';

import '../../../fixtures/synthetic_audio.dart';
import '../../../fixtures/synthetic_music.dart';
import 'main_baseline_data.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('kv_no_regression_');
  });

  tearDownAll(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Future<void> verifyIdenticalToMain(String key, String wavPath) async {
    final expected = kMainBaseline[key];
    expect(expected, isNotNull, reason: 'Missing baseline entry for $key');

    final analysis = await analyzeWavFile(wavPath);
    final result = classifyBeats(analysis, sensitivity: 0.5);

    expect(result.succeeded, isTrue, reason: '$key failed classification');
    expect(result.bpm, expected!.bpm, reason: 'BPM changed on $key');
    expect(
      result.beatPhaseSample,
      expected.phase,
      reason: 'beatPhaseSample changed on $key',
    );
    expect(
      result.beats.map((b) => b.sample).toList(),
      expected.samples,
      reason: 'Beat samples changed on $key',
    );
  }

  group('M4 click track fixtures match main identically', () {
    for (final (bpm, noisy, rate, ch) in [
      (90.0, false, 44100, 1),
      (90.0, true, 48000, 2),
      (120.0, false, 44100, 2),
      (120.0, true, 44100, 1),
      (128.0, false, 48000, 1),
      (128.0, true, 48000, 2),
    ]) {
      final key =
          'click_${bpm.round()}_${noisy ? "noisy" : "clean"}_${rate}_${ch}ch';
      test(key, () async {
        final track = await writeSyntheticClickTrack(
          dir: dir,
          fileName: '$key.wav',
          bpm: bpm,
          sampleRate: rate,
          channels: ch,
          durationSeconds: 45.0,
          startOffsetSeconds: 0.37,
          noisy: noisy,
        );
        await verifyIdenticalToMain(key, track.wavPath);
      });
    }

    test('octave_128_hihats', () async {
      final octave = await writeSyntheticClickTrack(
        dir: dir,
        fileName: 'octave_128_hihats.wav',
        bpm: 128.0,
        sampleRate: 44100,
        channels: 1,
        durationSeconds: 45.0,
        subdivisionEighthHiHats: true,
      );
      await verifyIdenticalToMain('octave_128_hihats', octave.wavPath);
    });

    test('downbeats_120', () async {
      final downbeats = await writeSyntheticClickTrack(
        dir: dir,
        fileName: 'downbeats_120.wav',
        bpm: 120.0,
        sampleRate: 44100,
        channels: 1,
        durationSeconds: 45.0,
        accentEvery4th: true,
        accentPhase: 1,
      );
      await verifyIdenticalToMain('downbeats_120', downbeats.wavPath);
    });

    test('drops_120', () async {
      final drops = await writeSyntheticDropTrack(dir: dir);
      await verifyIdenticalToMain('drops_120', drops.wavPath);
    });
  });

  group('M4 music-like grooves at 0/-12/-24 dB match main identically', () {
    for (final bpm in [75.0, 100.0, 128.0, 140.0]) {
      for (final gain in [0.0, -12.0, -24.0]) {
        final key = 'groove_${bpm.round()}_${gain.round()}dB';
        test(key, () async {
          final song = await writeSyntheticSong(
            dir,
            style: SongStyle.groove,
            bpm: bpm,
            gainDb: gain,
          );
          await verifyIdenticalToMain(key, song.path);
        });
      }
    }
  });

  group(
    'M4 drumless acoustic tracks at 0/-6/-12/-18 dB match main identically',
    () {
      for (final gain in [0.0, -6.0, -12.0, -18.0]) {
        final key = 'acoustic_90_${gain.round()}dB';
        test(key, () async {
          final song = await writeSyntheticSong(
            dir,
            style: SongStyle.acoustic,
            bpm: 90,
            gainDb: gain,
          );
          await verifyIdenticalToMain(key, song.path);
        });
      }
    },
  );
}
