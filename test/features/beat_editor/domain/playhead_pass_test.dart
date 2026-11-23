import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/domain/playhead_pass.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/demo_project.dart';

void main() {
  const sampleRate = 44100;

  late Project project;

  setUp(() {
    project = createDemoProject(sampleRate: sampleRate, includeBeats: false)
        .copyWith(
          sampleCount: sampleRate * 10,
          beats: const [
            Beat(sample: 10000, type: BeatType.downbeat),
            Beat(sample: 12000, type: BeatType.beat),
            Beat(sample: 14000, type: BeatType.strong),
            Beat(sample: 16000, type: BeatType.drop),
          ],
        );
  });

  group('detectPassedBeatHaptics', () {
    test(
      'forward play fires once per crossed visible beat by type when clicks on',
      () {
        // Cross downbeat (10000) -> light
        expect(
          detectPassedBeatHaptics(
            project: project,
            previousSample: 9500,
            currentSample: 10500,
            playing: true,
            clicksEnabled: true,
          ),
          [BeatPassHaptic.light],
        );

        // Cross regular beat (12000) -> nothing
        expect(
          detectPassedBeatHaptics(
            project: project,
            previousSample: 11500,
            currentSample: 12500,
            playing: true,
            clicksEnabled: true,
          ),
          isEmpty,
        );

        // Cross strong (14000) and drop (16000) in one short step (< 250 ms)
        expect(
          detectPassedBeatHaptics(
            project: project,
            previousSample: 13500,
            currentSample: 16500,
            playing: true,
            clicksEnabled: true,
          ),
          [BeatPassHaptic.light, BeatPassHaptic.heavy],
        );
      },
    );

    test('clicks off suppresses lightImpact for strong/downbeat but drops still fire', () {
      expect(
        detectPassedBeatHaptics(
          project: project,
          previousSample: 9500,
          currentSample: 16500,
          playing: true,
          clicksEnabled: false,
        ),
        [BeatPassHaptic.heavy],
      );
    });

    test('jump > 250 ms counts as a seek and fires nothing', () {
      final jump = project.msToSamples(260);
      expect(
        detectPassedBeatHaptics(
          project: project,
          previousSample: 9500,
          currentSample: 9500 + jump,
          playing: true,
          clicksEnabled: true,
        ),
        isEmpty,
      );
    });

    test('backwards movement or paused fires nothing', () {
      expect(
        detectPassedBeatHaptics(
          project: project,
          previousSample: 17000,
          currentSample: 9000,
          playing: true,
          clicksEnabled: true,
        ),
        isEmpty,
      );
      expect(
        detectPassedBeatHaptics(
          project: project,
          previousSample: 9500,
          currentSample: 16500,
          playing: false,
          clicksEnabled: true,
        ),
        isEmpty,
      );
    });

    test('hidden beats under filter do not fire', () {
      final dropsOnly = project.copyWith(
        detection: project.detection.copyWith(filter: BeatFilter.drops),
      );
      expect(
        detectPassedBeatHaptics(
          project: dropsOnly,
          previousSample: 9500,
          currentSample: 15000,
          playing: true,
          clicksEnabled: true,
        ),
        isEmpty,
      );
      expect(
        detectPassedBeatHaptics(
          project: dropsOnly,
          previousSample: 15000,
          currentSample: 16500,
          playing: true,
          clicksEnabled: true,
        ),
        [BeatPassHaptic.heavy],
      );
    });
  });
}
