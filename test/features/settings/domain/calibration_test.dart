import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/settings/domain/latency_calibration.dart';

void main() {
  const sampleRate = 44100;
  const bpm = 100.0; // period = 600 ms = 26,460 samples
  final clicks = calibrationClickSamples(
    sampleRate: sampleRate,
    bpm: bpm,
    durationSeconds: 30,
  );

  int msToSamples(double ms) => (ms * sampleRate / 1000.0).round();

  group('Latency calibration maths', () {
    test('taps at a known offset with small jitter -> median within 1 ms', () {
      const trueOffsetMs = 42.0;
      const jitters = [
        -3.0,
        2.0,
        0.5,
        -1.5,
        4.0,
        -2.5,
        1.0,
        0.0,
        -1.0,
        3.0,
        -0.5,
        2.5,
        -2.0,
        1.5,
        0.2,
        -0.8,
        1.2,
        -1.2,
      ];
      final taps = [
        for (var i = 0; i < jitters.length; i++)
          clicks[i + 2] + msToSamples(trueOffsetMs + jitters[i]),
      ];

      final result = evaluateCalibrationTaps(
        clickSamples: clicks,
        tapSamples: taps,
        sampleRate: sampleRate,
        bpm: bpm,
      );

      expect(result.status, CalibrationStatus.ready);
      expect(result.validTapCount, jitters.length);
      expect(result.offsetMs, isNotNull);
      expect((result.offsetMs! - trueOffsetMs).abs(), lessThanOrEqualTo(1));
    });

    test('outliers are dropped and median of inliers is returned', () {
      const trueOffsetMs = 180.0; // e.g. Bluetooth headphones
      final offsets = <double>[
        178, 181, 180, 179, 182, 180, 179, 181,
        180, 178, 182, 181, 179, 180, // 14 tight inliers
        -250, 280, // 2 wild outliers (within half period = 300 ms)
      ];
      final taps = [
        for (var i = 0; i < offsets.length; i++)
          clicks[i + 2] + msToSamples(offsets[i]),
      ];

      final result = evaluateCalibrationTaps(
        clickSamples: clicks,
        tapSamples: taps,
        sampleRate: sampleRate,
        bpm: bpm,
      );

      expect(result.status, CalibrationStatus.ready);
      expect(result.inlierCount, 14);
      expect((result.offsetMs! - trueOffsetMs).abs(), lessThanOrEqualTo(1));
    });

    test('taps beyond half a period of any click are ignored', () {
      // Only 1 click at sample 100,000; half period at 100 BPM = 13,230 samples.
      final taps = [
        100000 + msToSamples(40), // valid
        100000 + msToSamples(350), // > 300 ms -> ignored
        100000 - msToSamples(350), // > 300 ms -> ignored
      ];
      final result = evaluateCalibrationTaps(
        clickSamples: const [100000],
        tapSamples: taps,
        sampleRate: sampleRate,
        bpm: bpm,
      );
      expect(result.status, CalibrationStatus.needMoreTaps);
      expect(result.validTapCount, 1);
    });

    test('fewer than 16 valid taps returns needMoreTaps', () {
      final taps = [
        for (var i = 0; i < 15; i++) clicks[i + 1] + msToSamples(35),
      ];
      final result = evaluateCalibrationTaps(
        clickSamples: clicks,
        tapSamples: taps,
        sampleRate: sampleRate,
        bpm: bpm,
      );
      expect(result.status, CalibrationStatus.needMoreTaps);
      expect(result.validTapCount, 15);
      expect(result.offsetMs, isNull);
    });

    test('fewer than 12 inliers after outlier removal returns tooUneven', () {
      // 11 tight taps + 5 big outliers -> 11 remaining < 12.
      final offsets = <double>[
        40,
        41,
        39,
        40,
        42,
        38,
        40,
        41,
        39,
        40,
        41,
        240,
        -240,
        260,
        -250,
        270,
      ];
      final taps = [
        for (var i = 0; i < offsets.length; i++)
          clicks[i + 2] + msToSamples(offsets[i]),
      ];
      final result = evaluateCalibrationTaps(
        clickSamples: clicks,
        tapSamples: taps,
        sampleRate: sampleRate,
        bpm: bpm,
      );
      expect(result.status, CalibrationStatus.tooUneven);
      expect(result.offsetMs, isNull);
    });
  });
}
