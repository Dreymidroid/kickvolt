import 'dart:math' as math;
import 'dart:typed_data';

/// The four click voices shared by M5 click preview and M6 guide-track export.
enum ClickStyle { snap, rim, blip, kick }

/// Target peak level: -3 dBFS (`10^(-3/20)`).
const double kClickPeakLinear = 0.7079457843841379;

/// Clips a floating-point PCM sample (scaled to int16) to signed 16-bit range.
int clipInt16(num sample) => sample.round().clamp(-32768, 32767);

/// Renders one deterministic click burst at [sampleRate] Hz.
///
/// Guarantees:
/// - Attack is at index 0 (first non-zero sample is exactly the beat sample).
/// - Non-zero duration is 5–10 ms with exponential decay.
/// - Peak level is -3 dBFS ([kClickPeakLinear]).
/// - Fixed-seed PRNG so identical inputs always produce identical samples.
Float64List renderClick(ClickStyle style, int sampleRate) {
  final durationMs = switch (style) {
    ClickStyle.snap => 7.0,
    ClickStyle.rim => 7.5,
    ClickStyle.blip => 7.0,
    ClickStyle.kick => 10.0,
  };
  final length = math.max(1, (durationMs * sampleRate / 1000.0).round());
  final out = Float64List(length);

  switch (style) {
    case ClickStyle.snap:
      // High-passed filtered noise burst with fast exponential decay.
      final rng = math.Random(0x534E4150);
      final tau = 0.0016 * sampleRate;
      var prevIn = 0.0;
      for (var i = 0; i < length; i++) {
        final env = math.exp(-i / tau);
        final white = i == 0 ? 1.0 : (rng.nextDouble() * 2.0 - 1.0);
        // 1-pole high-pass difference emphasizes sharp snap transient.
        final hp = i == 0 ? white : (white - 0.7 * prevIn);
        prevIn = white;
        out[i] = env * hp;
      }

    case ClickStyle.rim:
      // Short deterministic noise burst + 1.8 kHz cosine tone (starts at peak).
      final rng = math.Random(0x52494D21);
      final tau = 0.0018 * sampleRate;
      final twoPiF = 2.0 * math.pi * 1800.0 / sampleRate;
      for (var i = 0; i < length; i++) {
        final env = math.exp(-i / tau);
        final noise = i == 0 ? 1.0 : (rng.nextDouble() * 2.0 - 1.0);
        final tone = math.cos(i * twoPiF);
        out[i] = env * (0.65 * tone + 0.35 * noise);
      }

    case ClickStyle.blip:
      // Clean 2 kHz cosine burst (cos(0) = 1 so sample 0 is the exact attack).
      final tau = 0.0017 * sampleRate;
      final twoPiF = 2.0 * math.pi * 2000.0 / sampleRate;
      for (var i = 0; i < length; i++) {
        final env = math.exp(-i / tau);
        out[i] = env * math.cos(i * twoPiF);
      }

    case ClickStyle.kick:
      // 10 ms pitch-dropping cosine (60 Hz -> 40 Hz) with exponential decay.
      final durSec = length / sampleRate;
      final tau = 0.0032 * sampleRate;
      for (var i = 0; i < length; i++) {
        final t = i / sampleRate;
        // Instantaneous frequency f(t) = 60 - 20 * (t / durSec)
        // Phase = integral of 2*pi*f(t) dt = 2*pi * (60*t - 10*t^2 / durSec)
        final phase = 2.0 * math.pi * (60.0 * t - 10.0 * t * t / durSec);
        final env = math.exp(-i / tau);
        out[i] = env * math.cos(phase);
      }
  }

  // Normalize exact peak to -3 dBFS.
  var peak = 0.0;
  for (var i = 0; i < length; i++) {
    final a = out[i].abs();
    if (a > peak) peak = a;
  }
  if (peak > 0) {
    final scale = kClickPeakLinear / peak;
    for (var i = 0; i < length; i++) {
      out[i] *= scale;
    }
  }

  return out;
}

/// Sums clicks for a sorted list of [beatSamples] into [monoOut], which
/// represents the audio frame range `[chunkStart, chunkStart + chunkLength)`.
///
/// Overlapping clicks are summed (caller clips to int16 when quantizing).
/// Clicks extending past [totalSampleCount] are truncated cleanly.
void addClicksToChunk({
  required Float64List monoOut,
  required int chunkStart,
  required int chunkLength,
  required List<int> beatSamples,
  required Float64List click,
  required int totalSampleCount,
}) {
  if (beatSamples.isEmpty || click.isEmpty || chunkLength <= 0) return;
  final chunkEnd = math.min(chunkStart + chunkLength, totalSampleCount);
  if (chunkEnd <= chunkStart) return;

  final clickLen = click.length;
  // First beat whose tail can reach chunkStart: beatSample + clickLen > chunkStart.
  final minBeatSample = chunkStart - clickLen + 1;
  var lo = 0;
  var hi = beatSamples.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (beatSamples[mid] < minBeatSample) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }

  for (var i = lo; i < beatSamples.length; i++) {
    final beatSample = beatSamples[i];
    if (beatSample >= chunkEnd) break;
    if (beatSample < 0) continue;

    final startFrame = math.max(chunkStart, beatSample);
    final endFrame = math.min(chunkEnd, beatSample + clickLen);
    var clickIdx = startFrame - beatSample;
    var outIdx = startFrame - chunkStart;
    for (var f = startFrame; f < endFrame; f++) {
      monoOut[outIdx++] += click[clickIdx++];
    }
  }
}
