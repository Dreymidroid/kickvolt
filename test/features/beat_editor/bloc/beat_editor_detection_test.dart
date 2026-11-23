import 'dart:async';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
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
    test('preview updates previewBeats without saving or touching undo, and close restores', () {
      fakeAsync((async) {
        final c = BeatEditorCubit(
          playback: FakeAudioPlayback(),
          repository: repo,
          detectionRepository: detectionRepo,
          saveDebounce: const Duration(milliseconds: 200),
        );
        unawaited(c.load('demo'));
        async.flushMicrotasks();
        final originalCount = ready(c).project.beatCount;

        unawaited(c.openAutoDetectSheet());
        async.flushMicrotasks();
        expect(ready(c).activeSheet, EditorSheet.autoDetect);
        expect(ready(c).previewBeats, detectedBeats);
        expect(ready(c).previewBpm, 120.0);
        expect(ready(c).project.beatCount, originalCount);
        expect(ready(c).canUndo, isFalse);

        // Move sensitivity slider -> re-classifies synchronously, no save, no isolate.
        c.setPreviewSensitivity(0.2);
        expect(ready(c).previewBeats?.length, 3);
        c.setPreviewFilter(BeatFilter.strong);
        expect(ready(c).previewFilter, BeatFilter.strong);

        async.elapse(const Duration(milliseconds: 500));
        expect(repo.savedProjects, isEmpty);
        expect(ready(c).canUndo, isFalse);
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
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('commit replaces beats, and undo restores beats, bpm, phase, sections and detection', () async {
      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
        detectionRepository: detectionRepo,
        saveDebounce: const Duration(milliseconds: 200),
      );
      await c.load('demo');
      final originalProject = ready(c).project;

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
      expect(s.canUndo, isTrue);

      // Undo restores ALL FIVE editable fields (M5 ReplaceAll fix).
      c.undo();
      expect(ready(c).project, originalProject);

      // close() flushes the pending debounced save.
      await c.close();
      expect(repo.savedProjects, isNotEmpty);
      expect(repo.savedProjects.last, originalProject);
    });
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
      expect(p.beats.length, totalBefore);
      final visible = visibleBeatIndices(p);
      expect(visible.length, 3);

      final hitHidden = TimelinePainter.beatAt(
        project: p,
        playheadSample: p.beats[32].sample,
        zoom: 4,
        dx: 195,
        dy: 300,
        width: 390,
      );
      expect(hitHidden, isNull);

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

    test(
      'markDropsOnly commits fallback drops and undo restores full state',
      () async {
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
        expect(ready(c1).project.detection.status, DetectionStatus.succeeded);
        expect(ready(c1).canUndo, isTrue);

        // Undo restores beats, filter, and failed status.
        c1.undo();
        expect(ready(c1).project, failedProject);
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
      },
    );
  });
}
