import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_analyzer.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_classifier.dart';
import 'package:kickvolt/features/projects/domain/entities/beat.dart';

import '../../../fixtures/synthetic_audio.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kv_detector_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('accuracy matrix (90/120/128 BPM × clean/noisy × 44.1/48 kHz × mono/stereo)', () {
    for (final bpm in [90.0, 120.0, 128.0]) {
      for (final noisy in [false, true]) {
        for (final rate in [44100, 48000]) {
          for (final ch in [1, 2]) {
            final label =
                '${bpm.round()} BPM, ${noisy ? "noisy" : "clean"}, '
                '$rate Hz, ${ch == 1 ? "mono" : "stereo"}';
            test(label, () async {
              final track = await writeSyntheticClickTrack(
                dir: tempDir,
                fileName:
                    'click_${bpm.round()}_${noisy ? "noisy" : "clean"}_${rate}_${ch}ch.wav',
                bpm: bpm,
                sampleRate: rate,
                channels: ch,
                durationSeconds: 45.0,
                startOffsetSeconds: 0.37,
                noisy: noisy,
              );

              final analysis = await analyzeWavFile(track.wavPath);
              final result = classifyBeats(analysis, sensitivity: 0.5);

              expect(result.succeeded, isTrue, reason: 'Failed on $label');
              expect(result.bpm, isNotNull);
              expect(
                (result.bpm! - bpm).abs(),
                lessThanOrEqualTo(1.0),
                reason:
                    'Detected BPM ${result.bpm} outside ±1 of $bpm on $label',
              );

              final toleranceSamples = (rate * 0.010).round(); // ±10 ms
              final detected = result.beats.map((b) => b.sample).toList();
              final matchedDetected = <int>{};
              var worstErrorMs = 0.0;
              var missed = 0;

              for (final truth in track.clickSamples) {
                int? bestIdx;
                var bestDist = 1 << 30;
                for (var i = 0; i < detected.length; i++) {
                  final d = (detected[i] - truth).abs();
                  if (d < bestDist) {
                    bestDist = d;
                    bestIdx = i;
                  }
                }
                final errMs = bestDist * 1000.0 / rate;
                if (errMs > worstErrorMs) worstErrorMs = errMs;
                if (bestIdx != null && bestDist <= toleranceSamples) {
                  matchedDetected.add(bestIdx);
                } else {
                  missed++;
                }
              }

              final extra = detected.length - matchedDetected.length;

              // Print accuracy line for the §10 report table.
              // ignore: avoid_print
              print(
                'ACCURACY_ROW | ${bpm.round()} | ${noisy ? "noisy" : "clean"} '
                '| $rate | $ch | ${result.bpm!.toStringAsFixed(1)} '
                '| ${worstErrorMs.toStringAsFixed(2)} ms '
                '| extra=$extra | missed=$missed',
              );

              expect(
                missed,
                0,
                reason:
                    '$missed ground-truth clicks were not matched within ±10 ms '
                    '(worst error: ${worstErrorMs.toStringAsFixed(2)} ms) on $label',
              );
              expect(
                worstErrorMs,
                lessThanOrEqualTo(10.0),
                reason:
                    'Worst beat error ${worstErrorMs.toStringAsFixed(2)} ms > 10 ms on $label',
              );
              expect(
                extra,
                lessThanOrEqualTo(2),
                reason: 'Found $extra extra beats (max 2) on $label',
              );
            });
          }
        }
      }
    }
  });

  test('octave handling: 128 BPM kicks with quieter 8th-note hi-hats (-12 dB) -> 128 BPM', () async {
    final track = await writeSyntheticClickTrack(
      dir: tempDir,
      fileName: 'octave_128_hihats.wav',
      bpm: 128.0,
      sampleRate: 44100,
      channels: 1,
      durationSeconds: 45.0,
      subdivisionEighthHiHats: true,
    );

    final analysis = await analyzeWavFile(track.wavPath);
    final result = classifyBeats(analysis, sensitivity: 0.5);

    expect(result.succeeded, isTrue);
    expect(result.bpm, isNotNull);
    expect(
      (result.bpm! - 128.0).abs(),
      lessThanOrEqualTo(1.0),
      reason: 'Expected ~128 BPM (not 256 or 64), got ${result.bpm}',
    );
  });

  test('downbeats: 120 BPM where every 4th click is +6 dB with extra low end -> >= 90% on accented clicks', () async {
    final track = await writeSyntheticClickTrack(
      dir: tempDir,
      fileName: 'downbeats_120.wav',
      bpm: 120.0,
      sampleRate: 44100,
      channels: 1,
      durationSeconds: 45.0,
      accentEvery4th: true,
      accentPhase: 1, // test non-zero downbeat phase too
    );

    final analysis = await analyzeWavFile(track.wavPath);
    final result = classifyBeats(analysis, sensitivity: 0.5);

    expect(result.succeeded, isTrue);
    final downbeats = result.beats
        .where((b) => b.type == BeatType.downbeat || b.type == BeatType.drop)
        .toList();
    expect(downbeats, isNotEmpty);

    final tol = (track.sampleRate * 0.015).round();
    var onAccented = 0;
    for (final db in downbeats) {
      final hit = track.accentedClickSamples.any(
        (acc) => (acc - db.sample).abs() <= tol,
      );
      if (hit) onAccented++;
    }

    final ratio = onAccented / downbeats.length;
    expect(
      ratio,
      greaterThanOrEqualTo(0.90),
      reason:
          'Only ${(ratio * 100).toStringAsFixed(1)}% ($onAccented/${downbeats.length}) '
          'of detected downbeats landed on accented clicks',
    );
  });

  test('drops: 16 bars quiet clicks then 16 bars with loud 50-80 Hz bass -> exactly 1 drop within 1 beat', () async {
    final track = await writeSyntheticDropTrack(dir: tempDir);

    final analysis = await analyzeWavFile(track.wavPath);
    final result = classifyBeats(analysis, sensitivity: 0.5);

    expect(result.succeeded, isTrue);
    final drops = result.beats.where((b) => b.type == BeatType.drop).toList();
    expect(
      drops.length,
      1,
      reason: 'Expected exactly 1 drop, found ${drops.length}: $drops',
    );

    final oneBeatSamples = (track.sampleRate * 60.0 / 120.0).round();
    final errSamples = (drops.single.sample - track.dropSample!).abs();
    expect(
      errSamples,
      lessThanOrEqualTo(oneBeatSamples + (track.sampleRate * 0.015).round()),
      reason:
          'Drop at ${drops.single.sample} was more than 1 beat away from truth ${track.dropSample}',
    );
  });

  test('failure: 45 s of white noise and 45 s of sustained chord fail classification', () async {
    final noisePath = await writeWhiteNoiseTrack(
      dir: tempDir,
      durationSeconds: 45.0,
    );
    final noiseAnalysis = await analyzeWavFile(noisePath);
    final noiseResult = classifyBeats(noiseAnalysis, sensitivity: 0.5);
    expect(noiseResult.succeeded, isFalse);
    expect(noiseResult.beats, isEmpty);
    expect(noiseResult.bpm, isNull);

    final chordPath = await writeSustainedChordTrack(
      dir: tempDir,
      durationSeconds: 45.0,
    );
    final chordAnalysis = await analyzeWavFile(chordPath);
    final chordResult = classifyBeats(chordAnalysis, sensitivity: 0.5);
    expect(chordResult.succeeded, isFalse);
    expect(chordResult.beats, isEmpty);
    expect(chordResult.bpm, isNull);
  });

  test('performance: 3-minute 44.1 kHz stereo song analyses in under 10 s', () async {
    final track = await writeSyntheticClickTrack(
      dir: tempDir,
      fileName: 'perf_3min_stereo.wav',
      bpm: 128.0,
      sampleRate: 44100,
      channels: 2,
      durationSeconds: 180.0,
    );

    final sw = Stopwatch()..start();
    final analysis = await analyzeWavFile(track.wavPath);
    sw.stop();

    final elapsedMs = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print(
      'PERF_3MIN_STEREO | elapsed=${elapsedMs}ms '
      '| peakPcmBufferBytes=${analysis.sampleRate > 0 ? maxPcmChunkBytes : 0}',
    );

    expect(
      elapsedMs,
      lessThan(10000),
      reason: '3-minute stereo analysis took $elapsedMs ms (limit 10,000 ms)',
    );
    expect(math.max(0, maxPcmChunkBytes), lessThanOrEqualTo(4 * 1024 * 1024));
  });
}
