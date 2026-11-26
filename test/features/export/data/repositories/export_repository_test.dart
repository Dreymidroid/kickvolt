import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';
import 'package:kickvolt/core/audio_native/audio_native_client.dart';
import 'package:kickvolt/core/storage/project_paths.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:path/path.dart' as p;

import '../../../../fixtures/demo_project.dart';

class FakeExportAudioNative implements AudioNative {
  int freeBytes = 1 << 40;
  AudioNativeException? encodeError;
  final encodedFiles = <({String jobId, String wavPath, String outPath, int bitrate})>[];
  final cancelledJobs = <String>[];
  int bgTokensIssued = 0;
  final endedBgTokens = <int>[];
  int savedCountResult = 2;
  final savedPaths = <List<String>>[];

  @override
  Future<MediaInfo> encodeM4a({
    required String jobId,
    required String wavPath,
    required String outPath,
    int bitrate = kDefaultM4aBitrate,
    void Function(double fraction)? onProgress,
  }) async {
    encodedFiles.add((
      jobId: jobId,
      wavPath: wavPath,
      outPath: outPath,
      bitrate: bitrate,
    ));
    onProgress?.call(0.5);
    if (encodeError != null) throw encodeError!;
    final info = await readWavInfo(File(wavPath));
    // Write a fake M4A file whose header encodes rate/channels/frames so
    // probeMedia can inspect it from disk.
    final out = File(outPath);
    await out.parent.create(recursive: true);
    final header = ByteData(16)
      ..setUint32(0, 0x4D344121, Endian.little) // 'M4A!'
      ..setUint32(4, info.sampleRate, Endian.little)
      ..setUint32(8, info.channels, Endian.little)
      ..setUint32(12, info.frameCount, Endian.little);
    await out.writeAsBytes(header.buffer.asUint8List());
    onProgress?.call(1.0);
    return probeMedia(outPath);
  }

  @override
  Future<MediaInfo> probeMedia(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final bd = ByteData.sublistView(bytes);
    final sr = bd.getUint32(4, Endian.little);
    final ch = bd.getUint32(8, Endian.little);
    final frames = bd.getUint32(12, Endian.little);
    return MediaInfo(
      sampleRate: sr,
      channels: ch,
      durationUs: frames * 1000000 ~/ sr,
      frameCount: frames,
    );
  }

  @override
  Future<int> saveToFiles(List<String> paths) async {
    savedPaths.add(paths);
    return savedCountResult;
  }

  @override
  Future<int> beginBackgroundWork(String name) async => ++bgTokensIssued;

  @override
  Future<void> endBackgroundWork(int token) async => endedBgTokens.add(token);

  @override
  Future<void> cancel(String jobId) async => cancelledJobs.add(jobId);

  @override
  Future<int> freeDiskBytes(String path) async => freeBytes;

  @override
  Future<DecodeResult> decodeToWav({
    required String jobId,
    required String inputPath,
    required String outputPath,
    void Function(double fraction)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> copyContentUri(String uri, String destPath) =>
      throw UnimplementedError();

  @override
  Future<List<LibraryTrack>> listMusicLibrary() async => const [];

  @override
  Future<LibraryTrack?> pickFromMusicLibrary() async => null;
}

Future<void> _writeSongWav({
  required String path,
  required int sampleRate,
  required int channels,
  required int frameCount,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final header = buildWavHeader(
    sampleRate: sampleRate,
    channels: channels,
    frameCount: frameCount,
  );
  final raf = await file.open(mode: FileMode.write);
  try {
    await raf.writeFrom(header);
    const chunkFrames = 16384;
    final pcm = Int16List(chunkFrames * channels);
    final bytes = Uint8List.view(pcm.buffer);
    final fade = math.max(10, sampleRate ~/ 20);
    var offset = 0;
    while (offset < frameCount) {
      final count = math.min(chunkFrames, frameCount - offset);
      for (var i = 0; i < count; i++) {
        final frame = offset + i;
        var env = 1.0;
        if (frame < fade) env = frame / fade;
        if (frameCount - 1 - frame < fade) {
          env = math.min(env, (frameCount - 1 - frame) / fade);
        }
        final v = (0.3 *
                env *
                math.sin(2 * math.pi * 220.0 * frame / sampleRate) *
                32767)
            .round()
            .clamp(-32768, 32767);
        for (var c = 0; c < channels; c++) {
          pcm[i * channels + c] = v;
        }
      }
      await raf.writeFrom(bytes, 0, count * channels * 2);
      offset += count;
    }
  } finally {
    await raf.close();
  }
}

void main() {
  late Directory docsDir;
  late ProjectPaths paths;
  late FakeExportAudioNative audio;
  late ExportRepositoryImpl repo;
  var clockTick = 0;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('kickvolt_export_repo_');
    paths = ProjectPaths(docsDir.path);
    audio = FakeExportAudioNative();
    clockTick = 0;
    repo = ExportRepositoryImpl(
      audio: audio,
      paths: () async => paths,
      clock: () => DateTime.utc(2026, 11, 26, 10, 0, clockTick++),
    );
  });

  tearDown(() async {
    if (await docsDir.exists()) {
      await docsDir.delete(recursive: true);
    }
  });

  Project makeProject({
    String id = 'p1',
    int sampleRate = 44100,
    int channels = 2,
    int frameCount = 44100 * 2,
  }) {
    return createDemoProject(
      id: id,
      sampleRate: sampleRate,
      includeBeats: false,
    ).copyWith(
      channels: channels,
      sampleCount: frameCount,
      beats: [
        Beat(sample: sampleRate ~/ 4, type: BeatType.strong),
        Beat(sample: sampleRate ~/ 2, type: BeatType.beat),
        Beat(sample: sampleRate, type: BeatType.drop),
      ],
    );
  }

  test('WAV pack: song file is byte-identical to song.wav; guide & preview have identical rate and frameCount', () async {
    final project = makeProject();
    final songWavPath = paths.songWav(project.id);
    await _writeSongWav(
      path: songWavPath,
      sampleRate: project.sampleRate,
      channels: project.channels,
      frameCount: project.sampleCount,
    );

    final progressEvents = <ExportProgress>[];
    final pack = await repo.export(
      project,
      const ExportOptions(
        format: AudioFormat.wav,
        includePreview: true,
        clickStyle: ClickStyle.snap,
      ),
      cancel: ExportCancelToken(),
      onProgress: progressEvents.add,
    );

    expect(pack.files.length, 3);
    expect(progressEvents, isNotEmpty);
    expect(progressEvents.last.overallFraction, 1.0);

    final guideFile = pack.files.firstWhere(
      (f) => f.kind == ExportFileKind.guide,
    );
    final songFile = pack.files.firstWhere(
      (f) => f.kind == ExportFileKind.song,
    );
    final previewFile = pack.files.firstWhere(
      (f) => f.kind == ExportFileKind.preview,
    );

    // WAV song is byte-exact copy of song.wav.
    expect(
      await File(songFile.path).readAsBytes(),
      await File(songWavPath).readAsBytes(),
    );

    final songInfo = await readWavInfo(File(songFile.path));
    final guideInfo = await readWavInfo(File(guideFile.path));
    final previewInfo = await readWavInfo(File(previewFile.path));

    expect(guideInfo.sampleRate, songInfo.sampleRate);
    expect(guideInfo.frameCount, songInfo.frameCount);
    expect(previewInfo.sampleRate, songInfo.sampleRate);
    expect(previewInfo.frameCount, songInfo.frameCount);
    expect(guideFile.clickCount, 3);

    // No .part files left anywhere in the pack folder.
    final packEntities = await Directory(pack.directoryPath).list().toList();
    expect(
      packEntities.where((e) => e.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('M4A pack calls encodeM4a for each file and deletes intermediate WAVs', () async {
    final project = makeProject();
    await _writeSongWav(
      path: paths.songWav(project.id),
      sampleRate: project.sampleRate,
      channels: project.channels,
      frameCount: project.sampleCount,
    );

    final pack = await repo.export(
      project,
      const ExportOptions(
        format: AudioFormat.m4a,
        includePreview: true,
        clickStyle: ClickStyle.rim,
      ),
      cancel: ExportCancelToken(),
    );

    expect(pack.files.length, 3);
    expect(audio.encodedFiles.length, 3);
    for (final f in pack.files) {
      expect(f.path.endsWith('.m4a'), isTrue);
      expect(await File(f.path).exists(), isTrue);
      expect(f.frameCount, project.sampleCount);
    }

    // All intermediate WAVs and .part files in the pack folder are deleted.
    final remaining = await Directory(pack.directoryPath).list().toList();
    for (final e in remaining) {
      expect(e.path.endsWith('.m4a'), isTrue);
    }
  });

  test('cancel mid-render and cancel immediately after start (30x) leave no .part and folder is deletable', () async {
    final project = makeProject(frameCount: 44100 * 6);
    await _writeSongWav(
      path: paths.songWav(project.id),
      sampleRate: project.sampleRate,
      channels: project.channels,
      frameCount: project.sampleCount,
    );

    // 1. Cancel mid-render on progress callback.
    final midToken = ExportCancelToken();
    var triggered = false;
    final midFuture = repo.export(
      project,
      const ExportOptions(format: AudioFormat.wav, includePreview: true),
      cancel: midToken,
      onProgress: (_) {
        if (!triggered) {
          triggered = true;
          midToken.cancel();
        }
      },
    );
    await expectLater(midFuture, throwsA(isA<ExportCancelledException>()));

    // 2. Cancel immediately after start (isolate still spawning) repeated 30x.
    for (var i = 0; i < 30; i++) {
      final token = ExportCancelToken();
      final future = repo.export(
        project,
        const ExportOptions(format: AudioFormat.wav),
        cancel: token,
      );
      if (i % 3 == 1) await Future<void>.value();
      if (i % 3 == 2) await pumpEventQueue();
      await token.cancel();
      await expectLater(
        future,
        throwsA(isA<ExportCancelledException>()),
        reason: 'iteration $i',
      );
    }

    final exportsDir = Directory(paths.exportsDir(project.id));
    if (await exportsDir.exists()) {
      final leftover = await exportsDir.list().toList();
      expect(leftover, isEmpty);
    }

    // Project directory deletes immediately on Windows without a file-lock error.
    await Directory(paths.projectDir(project.id)).delete(recursive: true);
    expect(await Directory(paths.projectDir(project.id)).exists(), isFalse);
  });

  test('pre-check with freeDiskBytes too low fails with diskFull before any file is written', () async {
    final project = makeProject(frameCount: 44100 * 10);
    await _writeSongWav(
      path: paths.songWav(project.id),
      sampleRate: project.sampleRate,
      channels: project.channels,
      frameCount: project.sampleCount,
    );

    audio.freeBytes = 5 * 1024 * 1024; // 5 MB < 20 MB margin + pack bytes

    await expectLater(
      repo.export(
        project,
        const ExportOptions(format: AudioFormat.wav),
        cancel: ExportCancelToken(),
      ),
      throwsA(
        isA<ExportFailureException>()
            .having((e) => e.failure.kind, 'kind', ExportFailureKind.diskFull)
            .having(
              (e) => e.failure.neededMegabytes,
              'neededMegabytes',
              greaterThan(0),
            ),
      ),
    );

    final exportsDir = Directory(paths.exportsDir(project.id));
    expect(
      !await exportsDir.exists() || (await exportsDir.list().toList()).isEmpty,
      isTrue,
    );
  });

  test('ENOSPC (OSError errorCode 28) during writing maps to diskFull with failed file label', () async {
    final project = makeProject();
    await _writeSongWav(
      path: paths.songWav(project.id),
      sampleRate: project.sampleRate,
      channels: project.channels,
      frameCount: project.sampleCount,
    );

    final enospcRepo = ExportRepositoryImpl(
      audio: audio,
      paths: () async => paths,
      renderHookForTesting: (step) async {
        if (step.kind == ExportFileKind.guide) {
          throw const FileSystemException(
            'write failed',
            '/fake/guide.wav.part',
            OSError('No space left on device', 28),
          );
        }
      },
    );

    await expectLater(
      enospcRepo.export(
        project,
        const ExportOptions(format: AudioFormat.wav),
        cancel: ExportCancelToken(),
      ),
      throwsA(
        isA<ExportFailureException>()
            .having((e) => e.failure.kind, 'kind', ExportFailureKind.diskFull)
            .having(
              (e) => e.failure.failedFileLabel,
              'failedFileLabel',
              'the guide track',
            ),
      ),
    );
  });

  test('native encode_failed maps to encodeFailed and removes partial pack folder', () async {
    final project = makeProject();
    await _writeSongWav(
      path: paths.songWav(project.id),
      sampleRate: project.sampleRate,
      channels: project.channels,
      frameCount: project.sampleCount,
    );

    audio.encodeError = const AudioNativeException(
      AudioErrorKind.encodeFailed,
      'Codec rejected rate',
    );

    await expectLater(
      repo.export(
        project,
        const ExportOptions(format: AudioFormat.m4a),
        cancel: ExportCancelToken(),
      ),
      throwsA(
        isA<ExportFailureException>().having(
          (e) => e.failure.kind,
          'kind',
          ExportFailureKind.encodeFailed,
        ),
      ),
    );

    final exportsDir = Directory(paths.exportsDir(project.id));
    expect(
      !await exportsDir.exists() || (await exportsDir.list().toList()).isEmpty,
      isTrue,
    );
  });

  test('cleanUpStaleParts removes pack folders with .part files or empty, keeping finished ones', () async {
    final staleWithPart = Directory(
      paths.exportPackDir('p1', '20261126-090000'),
    );
    await staleWithPart.create(recursive: true);
    await File(p.join(staleWithPart.path, 'MidnightRun_beats.wav.part'))
        .writeAsBytes([1, 2, 3]);

    final staleEmpty = Directory(
      paths.exportPackDir('p1', '20261126-090100'),
    );
    await staleEmpty.create(recursive: true);

    final finished = Directory(
      paths.exportPackDir('p1', '20261126-090200'),
    );
    await finished.create(recursive: true);
    await File(p.join(finished.path, 'MidnightRun_beats.wav'))
        .writeAsBytes([1, 2, 3]);

    await repo.cleanUpStaleParts();

    expect(await staleWithPart.exists(), isFalse);
    expect(await staleEmpty.exists(), isFalse);
    expect(await finished.exists(), isTrue);
  });

  test('keeps only the last 3 packs per project after a successful export', () async {
    final project = makeProject(frameCount: 4410);
    await _writeSongWav(
      path: paths.songWav(project.id),
      sampleRate: project.sampleRate,
      channels: project.channels,
      frameCount: project.sampleCount,
    );

    final createdDirs = <String>[];
    for (var i = 0; i < 5; i++) {
      final pack = await repo.export(
        project,
        const ExportOptions(format: AudioFormat.wav),
        cancel: ExportCancelToken(),
      );
      createdDirs.add(pack.directoryPath);
    }

    final remaining = await Directory(paths.exportsDir(project.id))
        .list()
        .where((e) => e is Directory)
        .map((e) => e.path)
        .toList()
      ..sort();

    expect(remaining.length, 3);
    expect(remaining, createdDirs.sublist(2));
  });
}
