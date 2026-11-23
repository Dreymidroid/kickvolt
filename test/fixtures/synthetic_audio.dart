import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kickvolt/core/audio_math/wav_header.dart';

/// Result of generating a synthetic WAV file for beat detection tests.
class SyntheticTrack {
  const SyntheticTrack({
    required this.wavPath,
    required this.sampleRate,
    required this.channels,
    required this.sampleCount,
    required this.clickSamples,
    required this.accentedClickSamples,
    this.dropSample,
  });

  final String wavPath;
  final int sampleRate;
  final int channels;
  final int sampleCount;

  /// Exact ground-truth attack start sample indices for every beat click.
  final List<int> clickSamples;

  /// Subset of [clickSamples] that were accented (+6 dB + extra low end).
  final Set<int> accentedClickSamples;

  /// Sample index where the drop starts, if generated.
  final int? dropSample;
}

/// Generates a synthetic click track WAV file per §7 of the M4 spec:
/// - 5–10 ms decaying burst (noise × exponential decay plus a short 1.5–3 kHz
///   tone) starting at exact sample indices.
/// - Clicks at [bpm] with a non-zero [startOffsetSeconds] (default 0.37 s),
///   [durationSeconds] long (default 45 s).
/// - When [noisy] is true: adds white noise at −20 dB relative to click peak
///   plus a 110 Hz sine pad at −12 dB.
/// - When [accentEvery4th] is true (starting at beat index [accentPhase]):
///   every 4th click is +6 dB (amplitude × 1.0 vs 0.5) with extra low end
///   (80 Hz sine burst).
/// - When [subdivisionEighthHiHats] is true: places quieter 8th-note hi-hats
///   (−12 dB high-frequency noise bursts) midway between main kicks, plus
///   low-end punch on main kicks.
Future<SyntheticTrack> writeSyntheticClickTrack({
  required Directory dir,
  String fileName = 'track.wav',
  required double bpm,
  int sampleRate = 44100,
  int channels = 1,
  double durationSeconds = 45.0,
  double startOffsetSeconds = 0.37,
  bool noisy = false,
  bool accentEvery4th = false,
  int accentPhase = 0,
  bool subdivisionEighthHiHats = false,
  int seed = 42,
}) async {
  final sampleCount = (durationSeconds * sampleRate).round();
  final mono = Float32List(sampleCount);
  final rng = math.Random(seed);

  final clickPeak = accentEvery4th ? 0.45 : 0.75;

  // Add background noise + 110 Hz pad if requested.
  if (noisy) {
    // -20 dB = 0.1 * clickPeak; -12 dB = 10^(-12/20) ≈ 0.2511886 * clickPeak
    final noiseAmp = clickPeak * 0.10;
    final padAmp = clickPeak * 0.25118864;
    final twoPi110 = 2 * math.pi * 110.0 / sampleRate;
    for (var i = 0; i < sampleCount; i++) {
      final white = (rng.nextDouble() * 2.0 - 1.0) * noiseAmp;
      final pad = math.sin(i * twoPi110) * padAmp;
      mono[i] = white + pad;
    }
  }

  final periodSamples = sampleRate * 60.0 / bpm;
  final startSample = (startOffsetSeconds * sampleRate).round();
  final clickSamples = <int>[];
  final accented = <int>{};

  // Keep clicks at least 50 ms away from the very end of the file.
  final maxClickSample = sampleCount - (0.05 * sampleRate).round();

  for (var idx = 0; ; idx++) {
    final s = startSample + (idx * periodSamples).round();
    if (s >= maxClickSample) break;
    clickSamples.add(s);

    final isAccent = accentEvery4th && (idx % 4 == accentPhase);
    if (isAccent) accented.add(s);

    final amp = isAccent ? (clickPeak * 2.0) : clickPeak;
    _addClickBurst(
      mono,
      startSample: s,
      sampleRate: sampleRate,
      amplitude: amp,
      extraLowEnd: isAccent || subdivisionEighthHiHats,
      rng: rng,
    );

    if (subdivisionEighthHiHats) {
      final hatSample = s + (periodSamples * 0.5).round();
      if (hatSample < maxClickSample) {
        // -12 dB relative to kick peak (0.2511886 * amp)
        _addHiHatBurst(
          mono,
          startSample: hatSample,
          sampleRate: sampleRate,
          amplitude: amp * 0.25118864,
          rng: rng,
        );
      }
    }
  }

  final wavPath = '${dir.path}${Platform.pathSeparator}$fileName';
  await _writeMonoAsWav(
    wavPath: wavPath,
    mono: mono,
    sampleRate: sampleRate,
    channels: channels,
  );

  return SyntheticTrack(
    wavPath: wavPath,
    sampleRate: sampleRate,
    channels: channels,
    sampleCount: sampleCount,
    clickSamples: clickSamples,
    accentedClickSamples: accented,
  );
}

/// Generates the §7 drops fixture:
/// 16 bars of quiet clicks, then 16 bars with a loud 50–80 Hz bass under the
/// clicks (32 bars total = 128 beats).
Future<SyntheticTrack> writeSyntheticDropTrack({
  required Directory dir,
  String fileName = 'drops.wav',
  double bpm = 120.0,
  int sampleRate = 44100,
  int channels = 1,
  double startOffsetSeconds = 0.37,
  int seed = 99,
}) async {
  const totalBars = 32;
  const beatsPerBar = 4;
  const totalBeats = totalBars * beatsPerBar; // 128 beats
  const dropBeatIndex = 16 * beatsPerBar; // beat 64 (start of bar 17)

  final periodSamples = sampleRate * 60.0 / bpm;
  final startSample = (startOffsetSeconds * sampleRate).round();
  final sampleCount = startSample + ((totalBeats + 2) * periodSamples).round();
  final mono = Float32List(sampleCount);
  final rng = math.Random(seed);

  final clickSamples = <int>[];
  final accented = <int>{};
  int? dropSample;

  for (var idx = 0; idx < totalBeats; idx++) {
    final s = startSample + (idx * periodSamples).round();
    clickSamples.add(s);
    final isDownbeat = idx % 4 == 0;
    if (isDownbeat) accented.add(s);
    if (idx == dropBeatIndex) dropSample = s;

    final inDrop = idx >= dropBeatIndex;
    final baseAmp = inDrop ? 0.55 : 0.25;
    final amp = isDownbeat ? baseAmp * 1.35 : baseAmp;

    _addClickBurst(
      mono,
      startSample: s,
      sampleRate: sampleRate,
      amplitude: amp,
      extraLowEnd: isDownbeat && inDrop,
      rng: rng,
    );
  }

  // Add loud 50-80 Hz bass (65 Hz sine + 55 Hz sine) under the second 16 bars.
  final dropStart = dropSample!;
  final dropEnd = math.min(
    sampleCount,
    startSample + (totalBeats * periodSamples).round(),
  );
  final twoPi65 = 2 * math.pi * 65.0 / sampleRate;
  final twoPi55 = 2 * math.pi * 55.0 / sampleRate;
  for (var i = dropStart; i < dropEnd; i++) {
    final t = i - dropStart;
    final bass = 0.35 * math.sin(t * twoPi65) + 0.20 * math.sin(t * twoPi55);
    mono[i] += bass;
  }

  final wavPath = '${dir.path}${Platform.pathSeparator}$fileName';
  await _writeMonoAsWav(
    wavPath: wavPath,
    mono: mono,
    sampleRate: sampleRate,
    channels: channels,
  );

  return SyntheticTrack(
    wavPath: wavPath,
    sampleRate: sampleRate,
    channels: channels,
    sampleCount: sampleCount,
    clickSamples: clickSamples,
    accentedClickSamples: accented,
    dropSample: dropSample,
  );
}

/// Generates 45 s of pure white noise (for §7 failure test).
Future<String> writeWhiteNoiseTrack({
  required Directory dir,
  String fileName = 'white_noise.wav',
  int sampleRate = 44100,
  int channels = 1,
  double durationSeconds = 45.0,
  int seed = 123,
}) async {
  final sampleCount = (durationSeconds * sampleRate).round();
  final mono = Float32List(sampleCount);
  final rng = math.Random(seed);
  for (var i = 0; i < sampleCount; i++) {
    mono[i] = (rng.nextDouble() * 2.0 - 1.0) * 0.3;
  }
  final wavPath = '${dir.path}${Platform.pathSeparator}$fileName';
  await _writeMonoAsWav(
    wavPath: wavPath,
    mono: mono,
    sampleRate: sampleRate,
    channels: channels,
  );
  return wavPath;
}

/// Generates 45 s of a steady sustained chord (A minor: 220, 261.63, 329.63,
/// 440 Hz) with no rhythmic pulses (for §7 failure test).
Future<String> writeSustainedChordTrack({
  required Directory dir,
  String fileName = 'sustained_chord.wav',
  int sampleRate = 44100,
  int channels = 1,
  double durationSeconds = 45.0,
}) async {
  final sampleCount = (durationSeconds * sampleRate).round();
  final mono = Float32List(sampleCount);
  const freqs = [220.0, 261.63, 329.63, 440.0];
  for (var i = 0; i < sampleCount; i++) {
    var sum = 0.0;
    for (final f in freqs) {
      sum += math.sin(2 * math.pi * f * i / sampleRate);
    }
    mono[i] = sum * (0.6 / freqs.length);
  }
  final wavPath = '${dir.path}${Platform.pathSeparator}$fileName';
  await _writeMonoAsWav(
    wavPath: wavPath,
    mono: mono,
    sampleRate: sampleRate,
    channels: channels,
  );
  return wavPath;
}

void _addClickBurst(
  Float32List mono, {
  required int startSample,
  required int sampleRate,
  required double amplitude,
  required bool extraLowEnd,
  required math.Random rng,
}) {
  // 8 ms burst for main click (5–10 ms spec)
  final burstLen = (0.008 * sampleRate).round();
  final end = math.min(mono.length, startSample + burstLen);
  final twoPi2k = 2 * math.pi * 2200.0 / sampleRate;
  final tau = 0.0022 * sampleRate; // exponential decay constant

  for (var i = startSample; i < end; i++) {
    final k = i - startSample;
    final env = math.exp(-k / tau);
    final noise = rng.nextDouble() * 2.0 - 1.0;
    final tone = math.sin(k * twoPi2k);
    mono[i] += amplitude * env * (0.55 * tone + 0.45 * noise);
  }

  if (extraLowEnd) {
    // 55 ms 75 Hz sub-kick thump starting at the exact same attack sample
    final lowLen = (0.055 * sampleRate).round();
    final lowEnd = math.min(mono.length, startSample + lowLen);
    final twoPi75 = 2 * math.pi * 75.0 / sampleRate;
    final lowTau = 0.018 * sampleRate;
    for (var i = startSample; i < lowEnd; i++) {
      final k = i - startSample;
      final env = math.exp(-k / lowTau);
      mono[i] += amplitude * 0.65 * env * math.sin(k * twoPi75);
    }
  }
}

void _addHiHatBurst(
  Float32List mono, {
  required int startSample,
  required int sampleRate,
  required double amplitude,
  required math.Random rng,
}) {
  final burstLen = (0.005 * sampleRate).round();
  final end = math.min(mono.length, startSample + burstLen);
  final twoPi6k = 2 * math.pi * 6000.0 / sampleRate;
  final tau = 0.0012 * sampleRate;
  for (var i = startSample; i < end; i++) {
    final k = i - startSample;
    final env = math.exp(-k / tau);
    final noise = rng.nextDouble() * 2.0 - 1.0;
    final tone = math.sin(k * twoPi6k);
    mono[i] += amplitude * env * (0.6 * tone + 0.4 * noise);
  }
}

Future<void> _writeMonoAsWav({
  required String wavPath,
  required Float32List mono,
  required int sampleRate,
  required int channels,
}) async {
  final frameCount = mono.length;
  final header = buildWavHeader(
    sampleRate: sampleRate,
    channels: channels,
    frameCount: frameCount,
  );
  final raf = await File(wavPath).open(mode: FileMode.write);
  try {
    await raf.writeFrom(header);
    const chunkFrames = 16384;
    final chunk = Int16List(chunkFrames * channels);
    final bytes = Uint8List.view(chunk.buffer);
    var offset = 0;
    while (offset < frameCount) {
      final count = math.min(chunkFrames, frameCount - offset);
      var outIdx = 0;
      for (var i = 0; i < count; i++) {
        final v = (mono[offset + i].clamp(-1.0, 1.0) * 32767.0).round().clamp(
          -32768,
          32767,
        );
        for (var c = 0; c < channels; c++) {
          chunk[outIdx++] = v;
        }
      }
      await raf.writeFrom(bytes, 0, count * channels * 2);
      offset += count;
    }
  } finally {
    await raf.close();
  }
}
