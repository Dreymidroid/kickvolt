import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';

void main() {
  group('ClickSynth', () {
    for (final sampleRate in const [44100, 48000]) {
      for (final style in ClickStyle.values) {
        test(
          '$style at $sampleRate Hz meets attack, length, peak and determinism',
          () {
            final click = renderClick(style, sampleRate);
            final clickAgain = renderClick(style, sampleRate);

            // Deterministic (fixed seed).
            expect(click, clickAgain);

            // Attack is exactly at index 0 (non-zero even after int16 quantization).
            expect(clipInt16(click[0] * 32767.0), isNot(0));

            // Non-zero length in int16 is 5–10 ms.
            var lastNonZero = -1;
            var peak = 0.0;
            for (var i = 0; i < click.length; i++) {
              final abs = click[i].abs();
              if (abs > peak) peak = abs;
              if (clipInt16(click[i] * 32767.0) != 0) {
                lastNonZero = i;
              }
            }
            final nonZeroMs = (lastNonZero + 1) * 1000.0 / sampleRate;
            expect(nonZeroMs, greaterThanOrEqualTo(5.0));
            expect(nonZeroMs, lessThanOrEqualTo(10.0));

            // Peak is -3 dBFS ± 0.1 dB.
            final peakDbfs = 20.0 * math.log(peak) / math.ln10;
            expect(peakDbfs, closeTo(-3.0, 0.1));
          },
        );
      }
    }

    test('overlapping clicks are summed and clipped to int16', () {
      const sampleRate = 44100;
      final click = renderClick(ClickStyle.blip, sampleRate);
      // Place two clicks only 2 samples apart so their peaks overlap (> 1.0).
      final buf = Float64List(click.length + 10);
      addClicksToChunk(
        monoOut: buf,
        chunkStart: 0,
        chunkLength: buf.length,
        beatSamples: const [0, 2],
        click: click,
        totalSampleCount: buf.length,
      );
      expect(buf[0], closeTo(click[0], 1e-12));
      expect(buf[2], closeTo(click[2] + click[0], 1e-12));
      // Verify clipping to int16 bounds.
      final clipped = clipInt16(buf[2] * 32767.0);
      expect(clipped, inInclusiveRange(-32768, 32767));
      // Sum of two ~0.7079 peaks exceeds 1.0 -> saturates to 32767.
      final maxSum = buf.reduce((a, b) => a.abs() > b.abs() ? a : b);
      expect(maxSum.abs(), greaterThan(1.0));
      expect(clipInt16(maxSum * 32767.0).abs(), greaterThanOrEqualTo(32767));
    });

    test('click at sampleCount - 1 truncates without error', () {
      const sampleRate = 44100;
      const totalSamples = 1000;
      final click = renderClick(ClickStyle.kick, sampleRate);
      final buf = Float64List(totalSamples);

      addClicksToChunk(
        monoOut: buf,
        chunkStart: 0,
        chunkLength: totalSamples,
        beatSamples: const [totalSamples - 1],
        click: click,
        totalSampleCount: totalSamples,
      );
      expect(buf[totalSamples - 1], closeTo(click[0], 1e-12));
      expect(buf[totalSamples - 2], 0.0);
    });
  });
}
