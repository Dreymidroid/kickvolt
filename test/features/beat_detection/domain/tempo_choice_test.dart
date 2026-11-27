import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/synthetic_music.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('kv_tempo_choice_test_');
  });

  tearDownAll(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  void expectBeatsWithin10Ms({
    required List<int> detectedSamples,
    required List<int> truthSamples,
    required int sampleRate,
    required String label,
  }) {
    final tol = (sampleRate * 0.010).round(); // ±10 ms
    var worstErrorMs = 0.0;
    var missed = 0;

    for (final truth in truthSamples) {
      var bestDist = 1 << 30;
      for (final det in detectedSamples) {
        final d = (det - truth).abs();
        if (d < bestDist) bestDist = d;
      }
      final errMs = bestDist * 1000.0 / sampleRate;
      if (errMs > worstErrorMs) worstErrorMs = errMs;
      if (bestDist > tol) missed++;
    }

    // ignore: avoid_print
    print(
      'TEMPO_CHOICE_ROW | $label | checked=${truthSamples.length} '
      '| detected=${detectedSamples.length} '
      '| worstError=${worstErrorMs.toStringAsFixed(2)}ms | missed=$missed',
    );

    expect(
      missed,
      0,
      reason:
          '$missed/${truthSamples.length} beats missed ±10 ms '
          '(worst ${worstErrorMs.toStringAsFixed(2)} ms) on $label',
    );
    expect(
      worstErrorMs,
      lessThanOrEqualTo(10.0),
      reason:
          'Worst error ${worstErrorMs.toStringAsFixed(2)} ms > 10 ms on $label',
    );
  }

  for (final rate in [44100, 48000]) {
    test(
      '174 BPM drum-and-bass groove at $rate Hz: 2x or 174 candidate tracks every 174-BPM beat within ±10 ms',
      () async {
        final song = await writeSyntheticDnbSong(
          dir,
          bpm: 174.0,
          sampleRate: rate,
        );
        final analysis = await analyzeWavFile(song.path);

        // Record what Auto reads (often ~87 BPM due to prior at 120 BPM).
        // ignore: avoid_print
        print(
          'DNB_AUTO_$rate | autoBpm=${analysis.bpm} '
          '| candidates=${analysis.tempoCandidates.map((c) => c.bpm.toStringAsFixed(1)).toList()}',
        );

        // Tempo candidates must be distinct, <= 5, and include octave relatives.
        expect(analysis.tempoCandidates, isNotEmpty);
        expect(analysis.tempoCandidates.length, lessThanOrEqualTo(5));
        for (var i = 0; i < analysis.tempoCandidates.length; i++) {
          for (var j = i + 1; j < analysis.tempoCandidates.length; j++) {
            expect(
              (analysis.tempoCandidates[i].bpm -
                      analysis.tempoCandidates[j].bpm)
                  .abs(),
              greaterThan(1.5),
              reason: 'Candidates must be distinct',
            );
          }
        }
        expect(
          analysis.tempoCandidates.any((c) => (c.bpm - 174.0).abs() <= 2.0),
          isTrue,
          reason: '174 BPM candidate must be present in tempoCandidates',
        );

        // Choosing 2x (if Auto read ~87) or the ~174 BPM target gives beats on every
        // 174-BPM period within ±10 ms.
        final targetBpm = analysis.bpm < 120.0 ? analysis.bpm * 2.0 : 174.0;
        final retracked = await retrack(
          analysis,
          const TrackingOptions(tempoMode: TempoMode.steady)
              .copyWith(targetBpm: targetBpm),
          wavPath: song.path,
        );

        expect(retracked.bpm, closeTo(174.0, 1.0));
        expectBeatsWithin10Ms(
          detectedSamples: retracked.candidates.map((c) => c.sample).toList(),
          truthSamples: song.quarterNotes,
          sampleRate: rate,
          label:
              'DnB 174 BPM ($rate Hz, chosen=${targetBpm.toStringAsFixed(1)})',
        );
      },
    );

    test(
      'Half-time hip-hop at 70 / 140 BPM ($rate Hz): both choices produce on-grid beats within ±10 ms and ½x/2x round-trip returns original beats exactly',
      () async {
        final song = await writeSyntheticHalfTimeHipHopSong(
          dir,
          fastBpm: 140.0,
          sampleRate: rate,
        );
        final analysis = await analyzeWavFile(song.path);
        final grid140 = song.quarterNotes;
        final grid70 = <int>[
          for (var i = 0; i < grid140.length; i += 2) grid140[i],
        ];

        // 1. Track at 70 BPM (half-time)
        final at70 = await retrack(
          analysis,
          const TrackingOptions(targetBpm: 70.0, tempoMode: TempoMode.steady),
          wavPath: song.path,
        );
        expect(at70.bpm, closeTo(70.0, 1.0));
        expectBeatsWithin10Ms(
          detectedSamples: at70.candidates.map((c) => c.sample).toList(),
          truthSamples: grid70,
          sampleRate: rate,
          label: 'Hip-hop 70 BPM ($rate Hz)',
        );

        // 2. Track at 140 BPM (double-time)
        final at140 = await retrack(
          analysis,
          const TrackingOptions(targetBpm: 140.0, tempoMode: TempoMode.steady),
          wavPath: song.path,
        );
        expect(at140.bpm, closeTo(140.0, 1.0));
        expectBeatsWithin10Ms(
          detectedSamples: at140.candidates.map((c) => c.sample).toList(),
          truthSamples: grid140,
          sampleRate: rate,
          label: 'Hip-hop 140 BPM ($rate Hz)',
        );

        // 3. ½x / 2x round trip returns the original beats exactly.
        final originalSamples = analysis.candidates
            .map((c) => c.sample)
            .toList();
        final halfBpm = analysis.bpm * 0.5;
        final halfTracked = await retrack(
          analysis,
          TrackingOptions(targetBpm: halfBpm, tempoMode: TempoMode.steady),
          wavPath: song.path,
        );
        expect(
          halfTracked.candidates.map((c) => c.sample).toList(),
          isNot(equals(originalSamples)),
        );

        // Round trip back to Auto (targetBpm: null) or double of halfBpm:
        final backToAuto = await retrack(
          analysis,
          const TrackingOptions(tempoMode: TempoMode.steady),
          wavPath: song.path,
        );
        expect(
          backToAuto.candidates.map((c) => c.sample).toList(),
          equals(originalSamples),
        );
        expect(backToAuto.bpm, analysis.bpm);
        expect(backToAuto.beatPhaseSample, analysis.beatPhaseSample);
      },
    );
  }
}
