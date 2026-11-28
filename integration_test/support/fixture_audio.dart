import 'dart:math' as math;
import 'dart:typed_data';

/// A synthetic test song generated at test time (§A3.1): kick + hat clicks
/// over a soft pad, with exact ground-truth beat samples.
///
/// Pure Dart (no Flutter, no app code) so the same bytes can be made on the
/// host (`test/integration_test_support/`) and on the device.
class FixtureAudio {
  FixtureAudio._({
    required this.sampleRate,
    required this.channels,
    required this.pcm,
    required this.beatSamples,
    required this.bpm,
  });

  final int sampleRate;
  final int channels;

  /// Interleaved 16-bit PCM.
  final Int16List pcm;

  /// Sample index where each kick's attack starts (the ground truth).
  final List<int> beatSamples;
  final double bpm;

  int get frameCount => pcm.length ~/ channels;

  /// A canonical 44-byte-header PCM WAV of [pcm].
  Uint8List wavBytes() {
    final dataBytes = pcm.length * 2;
    final out = Uint8List(44 + dataBytes);
    final b = ByteData.sublistView(out);
    void ascii(int at, String s) {
      for (var i = 0; i < s.length; i++) {
        out[at + i] = s.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    b.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, channels, Endian.little);
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * channels * 2, Endian.little);
    b.setUint16(32, channels * 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    b.setUint32(40, dataBytes, Endian.little);
    out.buffer
        .asUint8List(44)
        .setAll(0, pcm.buffer.asUint8List(pcm.offsetInBytes, dataBytes));
    return out;
  }

  /// Generates the fixture.
  ///
  /// - Kicks on every beat at [bpm], starting [firstBeatSeconds] in: a
  ///   150→50 Hz pitch-dropping sine (~120 ms decay) plus a 3 ms noise
  ///   transient, both starting exactly at the beat sample.
  /// - Closed hats on the off-beats (8ths), −14 dB, 25 ms decay.
  /// - A soft A-minor pad (−30 dB) with 200 ms fades in and out.
  /// - Stereo: hats panned slightly left, pad slightly wide; kicks centred.
  static FixtureAudio generate({
    int sampleRate = 44100,
    int channels = 2,
    double seconds = 10,
    double bpm = 120,
    double firstBeatSeconds = 0.37,
    int seed = 7,
  }) {
    assert(channels == 1 || channels == 2);
    final frames = (seconds * sampleRate).round();
    final left = Float64List(frames);
    final right = Float64List(frames);
    final rng = math.Random(seed);

    // Pad: A3, C4, E4 with fades.
    const padFreqs = [220.0, 261.63, 329.63];
    const padAmp = 0.03 / 3;
    final fade = (0.2 * sampleRate).round();
    for (var i = 0; i < frames; i++) {
      var env = 1.0;
      if (i < fade) env = i / fade;
      if (i > frames - fade) env = (frames - i) / fade;
      var l = 0.0, r = 0.0;
      for (var k = 0; k < padFreqs.length; k++) {
        final s = math.sin(2 * math.pi * padFreqs[k] * i / sampleRate);
        l += s * (k == 2 ? 0.7 : 1.0);
        r += s * (k == 0 ? 0.7 : 1.0);
      }
      left[i] = l * padAmp * env;
      right[i] = r * padAmp * env;
    }

    final period = sampleRate * 60.0 / bpm;
    final first = (firstBeatSeconds * sampleRate).round();
    final lastAllowed = frames - (0.15 * sampleRate).round();
    final beats = <int>[];
    for (var n = 0; ; n++) {
      final s = first + (n * period).round();
      if (s >= lastAllowed) break;
      beats.add(s);
      _addKick(left, right, s, sampleRate, rng);
      final hat = s + (period / 2).round();
      if (hat < lastAllowed) _addHat(left, right, hat, sampleRate, rng);
    }

    final pcm = Int16List(frames * channels);
    for (var i = 0; i < frames; i++) {
      if (channels == 1) {
        pcm[i] = _toInt16((left[i] + right[i]) / 2);
      } else {
        pcm[2 * i] = _toInt16(left[i]);
        pcm[2 * i + 1] = _toInt16(right[i]);
      }
    }
    return FixtureAudio._(
      sampleRate: sampleRate,
      channels: channels,
      pcm: pcm,
      beatSamples: beats,
      bpm: bpm,
    );
  }

  static int _toInt16(double v) => (v * 32767).round().clamp(-32768, 32767);

  static void _addKick(
    Float64List l,
    Float64List r,
    int start,
    int rate,
    math.Random rng,
  ) {
    final len = math.min((0.25 * rate).round(), l.length - start);
    var phase = 0.0;
    for (var i = 0; i < len; i++) {
      final t = i / rate;
      final f = 50 + 100 * math.exp(-t / 0.03);
      phase += 2 * math.pi * f / rate;
      final body = math.sin(phase) * math.exp(-t / 0.12) * 0.6;
      final click = i < 0.003 * rate
          ? (rng.nextDouble() * 2 - 1) * 0.35 * (1 - i / (0.003 * rate))
          : 0.0;
      // First sample is the attack: make it clearly non-zero.
      final v = i == 0 ? 0.5 : body + click;
      l[start + i] += v;
      r[start + i] += v;
    }
  }

  static void _addHat(
    Float64List l,
    Float64List r,
    int start,
    int rate,
    math.Random rng,
  ) {
    final len = math.min((0.06 * rate).round(), l.length - start);
    var prev = 0.0;
    for (var i = 0; i < len; i++) {
      final white = rng.nextDouble() * 2 - 1;
      final hp = white - prev; // crude high-pass
      prev = white;
      final v = hp * 0.1 * math.exp(-i / (0.025 * rate));
      l[start + i] += v * 1.0;
      r[start + i] += v * 0.7;
    }
  }
}

/// Mixes interleaved [pcm] down to mono doubles in −1..1, frames
/// [from, from + count).
Float64List monoMix(Int16List pcm, int channels, {int from = 0, int? count}) {
  final frames = pcm.length ~/ channels;
  final n = math.max(0, math.min(count ?? frames - from, frames - from));
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    var s = 0;
    for (var c = 0; c < channels; c++) {
      s += pcm[(from + i) * channels + c];
    }
    out[i] = s / (channels * 32768.0);
  }
  return out;
}
