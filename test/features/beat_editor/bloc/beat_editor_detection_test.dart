import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/demo_project.dart';
import '../../playback/fake_audio_playback.dart';

class MockBeatDetectionRepository extends Mock
    implements BeatDetectionRepository {}

class FakeBeatAnalysis extends Fake implements BeatAnalysis {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDemoProjectRepository repo;
  late MockBeatDetectionRepository detectionRepo;

  final analysis = BeatAnalysis(
    sampleRate: 44100,
    sampleCount: 44100 * 60,
    hopSize: 512,
    bpm: 120.0,
    confidence: 3.5,
    beatPhaseSample: 500,
    candidates: const [
      CandidateBeat(index: 0, sample: 500, strength: 0.9, lowEnergy: 5.0),
      CandidateBeat(index: 1, sample: 22550, strength: 0.4, lowEnergy: 1.0),
      CandidateBeat(index: 2, sample: 44600, strength: 0.7, lowEnergy: 2.0),
      CandidateBeat(index: 3, sample: 66650, strength: 0.3, lowEnergy: 1.0),
    ],
    frameLowEnergy: Float32List(10),
    frameOverallEnergy: Float32List(10),
  );

  const detectedBeats = <Beat>[
    Beat(sample: 500, type: BeatType.downbeat),
    Beat(sample: 22550, type: BeatType.beat),
    Beat(sample: 44600, type: BeatType.strong),
    Beat(sample: 66650, type: BeatType.drop),
  ];

  final detectedSections = <Section>[
    Section(
      startSample: 0,
      endSample: 44100 * 60,
      name: SectionPreset.verse.name,
      colorArgb: SectionPreset.verse.colorArgb,
    ),
  ];

  setUpAll(() {
    registerFallbackValue(FakeBeatAnalysis());
    registerFallbackValue(AnalysisCancelToken());
  });

  setUp(() {
    repo = FakeDemoProjectRepository();
    detectionRepo = MockBeatDetectionRepository();
    when(() => detectionRepo.getCachedAnalysis(any()))
        .thenAnswer((_) async => analysis);
    when(() => detectionRepo.classify(any(), any())).thenAnswer((inv) {
      final sens = inv.positionalArguments[1] as double;
      return DetectionResult(
        succeeded: true,
        beats: sens >= 0.5 ? detectedBeats : detectedBeats.sublist(0, 3),
        bpm: 120.0,
        beatPhaseSample: 500,
        sections: detectedSections,
      );
    });
  });

  BeatEditorReady ready(BeatEditorCubit c) => c.state as BeatEditorReady;

  group('Auto-detect sheet preview and commit', () {
    test('preview updates previewBeats without saving or touching undo, and close restores', () async {
      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
        detectionRepository: detectionRepo,
        saveDebounce: const Duration(milliseconds: 20),
      );
      await c.load('demo');
      final originalCount = ready(c).project.beatCount;

      await c.openAutoDetectSheet();
      expect(ready(c).activeSheet, EditorSheet.autoDetect);
      expect(ready(c).previewBeats, detectedBeats);
      expect(ready(c).previewBpm, 120.0);
      expect(ready(c).project.beatCount, originalCount);
      expect(ready(c).undoStack, isEmpty);

      // Move sensitivity slider -> re-classifies synchronously, no save, no isolate.
      c.setPreviewSensitivity(0.2);
      expect(ready(c).previewBeats?.length, 3);
      c.setPreviewFilter(BeatFilter.strong);
      expect(ready(c).previewFilter, BeatFilter.strong);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repo.savedProjects, isEmpty);
      expect(ready(c).undoStack, isEmpty);
      verifyNever(
        () => detectionRepo.analyze(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
          forceReanalyze: any(named: 'forceReanalyze'),
        ),
      );

      // Close without committing -> restores original state.
      c.closeSheet();
      expect(ready(c).activeSheet, EditorSheet.none);
      expect(ready(c).previewBeats, isNull);
      expect(ready(c).project.beatCount, originalCount);
      await c.close();
    });

    test(
      'commit replaces beats, is undoable, and saves bpm/phase/sections/status',
      () async {
        final c = BeatEditorCubit(
          playback: FakeAudioPlayback(),
          repository: repo,
          detectionRepository: detectionRepo,
          saveDebounce: const Duration(milliseconds: 20),
        );
        await c.load('demo');
        final originalBeats = ready(c).project.beats;

        await c.openAutoDetectSheet();
        c.setPreviewSensitivity(0.7);
        c.setPreviewFilter(BeatFilter.every2nd);
        c.commitAutoDetect();

        final s = ready(c);
        expect(s.activeSheet, EditorSheet.none);
        expect(s.project.beats, detectedBeats);
        expect(s.project.bpm, 120.0);
        expect(s.project.beatPhaseSample, 500);
        expect(s.project.sections, detectedSections);
        expect(s.project.detection.sensitivity, 0.7);
        expect(s.project.detection.filter, BeatFilter.every2nd);
        expect(s.project.detection.status, DetectionStatus.succeeded);
        expect(s.undoStack.length, 1);

        // Undo restores the previous beats.
        c.undo();
        expect(ready(c).project.beats, originalBeats);

        // close() flushes the pending debounced save, so this doesn't depend
        // on timer timing under load.
        await c.close();
        expect(repo.savedProjects, isNotEmpty);
        expect(repo.savedProjects.last.beats, originalBeats);
      },
    );
  });

  group('Filter as a view', () {
    test('filter changes visible counts and hit testing without deleting project.beats', () async {
      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
        detectionRepository: detectionRepo,
      );
      await c.load('demo');
      final totalBefore = ready(c).project.beats.length;
      expect(totalBefore, 358);

      c.setFilter(BeatFilter.drops);
      final p = ready(c).project;
      // Underlying project.beats untouched.
      expect(p.beats.length, totalBefore);
      // Visible set only contains the 3 drops.
      final visible = visibleBeatIndices(p);
      expect(visible.length, 3);

      // Hidden beat (index 32 is BeatType.strong at 15 s) is not tappable.
      final hitHidden = TimelinePainter.beatAt(
        project: p,
        playheadSample: p.beats[32].sample,
        zoom: 4,
        dx: 195,
        dy: 300,
        width: 390,
      );
      expect(hitHidden, isNull);

      // Visible drop beat IS tappable and returns its index in project.beats.
      final dropIndex = visible.first;
      final hitDrop = TimelinePainter.beatAt(
        project: p,
        playheadSample: p.beats[dropIndex].sample,
        zoom: 4,
        dx: 195,
        dy: 300,
        width: 390,
      );
      expect(hitDrop, dropIndex);

      await c.close();
    });
  });

  group('No steady beat failed sheet', () {
    test(
      'opens automatically when loaded project has DetectionStatus.failed',
      () async {
        final failedProject =
            createDemoProject(
              id: 'failed',
              bpm: null,
              includeBeats: false,
            ).copyWith(
              detection: const DetectionSettings(
                sensitivity: 0.5,
                status: DetectionStatus.failed,
              ),
            );
        repo.put(failedProject);

        final c = BeatEditorCubit(
          playback: FakeAudioPlayback(),
          repository: repo,
          detectionRepository: detectionRepo,
        );
        await c.load('failed');
        expect(ready(c).activeSheet, EditorSheet.detectFailed);

        // "Tap them in" switches to Tap tool and closes the sheet.
        c.tapBeatsFromFailedSheet();
        expect(ready(c).activeSheet, EditorSheet.none);
        expect(ready(c).tool, EditorTool.tap);
        await c.close();
      },
    );

    test('detectWithMoreSensitivity bumps sensitivity by +0.25 (capped at 1) and opens Auto sheet', () async {
      final failedProject =
          createDemoProject(
            id: 'failed2',
            bpm: null,
            includeBeats: false,
          ).copyWith(
            detection: const DetectionSettings(
              sensitivity: 0.6,
              status: DetectionStatus.failed,
            ),
          );
      repo.put(failedProject);

      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
        detectionRepository: detectionRepo,
      );
      await c.load('failed2');
      await c.detectWithMoreSensitivity();

      expect(ready(c).activeSheet, EditorSheet.autoDetect);
      expect(ready(c).previewSensitivity, closeTo(0.85, 1e-6));
      expect(ready(c).previewBeats, detectedBeats);
      await c.close();
    });

    test('markDropsOnly commits fallback drops when present, or emits infoMessage when none', () async {
      final failedProject =
          createDemoProject(
            id: 'failed3',
            bpm: null,
            includeBeats: false,
          ).copyWith(
            detection: const DetectionSettings(
              sensitivity: 0.5,
              status: DetectionStatus.failed,
            ),
          );
      repo.put(failedProject);

      // Case 1: fallback drops exist.
      const fallbackDrop = Beat(sample: 100000, type: BeatType.drop);
      when(() => detectionRepo.classify(any(), any())).thenReturn(
        const DetectionResult(
          succeeded: false,
          beats: [],
          bpm: null,
          beatPhaseSample: null,
          sections: [],
          fallbackDrops: [fallbackDrop],
        ),
      );

      final c1 = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
        detectionRepository: detectionRepo,
      );
      await c1.load('failed3');
      await c1.markDropsOnly();

      expect(ready(c1).activeSheet, EditorSheet.none);
      expect(ready(c1).project.beats, [fallbackDrop]);
      expect(ready(c1).project.detection.filter, BeatFilter.drops);
      expect(ready(c1).undoStack.length, 1);
      await c1.close();

      // Case 2: no fallback drops -> shows infoMessage (SnackBar).
      repo.put(failedProject);
      when(() => detectionRepo.classify(any(), any())).thenReturn(
        const DetectionResult(
          succeeded: false,
          beats: [],
          bpm: null,
          beatPhaseSample: null,
          sections: [],
          fallbackDrops: [],
        ),
      );

      final c2 = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
        detectionRepository: detectionRepo,
      );
      await c2.load('failed3');
      await c2.markDropsOnly();

      expect(ready(c2).activeSheet, EditorSheet.none);
      expect(ready(c2).infoMessage, isNotNull);
      expect(ready(c2).project.beats, isEmpty);
      await c2.close();
    });
  });
}
