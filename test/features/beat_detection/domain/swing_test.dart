import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';

import '../../../fixtures/synthetic_audio.dart';
import '../../../fixtures/synthetic_music.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('kv_swing_test_');
  });

  tearDownAll(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('Shuffle / swing grooves at 90 and 120 BPM with swung hats at 0.62 and 0.67', () {
    for (final bpm in [90.0, 120.0]) {
      for (final ratio in [0.62, 0.67]) {
        test('${bpm.round()} BPM shuffle (swing ratio $ratio)', () async {
          final song = await writeSyntheticSwingSong(
            dir,
            bpm: bpm,
            swingRatio: ratio,
          );
          final analysis = await analyzeWavFile(song.path);
          final result = classifyBeats(analysis, sensitivity: 0.5);

          expect(result.succeeded, isTrue);
          // BPM within ±1 of the true beat tempo (not x3/2 = 135/180 or x2/3 = 60/80).
          expect(
            analysis.bpm,
            closeTo(bpm, 1.0),
            reason:
                'Expected ~$bpm BPM (not ${bpm * 1.5} or ${bpm * 2 / 3}), got ${analysis.bpm}',
          );

          final sr = song.sampleRate;
          final tol = (sr * 0.010).round(); // ±10 ms
          final periodSamples = sr * 60.0 / bpm;
          final offBeatSamples = <int>[
            for (final q in song.quarterNotes)
              (q + ratio * periodSamples).round(),
          ];

          final detected = result.beats.map((b) => b.sample).toList();
          var worstErrorMs = 0.0;
          var missed = 0;
          for (final truth in song.quarterNotes) {
            var bestDist = 1 << 30;
            for (final det in detected) {
              final d = (det - truth).abs();
              if (d < bestDist) bestDist = d;
            }
            final errMs = bestDist * 1000.0 / sr;
            if (errMs > worstErrorMs) worstErrorMs = errMs;
            if (bestDist > tol) missed++;
          }

          // Verify no beat lands on a swung off-beat (within ±25 ms of off-beat).
          final offBeatCheckRadius = (sr * 0.025).round();
          var beatsOnOffBeat = 0;
          for (final det in detected) {
            if (offBeatSamples.any(
              (off) => (det - off).abs() <= offBeatCheckRadius,
            )) {
              beatsOnOffBeat++;
            }
          }

          // ignore: avoid_print
          print(
            'SWING_ROW | bpm=${bpm.round()} | trueRatio=$ratio '
            '| detectedBpm=${analysis.bpm.toStringAsFixed(1)} '
            '| estRatio=${analysis.swing.ratio.toStringAsFixed(3)} '
            '| swingConf=${analysis.swing.confidence.toStringAsFixed(2)} '
            '| isSwung=${analysis.swing.isSwung} '
            '| worstError=${worstErrorMs.toStringAsFixed(2)}ms '
            '| missed=$missed | onOffBeat=$beatsOnOffBeat',
          );

          expect(missed, 0);
          expect(worstErrorMs, lessThanOrEqualTo(10.0));
          expect(
            beatsOnOffBeat,
            0,
            reason: 'Found $beatsOnOffBeat tracked beats on swung off-beats',
          );
          expect(
            analysis.swing.ratio,
            closeTo(ratio, 0.05),
            reason:
                'Estimated swing ratio ${analysis.swing.ratio} outside ±0.05 of $ratio',
          );
          expect(analysis.swing.isSwung, isTrue);
        });
      }
    }
  });

  test('Straight fixtures report straight feel (not swung)', () async {
    final straightSwingSong = await writeSyntheticSwingSong(
      dir,
      bpm: 120.0,
      swingRatio: 0.50,
    );
    final a1 = await analyzeWavFile(straightSwingSong.path);
    // ignore: avoid_print
    print(
      'SWING_STRAIGHT_ROW | groove_0.50 | estRatio=${a1.swing.ratio.toStringAsFixed(3)} '
      '| conf=${a1.swing.confidence.toStringAsFixed(2)} | isSwung=${a1.swing.isSwung}',
    );
    expect(a1.swing.isSwung, isFalse);
    expect(a1.swing.ratio, closeTo(0.50, 0.05));

    final clickWith8ths = await writeSyntheticClickTrack(
      dir: dir,
      fileName: 'straight_128_8ths.wav',
      bpm: 128.0,
      subdivisionEighthHiHats: true,
    );
    final a2 = await analyzeWavFile(clickWith8ths.wavPath);
    expect(a2.swing.isSwung, isFalse);
  });
}
