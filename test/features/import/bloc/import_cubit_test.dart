import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:mocktail/mocktail.dart';

class MockImportRepository extends Mock implements ImportRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockBeatDetectionRepository extends Mock
    implements BeatDetectionRepository {}

class FakePickedSource extends Fake implements PickedSource {}

class FakeImportedSong extends Fake implements ImportedSong {}

class FakeProject extends Fake implements Project {}

class FakeBeatAnalysis extends Fake implements BeatAnalysis {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const source = PickedSource(
    kind: ImportSourceKind.file,
    location: '/tmp/a.mp3',
    displayName: 'a.mp3',
  );
  const song = ImportedSong(
    projectId: 'p1',
    title: 'a',
    source: source,
    wavPath: '/docs/projects/p1/song.wav',
    sampleRate: 44100,
    channels: 2,
    frameCount: 441000,
  );
  final createdProject = Project(
    id: 'p1',
    title: 'a',
    source: const ProjectSource(
      kind: ImportSourceKind.file,
      originalName: 'a.mp3',
      copiedFileName: 'source.mp3',
    ),
    sampleRate: 44100,
    channels: 2,
    sampleCount: 441000,
    createdAt: DateTime.utc(2026, 11, 22),
    updatedAt: DateTime.utc(2026, 11, 22),
  );
  final dummyAnalysis = BeatAnalysis(
    sampleRate: 44100,
    sampleCount: 441000,
    hopSize: 512,
    bpm: 128.0,
    confidence: 3.5,
    beatPhaseSample: 0,
    candidates: const [],
    frameLowEnergy: Float32List(0),
    frameOverallEnergy: Float32List(0),
  );
  const detectedBeats = [
    Beat(sample: 0, type: BeatType.downbeat),
    Beat(sample: 20672, type: BeatType.beat),
  ];
  final detectedSections = [
    Section(
      startSample: 0,
      endSample: 441000,
      name: SectionPreset.verse.name,
      colorArgb: SectionPreset.verse.colorArgb,
    ),
  ];

  late MockImportRepository repo;
  late MockProjectRepository projectRepo;
  late MockBeatDetectionRepository detectionRepo;

  setUpAll(() {
    registerFallbackValue(FakePickedSource());
    registerFallbackValue(FakeImportedSong());
    registerFallbackValue(FakeProject());
    registerFallbackValue(FakeBeatAnalysis());
    registerFallbackValue(ImportCancelToken());
    registerFallbackValue(AnalysisCancelToken());
  });

  setUp(() {
    repo = MockImportRepository();
    projectRepo = MockProjectRepository();
    detectionRepo = MockBeatDetectionRepository();
    when(() => projectRepo.createFromImport(any()))
        .thenAnswer((_) async => createdProject);
    when(() => projectRepo.saveProject(any())).thenAnswer((_) async {});
    when(() => projectRepo.deleteProject(any())).thenAnswer((_) async {});
    when(
      () => detectionRepo.analyze(
        any(),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
        forceReanalyze: any(named: 'forceReanalyze'),
      ),
    ).thenAnswer((_) async => dummyAnalysis);
    when(() => detectionRepo.classify(any(), any())).thenReturn(
      DetectionResult(
        succeeded: true,
        beats: detectedBeats,
        bpm: 128.0,
        beatPhaseSample: 0,
        sections: detectedSections,
      ),
    );
  });

  void stubImport(Future<ImportedSong> Function(Invocation) answer) => when(
    () => repo.importSong(
      any(),
      onProgress: any(named: 'onProgress'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer(answer);

  blocTest<ImportCubit, ImportState>(
    'maps decode 0..0.6, project 0.65, analysis 0.65..1.0 with live stages and BPM, saves project then done',
    build: () {
      stubImport((inv) async {
        final onProgress =
            inv.namedArguments[#onProgress] as void Function(double);
        onProgress(0.5);
        onProgress(0.2); // out of order: ignored
        onProgress(1.0);
        return song;
      });
      when(
        () => detectionRepo.analyze(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
          forceReanalyze: any(named: 'forceReanalyze'),
        ),
      ).thenAnswer((inv) async {
        final onProgress =
            inv.namedArguments[#onProgress] as void Function(AnalysisProgress);
        onProgress(
          const AnalysisProgress(
            stage: AnalysisStage.tempo,
            fraction: 0.5,
            bpm: 128.0,
          ),
        );
        onProgress(
          const AnalysisProgress(
            stage: AnalysisStage.tracking,
            fraction: 0.8,
            bpm: 128.0,
          ),
        );
        onProgress(
          const AnalysisProgress(
            stage: AnalysisStage.sections,
            fraction: 1.0,
            bpm: 128.0,
          ),
        );
        return dummyAnalysis;
      });
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
        detectionRepository: detectionRepo,
      );
    },
    act: (c) => c.start(),
    expect: () => [
      const ImportState.importing(
        source: source,
        progress: 0.3,
        step: ImportStep.reading,
      ),
      const ImportState.importing(
        source: source,
        progress: 0.6,
        step: ImportStep.reading,
      ),
      const ImportState.importing(
        source: source,
        progress: 0.65,
        step: ImportStep.tempo,
      ),
      isA<ImportImporting>()
          .having((s) => s.step, 'step', ImportStep.tempo)
          .having((s) => s.detectedBpm, 'bpm', 128.0)
          .having((s) => s.progress, 'progress', closeTo(0.825, 1e-6)),
      isA<ImportImporting>()
          .having((s) => s.step, 'step', ImportStep.beats)
          .having((s) => s.detectedBpm, 'bpm', 128.0)
          .having((s) => s.progress, 'progress', closeTo(0.93, 1e-6)),
      isA<ImportImporting>()
          .having((s) => s.step, 'step', ImportStep.sections)
          .having((s) => s.progress, 'progress', closeTo(0.99, 1e-6)),
      const ImportState.importing(
        source: source,
        progress: 1.0,
        step: ImportStep.sections,
        detectedBpm: 128.0,
      ),
      const ImportState.done(song),
    ],
    verify: (_) {
      verify(() => projectRepo.createFromImport(song)).called(1);
      final saved =
          verify(() => projectRepo.saveProject(captureAny())).captured.single
              as Project;
      expect(saved.beats, detectedBeats);
      expect(saved.bpm, 128.0);
      expect(saved.sections, detectedSections);
      expect(saved.detection.status, DetectionStatus.succeeded);
    },
  );

  blocTest<ImportCubit, ImportState>(
    'detection failure still ends in done with status: failed and no beats',
    build: () {
      stubImport((_) async => song);
      when(() => detectionRepo.classify(any(), any())).thenReturn(
        const DetectionResult(
          succeeded: false,
          beats: [],
          bpm: null,
          beatPhaseSample: null,
          sections: [],
        ),
      );
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
        detectionRepository: detectionRepo,
      );
    },
    act: (c) => c.start(),
    expect: () => [
      const ImportState.importing(
        source: source,
        progress: 0.65,
        step: ImportStep.tempo,
      ),
      const ImportState.importing(
        source: source,
        progress: 1.0,
        step: ImportStep.sections,
      ),
      const ImportState.done(song),
    ],
    verify: (_) {
      final saved =
          verify(() => projectRepo.saveProject(captureAny())).captured.single
              as Project;
      expect(saved.beats, isEmpty);
      expect(saved.bpm, isNull);
      expect(saved.sections, isEmpty);
      expect(saved.detection.status, DetectionStatus.failed);
      verifyNever(() => projectRepo.deleteProject(any()));
    },
  );

  blocTest<ImportCubit, ImportState>(
    'cancel during analysis deletes the created project and emits cancelled',
    build: () {
      stubImport((_) async => song);
      when(
        () => detectionRepo.analyze(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
          forceReanalyze: any(named: 'forceReanalyze'),
        ),
      ).thenAnswer((inv) async {
        final token = inv.namedArguments[#cancelToken] as AnalysisCancelToken;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (token.isCancelled) throw const AnalysisCancelledException();
        return dummyAnalysis;
      });
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
        detectionRepository: detectionRepo,
      );
    },
    act: (c) async {
      final f = c.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await c.cancel();
      await f;
    },
    expect: () => [
      const ImportState.importing(
        source: source,
        progress: 0.65,
        step: ImportStep.tempo,
      ),
      const ImportState.cancelled(),
    ],
    verify: (_) {
      verify(() => projectRepo.deleteProject('p1')).called(1);
      verifyNever(() => projectRepo.saveProject(any()));
    },
  );

  blocTest<ImportCubit, ImportState>(
    'emits failed when project creation fails after decode',
    build: () {
      stubImport((_) async => song);
      when(() => projectRepo.createFromImport(any()))
          .thenThrow(const ProjectCorruptException('disk error'));
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
        detectionRepository: detectionRepo,
      );
    },
    act: (c) => c.start(),
    expect: () => [
      isA<ImportFailed>()
          .having((s) => s.failure.kind, 'kind', ImportFailureKind.unknown)
          .having((s) => s.failure.fileName, 'fileName', 'a.mp3'),
    ],
  );

  blocTest<ImportCubit, ImportState>(
    'emits failed with the import failure',
    build: () {
      stubImport(
        (_) async => throw const ImportFailure(
          ImportFailureKind.protected,
          fileName: 'a.mp3',
        ),
      );
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
        detectionRepository: detectionRepo,
      );
    },
    act: (c) => c.start(),
    expect: () => [
      isA<ImportFailed>().having(
        (s) => s.failure.kind,
        'kind',
        ImportFailureKind.protected,
      ),
    ],
    verify: (_) {
      verifyNever(() => projectRepo.createFromImport(any()));
    },
  );

  blocTest<ImportCubit, ImportState>(
    'wraps unexpected errors as unknown failures',
    build: () {
      stubImport((_) async => throw StateError('boom'));
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
        detectionRepository: detectionRepo,
      );
    },
    act: (c) => c.start(),
    expect: () => [
      isA<ImportFailed>()
          .having((s) => s.failure.kind, 'kind', ImportFailureKind.unknown)
          .having((s) => s.failure.fileName, 'fileName', 'a.mp3'),
    ],
  );

  blocTest<ImportCubit, ImportState>(
    'cancel during decode passes through the token and emits cancelled',
    build: () {
      stubImport((inv) async {
        final token = inv.namedArguments[#cancelToken] as ImportCancelToken;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (token.isCancelled) throw const ImportCancelled();
        return song;
      });
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
        detectionRepository: detectionRepo,
      );
    },
    act: (c) async {
      final f = c.start();
      await c.cancel();
      await f;
    },
    expect: () => const [ImportState.cancelled()],
  );
}
