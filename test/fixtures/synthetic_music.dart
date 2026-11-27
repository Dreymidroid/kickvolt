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

/// Renders a 174 BPM drum-and-bass-like groove (§8 `tempo_choice_test.dart`):
/// kick on beat 1 (and step 6 = beat 2.5), snare on beats 2 and 4 of the 174
/// quarter-note grid, fast 8th-note hats, every hit humanised by nothing or
/// small jitter, every note faded out over its last 5 ms.
///
/// Returns [SyntheticSong] whose [quarterNotes] are the 174-BPM beat samples.
Future<SyntheticSong> writeSyntheticDnbSong(
  Directory dir, {
  double bpm = 174.0,
  int sampleRate = 44100,
  double seconds = 30.0,
  int seed = 17,
}) async {
  final sr = sampleRate;
  final rnd = math.Random(seed);
  final n = (seconds * sr).round();
  final out = Float64List(n);
  final beat = sr * 60.0 / bpm;
  final offset = (0.31 * sr).round();
  final grid = <int>[];

  final fade = (0.005 * sr).round();
  void add(int at, int len, double Function(int i) f) {
    for (var i = 0; i < len && at + i < n; i++) {
      if (at + i < 0) continue;
      final left = len - i;
      final g = left < fade ? left / fade : 1.0;
      out[at + i] += f(i) * g;
    }
  }

  final maxSample = n - (0.08 * sr).round();
  for (var k = 0; ; k++) {
    final t = (offset + k * beat).round();
    if (t >= maxSample) break;
    grid.add(t);
    final pos = k % 4;

    if (pos == 0) {
      // Strong kick on beat 1 of the bar.
      var ph = 0.0;
      add(t, (0.14 * sr).round(), (i) {
        ph += 2 * math.pi * (52 + 85 * math.exp(-i / (0.02 * sr))) / sr;
        return 0.95 * math.sin(ph) * math.exp(-i / (0.045 * sr));
      });
    } else if (pos == 1 || pos == 3) {
      // Snare on beats 2 and 4 of the 174 grid.
      add(t, (0.12 * sr).round(), (i) {
        final e = math.exp(-i / (0.028 * sr));
        return 0.65 * e * (rnd.nextDouble() * 2 - 1) +
            0.40 * e * math.sin(2 * math.pi * 210 * i / sr);
      });
    } else {
      // Beat 3: ghost rim/hat pulse on the quarter grid + offbeat DnB kick at 2.5.
      add(t, (0.06 * sr).round(), (i) {
        final e = math.exp(-i / (0.015 * sr));
        return 0.45 * e * math.sin(2 * math.pi * 320 * i / sr) +
            0.35 * e * (rnd.nextDouble() * 2 - 1);
      });
    }

    // Fast hats on every quarter and eighth of the 174 grid.
    for (final h in [t, (t + beat * 0.5).round()]) {
      if (h >= maxSample) continue;
      var prev = 0.0;
      add(h, (0.025 * sr).round(), (i) {
        final x = rnd.nextDouble() * 2 - 1;
        final hp = x - prev;
        prev = x;
        return 0.18 * hp * math.exp(-i / (0.006 * sr));
      });
    }
  }

  return _writeNormalisedStereoWav(
    dir: dir,
    fileName: 'dnb_${bpm.round()}_${sr}_$seed.wav',
    out: out,
    sampleRate: sr,
    grid: grid,
  );
}

/// Renders a half-time hip-hop groove where both the 70 BPM half-time pulse
/// and the 140 BPM double-time pulse have clear on-grid transients (§8).
///
/// Returns `quarterNotes` at the 140 BPM grid (every even index is the 70 BPM
/// half-time grid).
Future<SyntheticSong> writeSyntheticHalfTimeHipHopSong(
  Directory dir, {
  double fastBpm = 140.0,
  int sampleRate = 44100,
  double seconds = 30.0,
  int seed = 23,
}) async {
  final sr = sampleRate;
  final rnd = math.Random(seed);
  final n = (seconds * sr).round();
  final out = Float64List(n);
  final fastBeat = sr * 60.0 / fastBpm; // 140 BPM period
  final offset = (0.35 * sr).round();
  final grid140 = <int>[];

  final fade = (0.005 * sr).round();
  void add(int at, int len, double Function(int i) f) {
    for (var i = 0; i < len && at + i < n; i++) {
      if (at + i < 0) continue;
      final left = len - i;
      final g = left < fade ? left / fade : 1.0;
      out[at + i] += f(i) * g;
    }
  }

  final maxSample = n - (0.08 * sr).round();
  for (var k = 0; ; k++) {
    final t = (offset + k * fastBeat).round();
    if (t >= maxSample) break;
    grid140.add(t);
    final pos = k % 4; // 0,1,2,3 on 140 BPM grid -> 0 and 2 are 70 BPM beats

    if (pos == 0) {
      // Heavy 808 kick on beat 1 (70 BPM downbeat).
      var ph = 0.0;
      add(t, (0.18 * sr).round(), (i) {
        ph += 2 * math.pi * (48 + 80 * math.exp(-i / (0.025 * sr))) / sr;
        return 0.95 * math.sin(ph) * math.exp(-i / (0.06 * sr));
      });
    } else if (pos == 2) {
      // Punchy kick + clap/snare on beat 3 of 140 (= beat 2 of 70 BPM half-time).
      var ph = 0.0;
      add(t, (0.16 * sr).round(), (i) {
        ph += 2 * math.pi * (50 + 75 * math.exp(-i / (0.022 * sr))) / sr;
        final kick = 0.75 * math.sin(ph) * math.exp(-i / (0.05 * sr));
        final e = math.exp(-i / (0.03 * sr));
        final snare =
            0.70 * e * (rnd.nextDouble() * 2 - 1) +
            0.35 * e * math.sin(2 * math.pi * 200 * i / sr);
        return kick + snare;
      });
    } else {
      // Lighter rim/hat subdivision on beats 2 and 4 of 140 BPM (off-beats of
      // 70 BPM) so 70 BPM tracking locks onto the 0 & 2 main beats while 140 BPM
      // tracking locks onto every 140-BPM beat within ±10 ms.
      add(t, (0.04 * sr).round(), (i) {
        final e = math.exp(-i / (0.010 * sr));
        return 0.28 * e * math.sin(2 * math.pi * 900 * i / sr) +
            0.22 * e * (rnd.nextDouble() * 2 - 1);
      });
    }

    // Closed hat on every 140-BPM beat.
    var prev = 0.0;
    add(t, (0.025 * sr).round(), (i) {
      final x = rnd.nextDouble() * 2 - 1;
      final hp = x - prev;
      prev = x;
      return 0.16 * hp * math.exp(-i / (0.006 * sr));
    });
  }

  return _writeNormalisedStereoWav(
    dir: dir,
    fileName: 'halftime_${fastBpm.round()}_${sr}_$seed.wav',
    out: out,
    sampleRate: sr,
    grid: grid140,
  );
}

/// Renders a song with a custom variable-tempo beat sequence specified by
/// instantaneous [bpmAtTimeSeconds] (§8 `varying_tempo_test.dart`).
///
/// Places kick/snare/hat transients on each beat's exact sample index so
/// ground truth is known to the single sample, with every note faded out.
Future<SyntheticSong> writeSyntheticVaryingTempoSong(
  Directory dir, {
  required String name,
  required double Function(double timeSec) bpmAtTimeSeconds,
  int sampleRate = 44100,
  double seconds = 60.0,
  double startOffsetSeconds = 0.37,
  int seed = 31,
}) async {
  final sr = sampleRate;
  final rnd = math.Random(seed);
  final n = (seconds * sr).round();
  final out = Float64List(n);

  final fade = (0.005 * sr).round();
  void add(int at, int len, double Function(int i) f) {
    for (var i = 0; i < len && at + i < n; i++) {
      if (at + i < 0) continue;
      final left = len - i;
      final g = left < fade ? left / fade : 1.0;
      out[at + i] += f(i) * g;
    }
  }

  final grid = <int>[];
  final maxSample = n - (0.08 * sr).round();
  var currentSampleDouble = startOffsetSeconds * sr;
  var k = 0;

  while (currentSampleDouble < maxSample) {
    final t = currentSampleDouble.round();
    grid.add(t);

    final pos = k % 4;
    if (pos == 0 || pos == 2) {
      // Kick + crisp transient click at t.
      var ph = 0.0;
      add(t, (0.10 * sr).round(), (i) {
        ph += 2 * math.pi * (55 + 90 * math.exp(-i / (0.015 * sr))) / sr;
        final click =
            0.45 *
            math.exp(-i / (0.002 * sr)) *
            math.sin(2 * math.pi * 2200 * i / sr);
        return 0.85 * math.sin(ph) * math.exp(-i / (0.035 * sr)) + click;
      });
    } else {
      // Snare + crisp transient click at t.
      add(t, (0.09 * sr).round(), (i) {
        final e = math.exp(-i / (0.022 * sr));
        final click =
            0.40 *
            math.exp(-i / (0.002 * sr)) *
            math.sin(2 * math.pi * 2400 * i / sr);
        return 0.55 * e * (rnd.nextDouble() * 2 - 1) +
            0.35 * e * math.sin(2 * math.pi * 200 * i / sr) +
            click;
      });
    }

    final tSec = currentSampleDouble / sr;
    final bpmHere = bpmAtTimeSeconds(tSec);
    // Integrate over the beat using midpoint rule for smooth ramps/drifts.
    final dt0 = 60.0 / bpmHere;
    final bpmMid = bpmAtTimeSeconds(tSec + 0.5 * dt0);
    final periodSamples = sr * 60.0 / bpmMid;
    currentSampleDouble += periodSamples;
    k++;
  }

  return _writeNormalisedStereoWav(
    dir: dir,
    fileName: 'varying_${name}_$sr.wav',
    out: out,
    sampleRate: sr,
    grid: grid,
  );
}

/// Renders a shuffle/swing groove at [bpm] where off-beat eighth notes sit at
/// [swingRatio] (`0.5` = straight, `0.62..0.67` = swung) of each beat period
/// (§8 `swing_test.dart`).
Future<SyntheticSong> writeSyntheticSwingSong(
  Directory dir, {
  required double bpm,
  required double swingRatio,
  int sampleRate = 44100,
  double seconds = 35.0,
  double startOffsetSeconds = 0.35,
  int seed = 53,
}) async {
  final sr = sampleRate;
  final rnd = math.Random(seed);
  final n = (seconds * sr).round();
  final out = Float64List(n);
  final beat = sr * 60.0 / bpm;
  final offset = (startOffsetSeconds * sr).round();
  final grid = <int>[];

  final fade = (0.005 * sr).round();
  void add(int at, int len, double Function(int i) f) {
    for (var i = 0; i < len && at + i < n; i++) {
      if (at + i < 0) continue;
      final left = len - i;
      final g = left < fade ? left / fade : 1.0;
      out[at + i] += f(i) * g;
    }
  }

  final maxSample = n - (0.08 * sr).round();
  for (var k = 0; ; k++) {
    final t = (offset + k * beat).round();
    if (t >= maxSample) break;
    grid.add(t);
    final pos = k % 4;

    if (pos == 0 || pos == 2) {
      // Kick with clear attack on beats 1 and 3.
      var ph = 0.0;
      add(t, (0.14 * sr).round(), (i) {
        ph += 2 * math.pi * (55 + 80 * math.exp(-i / (0.02 * sr))) / sr;
        final click =
            0.35 *
            math.exp(-i / (0.002 * sr)) *
            math.sin(2 * math.pi * 2000 * i / sr);
        return 0.85 * math.sin(ph) * math.exp(-i / (0.045 * sr)) + click;
      });
    } else {
      // Snare on beats 2 and 4.
      add(t, (0.12 * sr).round(), (i) {
        final e = math.exp(-i / (0.028 * sr));
        return 0.60 * e * (rnd.nextDouble() * 2 - 1) +
            0.35 * e * math.sin(2 * math.pi * 195 * i / sr);
      });
    }

    // On-beat ride/hat.
    var prev0 = 0.0;
    add(t, (0.025 * sr).round(), (i) {
      final x = rnd.nextDouble() * 2 - 1;
      final hp = x - prev0;
      prev0 = x;
      return 0.20 * hp * math.exp(-i / (0.006 * sr));
    });

    // Off-beat swung hat/shuffle note at t + swingRatio * beat, except on the
    // final beat of the track so the song ends cleanly on the downbeat.
    final offBeatSample = (offset + (k + swingRatio) * beat).round();
    if (offBeatSample + (beat * 0.5).round() < maxSample) {
      var prev1 = 0.0;
      add(offBeatSample, (0.035 * sr).round(), (i) {
        final x = rnd.nextDouble() * 2 - 1;
        final hp = x - prev1;
        prev1 = x;
        final tone = math.sin(2 * math.pi * 3500 * i / sr);
        return (0.28 * hp + 0.14 * tone) * math.exp(-i / (0.008 * sr));
      });
    }
  }

  final ratioTag = (swingRatio * 100).round();
  return _writeNormalisedStereoWav(
    dir: dir,
    fileName: 'swing_${bpm.round()}_r${ratioTag}_$sr.wav',
    out: out,
    sampleRate: sr,
    grid: grid,
  );
}

Future<SyntheticSong> _writeNormalisedStereoWav({
  required Directory dir,
  required String fileName,
  required Float64List out,
  required int sampleRate,
  required List<int> grid,
}) async {
  final n = out.length;
  var peak = 1e-9;
  for (final v in out) {
    peak = math.max(peak, v.abs());
  }
  final g = 0.9 / peak;
  final pcm = Int16List(n * 2);
  for (var i = 0; i < n; i++) {
    final s = (out[i] * g * 32767).round().clamp(-32768, 32767);
    pcm[2 * i] = s;
    pcm[2 * i + 1] = s;
  }
  final path = '${dir.path}/$fileName';
  await File(path).writeAsBytes([
    ...buildWavHeader(sampleRate: sampleRate, channels: 2, frameCount: n),
    ...pcm.buffer.asUint8List(),
  ]);
  return SyntheticSong(path, sampleRate, grid);
}
