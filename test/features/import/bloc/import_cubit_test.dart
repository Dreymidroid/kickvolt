import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:mocktail/mocktail.dart';

class MockImportRepository extends Mock implements ImportRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class FakePickedSource extends Fake implements PickedSource {}

class FakeImportedSong extends Fake implements ImportedSong {}

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

  late MockImportRepository repo;
  late MockProjectRepository projectRepo;

  setUpAll(() {
    registerFallbackValue(FakePickedSource());
    registerFallbackValue(FakeImportedSong());
    registerFallbackValue(ImportCancelToken());
  });

  setUp(() {
    repo = MockImportRepository();
    projectRepo = MockProjectRepository();
    when(() => projectRepo.createFromImport(any()))
        .thenAnswer((_) async => createdProject);
    when(() => projectRepo.deleteProject(any())).thenAnswer((_) async {});
  });

  void stubImport(Future<ImportedSong> Function(Invocation) answer) => when(
    () => repo.importSong(
      any(),
      onProgress: any(named: 'onProgress'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer(answer);

  blocTest<ImportCubit, ImportState>(
    'maps decode progress to 0..0.9, creates project, emits 1.0 then done',
    build: () {
      stubImport((inv) async {
        final onProgress =
            inv.namedArguments[#onProgress] as void Function(double);
        onProgress(0.3);
        onProgress(0.2); // out of order: ignored
        onProgress(1.0);
        return song;
      });
      return ImportCubit(
        source: source,
        repository: repo,
        projectRepository: projectRepo,
      );
    },
    act: (c) => c.start(),
    expect: () => const [
      ImportState.importing(source: source, progress: 0.27),
      ImportState.importing(source: source, progress: 0.9),
      ImportState.importing(source: source, progress: 1.0),
      ImportState.done(song),
    ],
    verify: (_) {
      verify(() => projectRepo.createFromImport(song)).called(1);
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
    'cancel passes through the token and emits cancelled',
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
