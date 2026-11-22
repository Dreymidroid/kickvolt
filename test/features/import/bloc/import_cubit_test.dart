import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:mocktail/mocktail.dart';

class MockImportRepository extends Mock implements ImportRepository {}

class FakePickedSource extends Fake implements PickedSource {}

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
  late MockImportRepository repo;

  setUpAll(() {
    registerFallbackValue(FakePickedSource());
    registerFallbackValue(ImportCancelToken());
  });
  setUp(() => repo = MockImportRepository());

  void stubImport(Future<ImportedSong> Function(Invocation) answer) => when(
    () => repo.importSong(
      any(),
      onProgress: any(named: 'onProgress'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer(answer);

  blocTest<ImportCubit, ImportState>(
    'emits progress then done',
    build: () {
      stubImport((inv) async {
        final onProgress =
            inv.namedArguments[#onProgress] as void Function(double);
        onProgress(0.3);
        onProgress(0.2); // out of order: ignored
        onProgress(0.9);
        return song;
      });
      return ImportCubit(source: source, repository: repo);
    },
    act: (c) => c.start(),
    expect: () => const [
      ImportState.importing(source: source, progress: 0.3),
      ImportState.importing(source: source, progress: 0.9),
      ImportState.done(song),
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
      return ImportCubit(source: source, repository: repo);
    },
    act: (c) => c.start(),
    expect: () => [
      isA<ImportFailed>().having(
        (s) => s.failure.kind,
        'kind',
        ImportFailureKind.protected,
      ),
    ],
  );

  blocTest<ImportCubit, ImportState>(
    'wraps unexpected errors as unknown failures',
    build: () {
      stubImport((_) async => throw StateError('boom'));
      return ImportCubit(source: source, repository: repo);
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
      return ImportCubit(source: source, repository: repo);
    },
    act: (c) async {
      final f = c.start();
      await c.cancel();
      await f;
    },
    expect: () => const [ImportState.cancelled()],
  );
}
