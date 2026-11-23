import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_classifier.dart';
import 'package:kickvolt/features/beat_detection/domain/entities/beat_analysis.dart';
import 'package:kickvolt/features/projects/domain/entities/beat.dart';

void main() {
  BeatAnalysis buildSyntheticAnalysis({
    int count = 200,
    double bpm = 120.0,
    double confidence = 3.5,
    bool withDropAtBar16 = false,
  }) {
    const sampleRate = 44100;
    const hopSize = 512;
    final periodSamples = (sampleRate * 60.0 / bpm).round(); // 22050
    final sampleCount = (count + 4) * periodSamples;
    final frameCount = (sampleCount + hopSize - 1) ~/ hopSize;

    final frameLow = Float32List(frameCount);
    final frameOverall = Float32List(frameCount);
    for (var t = 0; t < frameCount; t++) {
      final sample = t * hopSize;
      final beatIdx = sample ~/ periodSamples;
      final inDrop = withDropAtBar16 && beatIdx >= 64 && beatIdx < 128;
      frameLow[t] = inDrop ? 10.0 : 1.0;
      frameOverall[t] = inDrop ? 20.0 : 5.0;
    }

    final candidates = <CandidateBeat>[];
    for (var i = 0; i < count; i++) {
      final isDownbeat = i % 4 == 0;
      final inDrop = withDropAtBar16 && i >= 64 && i < 128;
      // Give distinct strengths in 0..1 so percentiles are strictly ordered.
      final base = ((i * 37) % count) / count;
      final strength = isDownbeat
          ? (0.5 + 0.5 * base).clamp(0.0, 1.0)
          : (0.85 * base).clamp(0.0, 1.0);
      final lowEnergy = inDrop ? 10.0 : (isDownbeat ? 2.5 : 1.0);
      candidates.add(
        CandidateBeat(
          index: i,
          sample: i * periodSamples + 1000,
          strength: strength,
          lowEnergy: lowEnergy,
        ),
      );
    }

    return BeatAnalysis(
      sampleRate: sampleRate,
      sampleCount: sampleCount,
      hopSize: hopSize,
      bpm: bpm,
      confidence: confidence,
      beatPhaseSample: 1000,
      candidates: candidates,
      frameLowEnergy: frameLow,
      frameOverallEnergy: frameOverall,
    );
  }

  test('monotonic sensitivity: beat count and strong count never drop as sensitivity rises (0..1 step 0.1)', () {
    final analysis = buildSyntheticAnalysis(count: 240, withDropAtBar16: true);
    var prevBeats = -1;
    var prevStrong = -1;

    for (var step = 0; step <= 10; step++) {
      final s = step / 10.0;
      final result = classifyBeats(analysis, sensitivity: s);
      expect(result.succeeded, isTrue);

      final beatCount = result.beats.length;
      final strongCount = result.beats
          .where((b) => b.type != BeatType.beat)
          .length;

      expect(
        beatCount,
        greaterThanOrEqualTo(prevBeats),
        reason: 'beatCount dropped at sensitivity=$s ($beatCount < $prevBeats)',
      );
      expect(
        strongCount,
        greaterThanOrEqualTo(prevStrong),
        reason:
            'strongCount dropped at sensitivity=$s ($strongCount < $prevStrong)',
      );

      if (s >= 0.5) {
        // At >= 0.5 nothing is pruned.
        expect(beatCount, analysis.candidates.length);
      }

      prevBeats = beatCount;
      prevStrong = strongCount;
    }
  });

  test('strong percentile matches formula p = 85 - 40 * sensitivity', () {
    // 100 candidates with uniform strengths 0.00, 0.01, ..., 0.99
    // Equal lowEnergy and non-4-periodic strengths so downbeats don't obscure
    // the strong count on non-downbeat phases.
    const count = 100;
    const sampleRate = 44100;
    const hopSize = 512;
    const period = 22050;
    final candidates = <CandidateBeat>[
      for (var i = 0; i < count; i++)
        CandidateBeat(
          index: i,
          sample: (i + 1) * period,
          strength: i / (count - 1),
          lowEnergy: i % 4 == 0 ? 5.0 : 1.0, // phase 0 is downbeats
        ),
    ];
    final analysis = BeatAnalysis(
      sampleRate: sampleRate,
      sampleCount: (count + 2) * period,
      hopSize: hopSize,
      bpm: 120.0,
      confidence: 4.0,
      beatPhaseSample: 0,
      candidates: candidates,
      frameLowEnergy: Float32List.fromList(List<double>.filled(5000, 1.0)),
      frameOverallEnergy: Float32List.fromList(List<double>.filled(5000, 1.0)),
    );

    for (final sens in [0.5, 0.75, 1.0]) {
      final p = 85.0 - 40.0 * sens;
      final threshold = percentileOf(
        candidates.map((c) => c.strength).toList(),
        p,
      );
      final res = classifyBeats(analysis, sensitivity: sens);
      for (var i = 0; i < res.beats.length; i++) {
        final b = res.beats[i];
        final c = candidates[i];
        if (i % 4 != 0) {
          // Non-downbeats must be strong iff c.strength >= threshold
          if (c.strength >= threshold) {
            expect(b.type, BeatType.strong);
          } else {
            expect(b.type, BeatType.beat);
          }
        }
      }
    }
  });

  test('type precedence: drop > downbeat > strong > beat', () {
    final analysis = buildSyntheticAnalysis(count: 160, withDropAtBar16: true);
    final res = classifyBeats(analysis, sensitivity: 0.8);
    expect(res.succeeded, isTrue);

    // Beat 64 is both a downbeat (index % 4 == 0), strong (high strength),
    // and where the 2-bar low-band energy jumps >= 2x over previous 4 bars.
    // Because drop > downbeat > strong > beat, it must be classified as drop.
    final dropBeats = res.beats.where((b) => b.type == BeatType.drop).toList();
    expect(dropBeats.length, 1);
    expect(dropBeats.single.sample, analysis.candidates[64].sample);

    // Other phase-0 beats that also qualify for strong must be downbeat
    // because downbeat > strong.
    final beat0 = res.beats.firstWhere(
      (b) => b.sample == analysis.candidates[0].sample,
    );
    expect(beat0.type, BeatType.downbeat);
  });

  test('classification of 2,000 candidates completes in < 5 ms (median of 20 runs)', () {
    final analysis = buildSyntheticAnalysis(count: 2000, withDropAtBar16: true);
    // Warm up JIT.
    for (var i = 0; i < 5; i++) {
      classifyBeats(analysis, sensitivity: 0.5);
    }

    final elapsedUs = <int>[];
    final sw = Stopwatch();
    for (var i = 0; i < 20; i++) {
      sw
        ..reset()
        ..start();
      final res = classifyBeats(analysis, sensitivity: 0.55);
      sw.stop();
      expect(res.beats.length, 2000);
      elapsedUs.add(sw.elapsedMicroseconds);
    }
    elapsedUs.sort();
    final medianMs = elapsedUs[10] / 1000.0;
    expect(
      medianMs,
      lessThan(5.0),
      reason: 'Median classification time for 2,000 beats was $medianMs ms',
    );
  });
}
