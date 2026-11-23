import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kickvolt/core/audio_math/wav_header.dart';

/// A music-like test song written to disk, with its quarter-note grid.
class SyntheticSong {
  const SyntheticSong(this.path, this.sampleRate, this.quarterNotes);

  final String path;
  final int sampleRate;

  /// Un-humanised quarter-note positions (sample frames).
  final List<int> quarterNotes;
}

enum SongStyle {
  /// Kick on 1 and 3, snare on 2 and 4, 8th-note hats, bass, chord pad.
  /// The most common pop/hip-hop groove, and the classic half-tempo trap
  /// (the kick alone repeats every two beats).
  groove,

  /// Plucked notes on every beat over a sustained pad; no drums.
  acoustic,
}

/// Renders [seconds] of [style] at [bpm], with every hit humanised by up to
/// ±6 ms, normalised to a 0.9 peak and then scaled by [gainDb], as 16-bit
/// stereo.
Future<SyntheticSong> writeSyntheticSong(
  Directory dir, {
  required SongStyle style,
  required double bpm,
  double gainDb = 0,
  int sampleRate = 44100,
  double seconds = 30,
  int seed = 3,
}) async {
  final sr = sampleRate;
  final rnd = math.Random(seed);
  final n = (seconds * sr).round();
  final out = Float64List(n);
  final beat = sr * 60 / bpm;
  final offset = (0.31 * sr).round();
  final grid = <int>[];
  double humanize() => (rnd.nextDouble() * 2 - 1) * 0.006 * sr;

  // Every note fades out over its last 5 ms; a hard cut would be a click
  // (a real transient) that the detector rightly treats as an onset.
  final fade = (0.005 * sr).round();
  void add(int at, int len, double Function(int i) f) {
    for (var i = 0; i < len && at + i < n; i++) {
      if (at + i < 0) continue;
      final left = len - i;
      final g = left < fade ? left / fade : 1.0;
      out[at + i] += f(i) * g;
    }
  }

  const chords = [
    [220.0, 277.2, 329.6],
    [196.0, 246.9, 293.7],
    [174.6, 220.0, 261.6],
    [196.0, 246.9, 311.1],
  ];
  final drums = style == SongStyle.groove;
  for (var i = 0; i < n; i++) {
    final bar = ((i - offset) / (4 * beat)).floor() % 4;
    var v = 0.0;
    for (final f in chords[bar < 0 ? 0 : bar]) {
      v += math.sin(2 * math.pi * f * i / sr);
    }
    out[i] += v * (drums ? 0.035 : 0.06);
  }

  for (var k = 0; offset + k * beat < n; k++) {
    final t = (offset + k * beat).round();
    grid.add(t);
    final pos = k % 4;
    if (drums) {
      if (pos == 0 || pos == 2) {
        var ph = 0.0; // kick: 120 -> 50 Hz sweep
        add((t + humanize()).round(), (0.18 * sr).round(), (i) {
          ph += 2 * math.pi * (50 + 70 * math.exp(-i / (0.03 * sr))) / sr;
          return 0.9 * math.sin(ph) * math.exp(-i / (0.06 * sr));
        });
      } else {
        add((t + humanize()).round(), (0.15 * sr).round(), (i) {
          final e = math.exp(-i / (0.035 * sr)); // snare: noise + body
          return 0.5 * e * (rnd.nextDouble() * 2 - 1) +
              0.3 * e * math.sin(2 * math.pi * 190 * i / sr);
        });
      }
      for (final h in [t, (t + beat / 2).round()]) {
        var prev = 0.0; // closed hat: high-passed noise
        add((h + humanize()).round(), (0.03 * sr).round(), (i) {
          final x = rnd.nextDouble() * 2 - 1;
          final hp = x - prev;
          prev = x;
          return 0.12 * hp * math.exp(-i / (0.008 * sr));
        });
      }
      final f = const [55.0, 55.0, 65.4, 49.0][(k ~/ 4) % 4];
      add(t, beat.round(), (i) {
        final a = math.min(1.0, i / (0.02 * sr));
        return 0.25 *
            a *
            math.sin(2 * math.pi * f * i / sr) *
            math.exp(-i / (0.4 * sr));
      });
    } else {
      final f = const [261.6, 329.6, 392.0, 329.6][pos];
      add((t + humanize()).round(), (0.5 * sr).round(), (i) {
        final a = math.min(1.0, i / (0.005 * sr));
        final e = math.exp(-i / (0.25 * sr));
        return 0.4 *
            a *
            e *
            (math.sin(2 * math.pi * f * i / sr) +
                0.4 * math.sin(4 * math.pi * f * i / sr));
      });
    }
  }

  var peak = 1e-9;
  for (final v in out) {
    peak = math.max(peak, v.abs());
  }
  final g = 0.9 / peak * math.pow(10, gainDb / 20);
  final pcm = Int16List(n * 2);
  for (var i = 0; i < n; i++) {
    final s = (out[i] * g * 32767).round().clamp(-32768, 32767);
    pcm[2 * i] = s;
    pcm[2 * i + 1] = s;
  }
  final path =
      '${dir.path}/${style.name}_${bpm.round()}_${gainDb.round()}_$seed.wav';
  await File(path).writeAsBytes([
    ...buildWavHeader(sampleRate: sr, channels: 2, frameCount: n),
    ...pcm.buffer.asUint8List(),
  ]);
  return SyntheticSong(path, sr, grid);
}
