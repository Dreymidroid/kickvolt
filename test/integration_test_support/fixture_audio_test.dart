import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_analyzer.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_classifier.dart';

import '../../integration_test/support/fixture_audio.dart';
import '../../integration_test/support/signal.dart';

/// Host-side checks of the integration-test fixtures and measuring helpers,
/// so a device failure can't be blamed on the fixture itself.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kv_fixture_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  for (final (rate, ch) in [(44100, 2), (48000, 1)]) {
    test('fixture $rate Hz ${ch}ch: valid WAV, detected at 120 BPM, '
        'beats within ±10 ms', () async {
      final fx = FixtureAudio.generate(sampleRate: rate, channels: ch);
      final path = '${tmp.path}/fx.wav';
      await File(path).writeAsBytes(fx.wavBytes());

      final info = await readWavInfo(File(path));
      expect(info.sampleRate, rate);
      expect(info.channels, ch);
      expect(info.frameCount, fx.frameCount);
      expect(fx.frameCount, (10 * rate).round());

      final analysis = await analyzeWavFile(path);
      final result = classifyBeats(analysis, sensitivity: 0.5);
      expect(result.succeeded, isTrue);
      expect((result.bpm! - 120).abs(), lessThanOrEqualTo(1));

      final detected = [for (final b in result.beats) b.sample];
      var worst = 0.0;
      for (final truth in fx.beatSamples) {
        final d = detected
            .map((s) => (s - truth).abs())
            .reduce((a, b) => a < b ? a : b);
        final ms = d * 1000 / rate;
        if (ms > worst) worst = ms;
      }
      // ignore: avoid_print
      print(
        'FIXTURE $rate/$ch: bpm=${result.bpm} beats=${detected.length} '
        'truth=${fx.beatSamples.length} worst=${worst.toStringAsFixed(2)} ms',
      );
      expect(worst, lessThanOrEqualTo(10));
    });
  }

  test('crossCorrelationLag finds a known shift', () {
    final fx = FixtureAudio.generate(sampleRate: 44100, channels: 1);
    final ref = monoMix(fx.pcm, 1, count: 44100 * 3);
    for (final shift in [0, 1, 1024, 2112, -37]) {
      final shifted = Float64List(ref.length);
      for (var i = 0; i < ref.length; i++) {
        final j = i - shift;
        if (j >= 0 && j < ref.length) shifted[i] = ref[j];
      }
      final r = crossCorrelationLag(shifted, ref);
      expect(r.lag, shift, reason: '$r');
      expect(r.normalised, greaterThan(0.9));
    }
  });
}
