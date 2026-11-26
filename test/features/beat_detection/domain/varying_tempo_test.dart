import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/synthetic_audio.dart';
import '../../../fixtures/synthetic_music.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('kv_varying_tempo_test_');
  });

  tearDownAll(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  ({
    double worstErrorMs,
    int missed,
    double worstIbiBpmError,
    double gridDriftMs,
  })
  evaluateAccuracy({
    required List<int> detectedSamples,
    required List<int> truthSamples,
    required int sampleRate,
    required double reportedBpm,
  }) {
    final tol = (sampleRate * 0.010).round();
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

    // Also measure worst drift against a constant-tempo grid at `reportedBpm`
    // (shows why a single constant-BPM grid slides off a varying-tempo song).
    var gridDriftMs = 0.0;
    if (truthSamples.length >= 2 && reportedBpm > 0) {
      final periodSamples = sampleRate * 60.0 / reportedBpm;
      final t0 = truthSamples.first;
      for (var i = 0; i < truthSamples.length; i++) {
        final gridSample = t0 + i * periodSamples;
        final driftMs =
            (truthSamples[i] - gridSample).abs() * 1000.0 / sampleRate;
        if (driftMs > gridDriftMs) gridDriftMs = driftMs;
      }
    }

    var worstIbiBpmError = 0.0;
    if (detectedSamples.length >= 2 && reportedBpm > 0) {
      for (var i = 1; i < detectedSamples.length; i++) {
        final ibi = detectedSamples[i] - detectedSamples[i - 1];
        if (ibi > 0) {
          final instBpm = sampleRate * 60.0 / ibi;
          final err = (instBpm - reportedBpm).abs();
          if (err > worstIbiBpmError) worstIbiBpmError = err;
        }
      }
    }

    return (
      worstErrorMs: worstErrorMs,
      missed: missed,
      worstIbiBpmError: worstIbiBpmError,
      gridDriftMs: gridDriftMs,
    );
  }

  void checkLocalOctaveConsistency(
    BeatAnalysis analysis, {
    required double minExpectedBpm,
    required double maxExpectedBpm,
  }) {
    final framesPerSec = analysis.sampleRate / analysis.hopSize;
    expect(analysis.localTempo, isNotEmpty);
    for (final period in analysis.localTempo) {
      final localBpm = framesPerSec * 60.0 / period;
      expect(
        localBpm,
        inInclusiveRange(minExpectedBpm, maxExpectedBpm),
        reason:
            'Local tempo $localBpm BPM flipped octave outside [$minExpectedBpm, $maxExpectedBpm]',
      );
    }
  }

  test('Linear ramp 120 -> 130 BPM over 60 s: varying mode tracks every beat within ±10 ms and suggests varying tempo', () async {
    final song = await writeSyntheticVaryingTempoSong(
      dir,
      name: 'ramp_120_130',
      seconds: 60.0,
      bpmAtTimeSeconds: (t) => 120.0 + (10.0 * (t / 60.0).clamp(0.0, 1.0)),
    );

    final analysis = await analyzeWavFile(song.path);
    final steadyEval = evaluateAccuracy(
      detectedSamples: analysis.candidates.map((c) => c.sample).toList(),
      truthSamples: song.quarterNotes,
      sampleRate: song.sampleRate,
      reportedBpm: analysis.bpm,
    );

    final varyingAnalysis = await retrack(
      analysis,
      const TrackingOptions(tempoMode: TempoMode.varying),
      wavPath: song.path,
    );
    final varyingEval = evaluateAccuracy(
      detectedSamples: varyingAnalysis.candidates.map((c) => c.sample).toList(),
      truthSamples: song.quarterNotes,
      sampleRate: song.sampleRate,
      reportedBpm: varyingAnalysis.bpm,
    );

    // ignore: avoid_print
    print(
      'VARYING_ROW | Ramp 120->130 | autoBpm=${analysis.bpm} '
      '| steadyWorst=${steadyEval.worstErrorMs.toStringAsFixed(2)}ms (missed=${steadyEval.missed}, gridDrift=${steadyEval.gridDriftMs.toStringAsFixed(1)}ms) '
      '| varyingBpm=${varyingAnalysis.bpm} '
      '| varyingWorst=${varyingEval.worstErrorMs.toStringAsFixed(2)}ms (missed=${varyingEval.missed}) '
      '| stability=${analysis.tempoStability.toStringAsFixed(4)}',
    );

    expect(analysis.suggestsTempoChanges, isTrue);
    checkLocalOctaveConsistency(
      analysis,
      minExpectedBpm: 105.0,
      maxExpectedBpm: 145.0,
    );
    expect(varyingEval.missed, 0);
    expect(varyingEval.worstErrorMs, lessThanOrEqualTo(10.0));
    expect(steadyEval.gridDriftMs, greaterThan(500.0));
  });

  test('Step change 100 -> 140 BPM at 30 s: varying mode tracks every beat within ±10 ms and suggests varying tempo', () async {
    final song = await writeSyntheticVaryingTempoSong(
      dir,
      name: 'step_100_140',
      seconds: 60.0,
      bpmAtTimeSeconds: (t) => t < 30.0 ? 100.0 : 140.0,
    );

    final analysis = await analyzeWavFile(song.path);
    final steadyEval = evaluateAccuracy(
      detectedSamples: analysis.candidates.map((c) => c.sample).toList(),
      truthSamples: song.quarterNotes,
      sampleRate: song.sampleRate,
      reportedBpm: analysis.bpm,
    );

    final varyingAnalysis = await retrack(
      analysis,
      const TrackingOptions(tempoMode: TempoMode.varying),
      wavPath: song.path,
    );
    final varyingEval = evaluateAccuracy(
      detectedSamples: varyingAnalysis.candidates.map((c) => c.sample).toList(),
      truthSamples: song.quarterNotes,
      sampleRate: song.sampleRate,
      reportedBpm: varyingAnalysis.bpm,
    );

    // ignore: avoid_print
    print(
      'VARYING_ROW | Step 100->140 | autoBpm=${analysis.bpm} '
      '| steadyWorst=${steadyEval.worstErrorMs.toStringAsFixed(2)}ms (missed=${steadyEval.missed}, gridDrift=${steadyEval.gridDriftMs.toStringAsFixed(1)}ms) '
      '| varyingBpm=${varyingAnalysis.bpm} '
      '| varyingWorst=${varyingEval.worstErrorMs.toStringAsFixed(2)}ms (missed=${varyingEval.missed}) '
      '| stability=${analysis.tempoStability.toStringAsFixed(4)}',
    );

    expect(analysis.suggestsTempoChanges, isTrue);
    checkLocalOctaveConsistency(
      analysis,
      minExpectedBpm: 85.0,
      maxExpectedBpm: 160.0,
    );
    expect(varyingEval.missed, 0);
    expect(varyingEval.worstErrorMs, lessThanOrEqualTo(10.0));
    expect(steadyEval.worstErrorMs, greaterThan(10.0));
  });

  test('Slow drift ±2% around 120 BPM (live feel): varying mode tracks every beat within ±10 ms', () async {
    final song = await writeSyntheticVaryingTempoSong(
      dir,
      name: 'drift_120_2pct',
      seconds: 60.0,
      bpmAtTimeSeconds: (t) =>
          120.0 * (1.0 + 0.02 * math.sin(2 * math.pi * t / 30.0)),
    );

    final analysis = await analyzeWavFile(song.path);
    final steadyEval = evaluateAccuracy(
      detectedSamples: analysis.candidates.map((c) => c.sample).toList(),
      truthSamples: song.quarterNotes,
      sampleRate: song.sampleRate,
      reportedBpm: analysis.bpm,
    );

    final varyingAnalysis = await retrack(
      analysis,
      const TrackingOptions(tempoMode: TempoMode.varying),
      wavPath: song.path,
    );
    final varyingEval = evaluateAccuracy(
      detectedSamples: varyingAnalysis.candidates.map((c) => c.sample).toList(),
      truthSamples: song.quarterNotes,
      sampleRate: song.sampleRate,
      reportedBpm: varyingAnalysis.bpm,
    );

    // ignore: avoid_print
    print(
      'VARYING_ROW | Drift 120 ±2% | autoBpm=${analysis.bpm} '
      '| steadyWorst=${steadyEval.worstErrorMs.toStringAsFixed(2)}ms (missed=${steadyEval.missed}, gridDrift=${steadyEval.gridDriftMs.toStringAsFixed(1)}ms) '
      '| varyingBpm=${varyingAnalysis.bpm} '
      '| varyingWorst=${varyingEval.worstErrorMs.toStringAsFixed(2)}ms (missed=${varyingEval.missed}) '
      '| stability=${analysis.tempoStability.toStringAsFixed(4)}',
    );

    checkLocalOctaveConsistency(
      analysis,
      minExpectedBpm: 110.0,
      maxExpectedBpm: 130.0,
    );
    expect(varyingEval.missed, 0);
    expect(varyingEval.worstErrorMs, lessThanOrEqualTo(10.0));
  });

  test('Steady fixtures do NOT suggest tempo changes', () async {
    final clickTrack = await writeSyntheticClickTrack(
      dir: dir,
      fileName: 'steady_128.wav',
      bpm: 128.0,
      durationSeconds: 45.0,
    );
    final clickAnalysis = await analyzeWavFile(clickTrack.wavPath);
    expect(
      clickAnalysis.suggestsTempoChanges,
      isFalse,
      reason:
          'Steady click track had tempoStability=${clickAnalysis.tempoStability}',
    );

    final grooveSong = await writeSyntheticSong(
      dir,
      style: SongStyle.groove,
      bpm: 120.0,
    );
    final grooveAnalysis = await analyzeWavFile(grooveSong.path);
    expect(
      grooveAnalysis.suggestsTempoChanges,
      isFalse,
      reason:
          'Steady groove had tempoStability=${grooveAnalysis.tempoStability}',
    );
  });
}
