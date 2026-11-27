import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/demo_project.dart';

/// Independent reference: sorted, unique, clamped visible beats.
List<int> _normalize(List<int> beats, int frameCount) {
  if (frameCount <= 0) return const [];
  final s = [for (final b in beats) b.clamp(0, frameCount - 1)]..sort();
  final out = <int>[];
  for (final b in s) {
    if (out.isEmpty || out.last != b) out.add(b);
  }
  return out;
}

void main() {
  group('guideVideoTotalFrames (exact integer ceil)', () {
    final cases = <({int rate, int frames, int expected})>[
      // Whole seconds.
      (rate: 44100, frames: 44100, expected: 30),
      (rate: 48000, frames: 96000, expected: 60),
      (rate: 22050, frames: 22050, expected: 30),
      // One sample over a whole second -> one more frame.
      (rate: 44100, frames: 44101, expected: 31),
      (rate: 48000, frames: 96001, expected: 61),
      (rate: 22050, frames: 22051, expected: 31),
      // Exactly one video frame of samples, and one sample over.
      (rate: 44100, frames: 1470, expected: 1),
      (rate: 44100, frames: 1471, expected: 2),
      (rate: 48000, frames: 1600, expected: 1),
      (rate: 48000, frames: 1601, expected: 2),
      (rate: 22050, frames: 735, expected: 1),
      (rate: 22050, frames: 736, expected: 2),
      // Exact multiples of a frame.
      (rate: 44100, frames: 1470 * 7, expected: 7),
      (rate: 48000, frames: 1600 * 1234, expected: 1234),
      (rate: 22050, frames: 735 * 99, expected: 99),
      // Odd lengths.
      (rate: 44100, frames: 44100 * 3 + 17, expected: 91),
      (rate: 48000, frames: 48000 * 168 + 1599, expected: 168 * 30 + 1),
      (rate: 22050, frames: 22050 * 2 + 734, expected: 61),
      (rate: 44100, frames: 1, expected: 1),
      (rate: 48000, frames: 0, expected: 0),
      // A rate whose frame is not a whole number of samples (1066.67).
      (rate: 32000, frames: 32000, expected: 30),
      (rate: 32000, frames: 1066, expected: 1),
      (rate: 32000, frames: 1067, expected: 2),
    ];
    for (final c in cases) {
      test('${c.frames} frames @ ${c.rate} Hz -> ${c.expected}', () {
        expect(
          guideVideoTotalFrames(frameCount: c.frames, sampleRate: c.rate),
          c.expected,
        );
        // Video covers the audio and is less than one frame longer.
        final total = c.expected;
        expect(total * c.rate >= c.frames * 30, isTrue);
        if (total > 0) expect((total - 1) * c.rate < c.frames * 30, isTrue);
      });
    }

    test('rejects a non-positive sample rate', () {
      expect(
        () => guideVideoTotalFrames(frameCount: 10, sampleRate: 0),
        throwsArgumentError,
      );
    });
  });

  group('beat -> frame at boundaries', () {
    for (final rate in [
      8000,
      11025,
      22050,
      32000,
      44100,
      48000,
      88200,
      96000,
    ]) {
      test('$rate Hz: last sample of frame k -> k, first of k+1 -> k+1', () {
        for (final k in [0, 1, 2, 29, 30, 31, 299, 1799, 5399]) {
          // First sample of frame k+1 = ceil((k+1) * rate / 30).
          final firstOfNext = ((k + 1) * rate + 29) ~/ 30;
          expect(
            guideVideoFrameForSample(firstOfNext - 1, sampleRate: rate),
            k,
            reason: 'last sample of frame $k',
          );
          expect(
            guideVideoFrameForSample(firstOfNext, sampleRate: rate),
            k + 1,
            reason: 'first sample of frame ${k + 1}',
          );
        }
      });
    }

    test('44.1 kHz: samples 1469 / 1470 straddle frames 0 / 1', () {
      final plan = planGuideVideo(
        sampleRate: 44100,
        frameCount: 44100,
        visibleBeatSamples: const [1469, 1470 * 2 - 1, 1470 * 2],
      );
      expect(plan.flashFrames, [0, 1, 2]);
      expect(plan.beatNumbers, [1, 2, 3]);
    });
  });

  group('planGuideVideo', () {
    test('first and last sample beats land on the first and last frame', () {
      for (final rate in [22050, 44100, 48000]) {
        final frameCount = rate * 2 + 123;
        final plan = planGuideVideo(
          sampleRate: rate,
          frameCount: frameCount,
          visibleBeatSamples: [0, frameCount - 1],
        );
        expect(plan.totalFrames, 61);
        expect(plan.flashFrames, [0, plan.totalFrames - 1]);
        expect(plan.beatNumbers, [1, 2]);
      }
    });

    test('beats beyond the end and below zero are clamped', () {
      final plan = planGuideVideo(
        sampleRate: 48000,
        frameCount: 48000,
        visibleBeatSamples: const [-50, 24000, 999999],
      );
      expect(plan.flashFrames, [0, 15, 29]);
      expect(plan.beatNumbers, [1, 2, 3]);
      expect(plan.beatCount, 3);
    });

    test('two beats in one frame -> one flash with the later number', () {
      final plan = planGuideVideo(
        sampleRate: 44100,
        frameCount: 44100 * 2,
        // 0 and 100 share frame 0; 44100 is frame 30.
        visibleBeatSamples: const [44100, 100, 0],
      );
      expect(plan.flashFrames, [0, 30]);
      expect(plan.beatNumbers, [2, 3]);
      expect(plan.beatCount, 3);
      expect(plan.flashCount, 2);
    });

    test('duplicate samples count once (sorted, unique)', () {
      final plan = planGuideVideo(
        sampleRate: 44100,
        frameCount: 44100,
        visibleBeatSamples: const [22050, 22050, 0],
      );
      expect(plan.flashFrames, [0, 15]);
      expect(plan.beatNumbers, [1, 2]);
      expect(plan.beatCount, 2);
    });

    test('numbers are 1-based and parallel to frames', () {
      final beats = [for (var i = 0; i < 20; i++) 1000 + i * 22050];
      final plan = planGuideVideo(
        sampleRate: 44100,
        frameCount: 44100 * 11,
        visibleBeatSamples: beats,
      );
      expect(plan.flashFrames.length, plan.beatNumbers.length);
      expect(plan.beatNumbers, [for (var i = 1; i <= 20; i++) i]);
      for (var i = 0; i < 20; i++) {
        expect(plan.flashFrames[i], (beats[i] * 30) ~/ 44100);
      }
    });

    test('empty beat list -> plain black video of the right length', () {
      final plan = planGuideVideo(
        sampleRate: 48000,
        frameCount: 48000 * 5 + 1,
        visibleBeatSamples: const [],
      );
      expect(plan.totalFrames, 151);
      expect(plan.flashFrames, isEmpty);
      expect(plan.beatNumbers, isEmpty);
      expect(plan.fps, 30);
      expect(plan.width, 1080);
      expect(plan.height, 1920);
    });

    test('durationUs and frame tolerance', () {
      final plan = planGuideVideo(
        sampleRate: 44100,
        frameCount: 44100,
        visibleBeatSamples: const [],
      );
      expect(plan.durationUs, 1000000);
      expect(plan.frameDurationUs, 33334);
    });

    test('property: every flash frame span contains its beat (seeded)', () {
      final rng = math.Random(20261127);
      const rates = [8000, 11025, 16000, 22050, 32000, 44100, 48000, 96000];
      var cases = 0;
      var violations = 0;
      for (var iter = 0; iter < 400; iter++) {
        final rate = rates[rng.nextInt(rates.length)];
        final frameCount = 1 + rng.nextInt(rate * 20);
        final n = rng.nextInt(120);
        final beats = <int>[
          for (var i = 0; i < n; i++)
            // Some out-of-range values to exercise clamping.
            rng.nextInt(frameCount + 200) - 100,
          // Near-duplicates (double markers) now and then.
          if (n > 0 && rng.nextBool()) rng.nextInt(frameCount),
        ];
        final plan = planGuideVideo(
          sampleRate: rate,
          frameCount: frameCount,
          visibleBeatSamples: beats,
        );
        final normalized = _normalize(beats, frameCount);
        expect(plan.beatCount, normalized.length);
        expect(
          plan.totalFrames,
          (frameCount * 30 + rate - 1) ~/ rate,
          reason: 'totalFrames',
        );

        var prev = -1;
        for (var i = 0; i < plan.flashCount; i++) {
          cases++;
          final k = plan.flashFrames[i];
          final s = normalized[plan.beatNumbers[i] - 1];
          // Frame k spans [k / 30, (k + 1) / 30) s; beat at s / rate s.
          final inSpan = k * rate <= s * 30 && s * 30 < (k + 1) * rate;
          if (!inSpan) violations++;
          expect(k > prev, isTrue, reason: 'ascending, unique');
          expect(k < plan.totalFrames, isTrue);
          prev = k;
        }
        // Every beat is accounted for by a flash on its frame.
        for (var j = 0; j < normalized.length; j++) {
          final k = (normalized[j] * 30) ~/ rate;
          expect(plan.flashFrames.contains(k), isTrue);
        }
        // Skipped numbers only where beats share a frame with the next one.
        final shown = plan.beatNumbers.toSet();
        for (var j = 0; j < normalized.length; j++) {
          if (!shown.contains(j + 1)) {
            expect(j + 1 < normalized.length, isTrue);
            expect(
              (normalized[j] * 30) ~/ rate,
              (normalized[j + 1] * 30) ~/ rate,
            );
          }
        }
      }
      expect(cases, greaterThan(1000));
      expect(violations, 0);
    });
  });

  group('estimateGuideVideoBytes', () {
    test('bitrate x duration + 10%', () {
      // 10 s at 2.192 Mbps = 2,740,000 bytes; +10% = 3,014,000.
      expect(
        estimateGuideVideoBytes(frameCount: 441000, sampleRate: 44100),
        3014000,
      );
      expect(estimateGuideVideoBytes(frameCount: 0, sampleRate: 44100), 0);
    });
  });

  group('planBeatPack with video', () {
    Project project({BeatFilter filter = BeatFilter.every}) {
      final base = createDemoProject(
        id: 'pv',
        sampleRate: 44100,
        includeBeats: false,
      );
      return base.copyWith(
        title: 'Midnight Run',
        sampleCount: 44100 * 4,
        detection: base.detection.copyWith(filter: filter),
        beats: const [
          Beat(sample: 0, type: BeatType.downbeat),
          Beat(sample: 22050, type: BeatType.beat),
          Beat(sample: 44100, type: BeatType.strong),
          Beat(sample: 66150, type: BeatType.beat),
        ],
      );
    }

    test('adds <Title>_guide.mp4 right after the guide track', () {
      final plan = planBeatPack(
        project(),
        const ExportOptions(includeVideo: true, includePreview: true),
      );
      expect(
        [for (final f in plan.files) f.fileName],
        [
          'MidnightRun_beats.wav',
          'MidnightRun_guide.mp4',
          'MidnightRun_song.wav',
          'MidnightRun_preview.wav',
        ],
      );
      final video = plan.guideVideo!;
      expect(video.totalFrames, 120);
      expect(video.flashFrames, [0, 15, 30, 45]);
      expect(plan.files[1].kind, ExportFileKind.video);
      expect(plan.files[1].clickCount, 4);
    });

    test('M4A pack still names the video .mp4', () {
      final plan = planBeatPack(
        project(),
        const ExportOptions(includeVideo: true, format: AudioFormat.m4a),
      );
      expect(plan.files[1].fileName, 'MidnightRun_guide.mp4');
      expect(plan.files[0].fileName, 'MidnightRun_beats.m4a');
    });

    test('no video unless asked', () {
      final plan = planBeatPack(project(), const ExportOptions());
      expect(plan.guideVideo, isNull);
      expect(plan.files.any((f) => f.kind == ExportFileKind.video), isFalse);
    });

    test('filter respected: hidden beats do not flash', () {
      final plan = planBeatPack(
        project(filter: BeatFilter.strong),
        const ExportOptions(includeVideo: true),
      );
      // Strong = downbeat at 0 and strong at 44100.
      expect(plan.guideVideo!.flashFrames, [0, 30]);
      expect(plan.guideVideo!.beatNumbers, [1, 2]);
    });

    test('disk estimate adds the video estimate', () {
      final without = planBeatPack(project(), const ExportOptions());
      final withVideo = planBeatPack(
        project(),
        const ExportOptions(includeVideo: true),
      );
      expect(
        withVideo.estimatedDiskBytes - without.estimatedDiskBytes,
        estimateGuideVideoBytes(frameCount: 44100 * 4, sampleRate: 44100),
      );
    });
  });
}
