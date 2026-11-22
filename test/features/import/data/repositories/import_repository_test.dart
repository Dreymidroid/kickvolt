import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';
import 'package:kickvolt/core/audio_native/audio_native_client.dart';
import 'package:kickvolt/core/storage/project_paths.dart';
import 'package:kickvolt/features/import/import.dart';

/// Writes a real WAV like the native decoders do, and records calls.
class FakeAudioNative implements AudioNative {
  FakeAudioNative({this.frames = 4410, this.sampleRate = 44100});

  int frames;
  int sampleRate;
  int channels = 2;
  AudioNativeException? decodeError;
  int freeBytes = 1 << 40;

  /// When set, decode waits for this before finishing.
  Completer<void>? hold;

  /// Completes when a decode starts.
  final decodeStarted = Completer<void>();

  /// Lie in the result to test verification.
  int? reportFrames;

  final decodeInputs = <String>[];
  final copiedUris = <String>[];
  final cancelled = <String>[];

  @override
  Future<DecodeResult> decodeToWav({
    required String jobId,
    required String inputPath,
    required String outputPath,
    void Function(double)? onProgress,
  }) async {
    decodeInputs.add(inputPath);
    if (!decodeStarted.isCompleted) decodeStarted.complete();
    onProgress?.call(0.5);
    if (hold != null) await hold!.future;
    if (cancelled.contains(jobId)) {
      throw const AudioNativeException(AudioErrorKind.cancelled);
    }
    if (decodeError != null) throw decodeError!;
    File(outputPath).writeAsBytesSync([
      ...buildWavHeader(
        sampleRate: sampleRate,
        channels: channels,
        frameCount: frames,
      ),
      ...List.filled(frames * channels * 2, 0),
    ]);
    onProgress?.call(1);
    return DecodeResult(
      sampleRate: sampleRate,
      channels: channels,
      frameCount: reportFrames ?? frames,
    );
  }

  @override
  Future<void> cancel(String jobId) async => cancelled.add(jobId);

  @override
  Future<void> copyContentUri(String uri, String destPath) async {
    copiedUris.add(uri);
    File(destPath).writeAsBytesSync([1, 2, 3]);
  }

  @override
  Future<int> freeDiskBytes(String path) async => freeBytes;

  @override
  Future<List<LibraryTrack>> listMusicLibrary() async => const [];

  @override
  Future<LibraryTrack?> pickFromMusicLibrary() async => null;
}

void main() {
  late Directory docs;
  late FakeAudioNative audio;
  late ImportRepositoryImpl repo;
  late ProjectPaths paths;
  late File picked;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('import_repo_test');
    paths = ProjectPaths(docs.path);
    audio = FakeAudioNative();
    repo = ImportRepositoryImpl(
      audio: audio,
      paths: () async => paths,
      newId: () => 'p1',
    );
    picked = File('${docs.path}/Midnight Run.M4A')
      ..writeAsBytesSync(List.filled(64, 7));
  });

  tearDown(() => docs.deleteSync(recursive: true));

  PickedSource fileSource() => PickedSource(
    kind: ImportSourceKind.file,
    location: picked.path,
    displayName: 'Midnight Run.M4A',
  );

  test(
    'copies the source into the project and decodes from the copy',
    () async {
      final progress = <double>[];
      final song = await repo.importSong(
        fileSource(),
        onProgress: progress.add,
      );

      final copy = File(paths.sourceFile('p1', 'm4a'));
      expect(copy.existsSync(), isTrue);
      expect(copy.readAsBytesSync(), picked.readAsBytesSync());
      expect(audio.decodeInputs, [copy.path]);

      expect(song.projectId, 'p1');
      expect(song.title, 'Midnight Run');
      expect(song.sourceCopyPath, copy.path);
      expect(song.wavPath, paths.songWav('p1'));
      expect(song.sampleRate, 44100);
      expect(song.channels, 2);
      expect(song.frameCount, 4410);
      expect(song.durationMs, 100);

      expect(progress.first, 0);
      expect(progress.last, 1);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    },
  );

  test('project survives the original file being deleted', () async {
    final song = await repo.importSong(fileSource());
    picked.deleteSync();
    expect(File(song.sourceCopyPath!).existsSync(), isTrue);
    expect(File(song.wavPath).existsSync(), isTrue);
  });

  test('iOS library asset URLs are decoded directly, without a copy', () async {
    const url = 'ipod-library://item/item.m4a?id=123';
    final song = await repo.importSong(
      const PickedSource(
        kind: ImportSourceKind.library,
        location: url,
        displayName: 'Library Song',
        durationMs: 100,
      ),
    );
    expect(audio.decodeInputs, [url]);
    expect(song.sourceCopyPath, isNull);
  });

  test('Android content URIs are copied natively', () async {
    const uri = 'content://media/external/audio/media/42';
    await repo.importSong(
      const PickedSource(
        kind: ImportSourceKind.library,
        location: uri,
        displayName: 'Song',
      ),
    );
    expect(audio.copiedUris, [uri]);
    expect(audio.decodeInputs, [paths.sourceFile('p1', '')]);
  });

  test('a DRM failure maps to "protected" and removes the project', () async {
    audio.decodeError = const AudioNativeException(AudioErrorKind.drmProtected);
    await expectLater(
      repo.importSong(fileSource()),
      throwsA(
        isA<ImportFailure>()
            .having((f) => f.kind, 'kind', ImportFailureKind.protected)
            .having((f) => f.fileName, 'fileName', 'Midnight Run.M4A'),
      ),
    );
    expect(Directory(paths.projectDir('p1')).existsSync(), isFalse);
  });

  test('unsupported formats map to "unsupported"', () async {
    audio.decodeError = const AudioNativeException(
      AudioErrorKind.unsupportedFormat,
    );
    await expectLater(
      repo.importSong(fileSource()),
      throwsA(
        isA<ImportFailure>().having(
          (f) => f.kind,
          'kind',
          ImportFailureKind.unsupported,
        ),
      ),
    );
  });

  test('not enough space to copy fails before copying', () async {
    audio.freeBytes = 10;
    await expectLater(
      repo.importSong(fileSource()),
      throwsA(
        isA<ImportFailure>().having(
          (f) => f.kind,
          'kind',
          ImportFailureKind.diskFull,
        ),
      ),
    );
    expect(audio.decodeInputs, isEmpty);
    expect(Directory(paths.projectDir('p1')).existsSync(), isFalse);
  });

  test('rejects a WAV that disagrees with the decoder result', () async {
    audio.reportFrames = 9999;
    await expectLater(
      repo.importSong(fileSource()),
      throwsA(
        isA<ImportFailure>().having(
          (f) => f.kind,
          'kind',
          ImportFailureKind.unsupported,
        ),
      ),
    );
    expect(Directory(paths.projectDir('p1')).existsSync(), isFalse);
  });

  test('cancel during decoding stops the native job and cleans up', () async {
    audio.hold = Completer();
    final token = ImportCancelToken();
    final future = repo.importSong(fileSource(), cancelToken: token);
    await audio.decodeStarted.future;
    await token.cancel();
    audio.hold!.complete();

    await expectLater(future, throwsA(isA<ImportCancelled>()));
    expect(audio.cancelled, ['import-p1']);
    expect(Directory(paths.projectDir('p1')).existsSync(), isFalse);
  });

  test('cancel before decoding never starts the decoder', () async {
    final token = ImportCancelToken();
    final future = repo.importSong(fileSource(), cancelToken: token);
    await token.cancel();

    await expectLater(future, throwsA(isA<ImportCancelled>()));
    expect(audio.decodeInputs, isEmpty);
    expect(Directory(paths.projectDir('p1')).existsSync(), isFalse);
  });
}
