// Detection on music-like audio, beyond click tracks: a kick-on-1-and-3
// groove (the classic half-tempo trap) and a drumless acoustic track, at
// several loudness levels. Hits are humanised by up to ±6 ms, so beats are
// checked against the quarter-note grid at ±15 ms.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';

import '../../../fixtures/synthetic_music.dart';

void main() {
  late Directory dir;
  setUpAll(() => dir = Directory.systemTemp.createTempSync('music_detect'));
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<DetectionResult> detect(SyntheticSong song) async =>
      classifyBeats(await analyzeWavFile(song.path), sensitivity: 0.5);

  void expectOnGrid(DetectionResult r, SyntheticSong song, double bpm) {
    expect(r.succeeded, isTrue, reason: 'no steady beat found');
    expect(r.bpm, closeTo(bpm, 1.0), reason: 'tempo');
    final tol = (song.sampleRate * 0.015).round();
    final missed = <int>[];
    for (final t in song.quarterNotes) {
      if (!r.beats.any((b) => (b.sample - t).abs() <= tol)) missed.add(t);
    }
    expect(
      missed,
      isEmpty,
      reason:
          '${missed.length}/${song.quarterNotes.length} quarter notes have '
          'no beat within 15 ms',
    );
    expect(r.beats.length - song.quarterNotes.length, lessThanOrEqualTo(2));
  }

  group('kick on 1 and 3 groove', () {
    for (final bpm in [75.0, 100.0, 128.0, 140.0]) {
      for (final gain in [0.0, -12.0, -24.0]) {
        test('$bpm BPM at $gain dB', () async {
          final song = await writeSyntheticSong(
            dir,
            style: SongStyle.groove,
            bpm: bpm,
            gainDb: gain,
          );
          expectOnGrid(await detect(song), song, bpm);
        });
      }
    }
  });

  group('acoustic, no drums', () {
    for (final gain in [0.0, -6.0, -12.0, -18.0]) {
      test('90 BPM at $gain dB', () async {
        final song = await writeSyntheticSong(
          dir,
          style: SongStyle.acoustic,
          bpm: 90,
          gainDb: gain,
        );
        expectOnGrid(await detect(song), song, 90);
      });
    }
  });

  test('the result does not depend on loudness', () async {
    final results = <DetectionResult>[];
    for (final gain in [0.0, -10.0, -20.0, -30.0]) {
      results.add(
        await detect(
          await writeSyntheticSong(
            dir,
            style: SongStyle.groove,
            bpm: 128,
            gainDb: gain,
            seed: 11,
          ),
        ),
      );
    }
    final ref = results.first;
    for (final r in results.skip(1)) {
      expect(r.succeeded, ref.succeeded);
      expect(r.bpm, closeTo(ref.bpm!, 0.15));
      expect(r.beats.length, ref.beats.length);
      for (var i = 0; i < r.beats.length; i++) {
        // 16-bit rounding differs between levels; allow 1 ms.
        expect((r.beats[i].sample - ref.beats[i].sample).abs(), lessThan(45));
      }
    }
  });
}
