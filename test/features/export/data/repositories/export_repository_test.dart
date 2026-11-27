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
import '../../../../fixtures/export_fakes.dart' show FakeEntitlementService;

class FakeExportAudioNative implements AudioNative {
  int freeBytes = 1 << 40;
  AudioNativeException? encodeError;
  final encodedFiles =
      <({String jobId, String wavPath, String outPath, int bitrate})>[];
  final cancelledJobs = <String>[];

  /// Ordered log of native work, e.g. `video:<wav name>` / `m4a:<wav name>`.
  final events = <String>[];

  // Guide video (M7).
  final videoSpecs = <GuideVideoSpec>[];
  final videoJobIds = <String>[];

  /// Info about the guide WAV the video was given, read from disk.
  final videoAudioInfo = <WavInfo>[];
  AudioNativeException? videoError;

  /// When set, encodeGuideVideo waits here until cancelled.
  Completer<void>? videoGate;

  /// Overrides what the fake MP4 reports (to test verification).
  int videoFrameDelta = 0;

  @override
  Future<MediaInfo> encodeGuideVideo({
    required String jobId,
    required GuideVideoSpec spec,
    void Function(double fraction)? onProgress,
  }) async {
    videoSpecs.add(spec);
    videoJobIds.add(jobId);
    events.add('video:${p.basename(spec.audioWavPath)}');
    final info = await readWavInfo(File(spec.audioWavPath));
    videoAudioInfo.add(info);
    onProgress?.call(0.5);
    final gate = videoGate;
    if (gate != null) {
      await gate.future;
      if (cancelledJobs.contains(jobId)) {
        throw const AudioNativeException(AudioErrorKind.cancelled, 'stop');
      }
    }
    if (videoError != null) throw videoError!;
    final out = File(spec.outPath);
    await out.parent.create(recursive: true);
    final frames = spec.totalFrames + videoFrameDelta;
    final header = ByteData(28)
      ..setUint32(0, 0x4D503421, Endian.little) // 'MP4!'
      ..setUint32(4, info.sampleRate, Endian.little)
      ..setUint32(8, info.channels, Endian.little)
      ..setUint32(12, info.frameCount, Endian.little)
      ..setUint32(16, frames, Endian.little)
      ..setUint32(20, spec.width, Endian.little)
      ..setUint32(24, spec.height, Endian.little);
    await out.writeAsBytes(header.buffer.asUint8List());
    onProgress?.call(1.0);
    return probeMedia(spec.outPath);
  }

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
    events.add('m4a:${p.basename(wavPath)}');
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
    if (bd.getUint32(0, Endian.little) == 0x4D503421) {
      final videoFrames = bd.getUint32(16, Endian.little);
      return MediaInfo(
        sampleRate: sr,
        channels: ch,
        durationUs: frames * 1000000 ~/ sr,
        frameCount: frames,
        hasVideo: true,
        videoFrameCount: videoFrames,
        videoDurationUs: (videoFrames * 1000000 + 29) ~/ 30,
        videoWidth: bd.getUint32(20, Endian.little),
        videoHeight: bd.getUint32(24, Endian.little),
      );
    }
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
  Future<bool> requestAudioPermission() async => true;

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
        final v =
            (0.3 *
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
    expect(packEntities.where((e) => e.path.endsWith('.part')), isEmpty);
  });

  test(
    'M4A pack calls encodeM4a for each file and deletes intermediate WAVs',
    () async {
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
    },
  );

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

  test(
    'native encode_failed maps to encodeFailed and removes partial pack folder',
    () async {
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
        !await exportsDir.exists() ||
            (await exportsDir.list().toList()).isEmpty,
        isTrue,
      );
    },
  );

  test('cleanUpStaleParts removes pack folders with .part files or empty, keeping finished ones', () async {
    final staleWithPart = Directory(
      paths.exportPackDir('p1', '20261126-090000'),
    );
    await staleWithPart.create(recursive: true);
    await File(p.join(staleWithPart.path, 'MidnightRun_beats.wav.part'))
        .writeAsBytes([1, 2, 3]);

    final staleEmpty = Directory(paths.exportPackDir('p1', '20261126-090100'));
    await staleEmpty.create(recursive: true);

    final finished = Directory(paths.exportPackDir('p1', '20261126-090200'));
    await finished.create(recursive: true);
    await File(p.join(finished.path, 'MidnightRun_beats.wav'))
        .writeAsBytes([1, 2, 3]);

    await repo.cleanUpStaleParts();

    expect(await staleWithPart.exists(), isFalse);
    expect(await staleEmpty.exists(), isFalse);
    expect(await finished.exists(), isTrue);
  });

  test(
    'keeps only the last 3 packs per project after a successful export',
    () async {
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

      final remaining =
          await Directory(paths.exportsDir(project.id))
                .list()
                .where((e) => e is Directory)
                .map((e) => e.path)
                .toList()
            ..sort();

      expect(remaining.length, 3);
      expect(remaining, createdDirs.sublist(2));
    },
  );

  group('guide video (M7)', () {
    Future<Project> songProject() async {
      final project = makeProject();
      await _writeSongWav(
        path: paths.songWav(project.id),
        sampleRate: project.sampleRate,
        channels: project.channels,
        frameCount: project.sampleCount,
      );
      return project;
    }

    Future<void> expectNoPackLeft(Project project) async {
      final exportsDir = Directory(paths.exportsDir(project.id));
      expect(
        !await exportsDir.exists() ||
            (await exportsDir.list().toList()).isEmpty,
        isTrue,
      );
    }

    test('not asked -> no video', () async {
      final project = await songProject();
      final pack = await repo.export(
        project,
        const ExportOptions(),
        cancel: ExportCancelToken(),
      );
      expect(audio.videoSpecs, isEmpty);
      expect(pack.files.any((f) => f.kind == ExportFileKind.video), isFalse);
    });

    test('asked but not entitled -> no video', () async {
      final project = await songProject();
      final entitlements = FakeEntitlementService()..hasGuideVideo = false;
      final gated = ExportRepositoryImpl(
        audio: audio,
        paths: () async => paths,
        entitlements: entitlements,
      );
      final pack = await gated.export(
        project,
        const ExportOptions(includeVideo: true),
        cancel: ExportCancelToken(),
      );
      expect(audio.videoSpecs, isEmpty);
      expect(pack.files.map((f) => f.kind), [
        ExportFileKind.guide,
        ExportFileKind.song,
      ]);
    });

    test('WAV pack: spec equals planGuideVideo and points at the rendered '
        'guide WAV', () async {
      final project = await songProject();
      final progress = <ExportProgress>[];
      final pack = await repo.export(
        project,
        const ExportOptions(includeVideo: true),
        cancel: ExportCancelToken(),
        onProgress: progress.add,
      );

      expect(audio.videoSpecs, hasLength(1));
      final spec = audio.videoSpecs.single;
      final expectedPlan = planGuideVideo(
        sampleRate: project.sampleRate,
        frameCount: project.sampleCount,
        visibleBeatSamples: [for (final b in project.beats) b.sample],
      );
      expect(spec.fps, 30);
      expect(spec.width, 1080);
      expect(spec.height, 1920);
      expect(spec.totalFrames, expectedPlan.totalFrames);
      expect(spec.totalFrames, 60);
      expect(spec.flashFrames, expectedPlan.flashFrames);
      expect(spec.flashFrames, [7, 15, 30]);
      expect(spec.beatNumbers, [1, 2, 3]);
      expect(spec.videoBitrate, kGuideVideoBitrate);
      expect(spec.audioBitrate, kGuideVideoAudioBitrate);

      // The audio is the rendered guide track (staged), read back from disk
      // when the encoder was called: same rate and frames as the song.
      expect(p.basename(spec.audioWavPath), 'MidnightRun_beats.wav.part');
      final guideInfo = audio.videoAudioInfo.single;
      expect(guideInfo.sampleRate, project.sampleRate);
      expect(guideInfo.frameCount, project.sampleCount);
      expect(guideInfo.channels, 2);
      expect(p.basename(spec.outPath), 'MidnightRun_guide.mp4.part');

      expect(pack.files.map((f) => f.displayName), [
        'MidnightRun_beats.wav',
        'MidnightRun_guide.mp4',
        'MidnightRun_song.wav',
      ]);
      final video = pack.files[1];
      expect(video.kind, ExportFileKind.video);
      expect(video.flashCount, 3);
      expect(await File(video.path).exists(), isTrue);
      final names = [
        for (final e in await Directory(pack.directoryPath).list().toList())
          p.basename(e.path),
      ]..sort();
      expect(names, [
        'MidnightRun_beats.wav',
        'MidnightRun_guide.mp4',
        'MidnightRun_song.wav',
      ]);
      expect(progress.last.overallFraction, 1.0);
    });

    test(
      'M4A pack order: guide WAV -> video -> guide M4A -> WAV deleted',
      () async {
        final project = await songProject();
        final pack = await repo.export(
          project,
          const ExportOptions(includeVideo: true, format: AudioFormat.m4a),
          cancel: ExportCancelToken(),
        );
        expect(audio.events, [
          'video:_transient_guide.wav',
          'm4a:_transient_guide.wav',
          'm4a:song.wav',
        ]);
        expect(audio.videoAudioInfo.single.frameCount, project.sampleCount);
        final names = [
          for (final e in await Directory(pack.directoryPath).list().toList())
            p.basename(e.path),
        ]..sort();
        expect(names, [
          'MidnightRun_beats.m4a',
          'MidnightRun_guide.mp4',
          'MidnightRun_song.m4a',
        ]);
      },
    );

    test('encode_failed on the video -> failure offering export without '
        'video; pack folder removed', () async {
      final project = await songProject();
      audio.videoError = const AudioNativeException(
        AudioErrorKind.encodeFailed,
        'No H.264 encoder',
      );
      await expectLater(
        repo.export(
          project,
          const ExportOptions(includeVideo: true),
          cancel: ExportCancelToken(),
        ),
        throwsA(
          isA<ExportFailureException>()
              .having(
                (e) => e.failure.kind,
                'kind',
                ExportFailureKind.encodeFailed,
              )
              .having((e) => e.failure.isVideoFailure, 'isVideoFailure', isTrue)
              .having(
                (e) => e.failure.message,
                'message',
                'This phone couldn’t make the guide video. Export without it?',
              ),
        ),
      );
      await expectNoPackLeft(project);
    });

    test('a video that fails verification is an encode failure', () async {
      final project = await songProject();
      audio.videoFrameDelta = 1;
      await expectLater(
        repo.export(
          project,
          const ExportOptions(includeVideo: true),
          cancel: ExportCancelToken(),
        ),
        throwsA(
          isA<ExportFailureException>().having(
            (e) => e.failure.isVideoFailure,
            'isVideoFailure',
            isTrue,
          ),
        ),
      );
      await expectNoPackLeft(project);
    });

    test('cancel during the video cancels the native job and removes the '
        'pack folder', () async {
      final project = await songProject();
      final gate = Completer<void>();
      audio.videoGate = gate;
      final token = ExportCancelToken();
      final future = repo.export(
        project,
        const ExportOptions(includeVideo: true),
        cancel: token,
        onProgress: (p) {
          if (audio.videoSpecs.isNotEmpty && !token.isCancelled) {
            // The video job is running (it reported 0.5): cancel now.
            unawaited(token.cancel().then((_) => gate.complete()));
          }
        },
      );
      await expectLater(future, throwsA(isA<ExportCancelledException>()));
      expect(audio.videoJobIds, hasLength(1));
      expect(audio.cancelledJobs, contains(audio.videoJobIds.single));
      await expectNoPackLeft(project);
      await Directory(paths.projectDir(project.id)).delete(recursive: true);
    });

    test('verification helper: duration within one frame of the song', () {
      final plan = planGuideVideo(
        sampleRate: 44100,
        frameCount: 44100 + 1,
        visibleBeatSamples: const [0],
      );
      MediaInfo info({int? videoUs, int? frames, bool video = true}) =>
          MediaInfo(
            sampleRate: 44100,
            channels: 2,
            durationUs: 1000000,
            hasVideo: video,
            videoFrameCount: frames ?? plan.totalFrames,
            videoDurationUs: videoUs ?? plan.durationUs,
          );
      String? check(MediaInfo m) => guideVideoVerificationProblem(
        m,
        plan: plan,
        sampleRate: 44100,
        frameCount: 44101,
        guideChannels: 2,
      );
      expect(plan.totalFrames, 31);
      expect(check(info()), isNull);
      // Song = 1,000,022.7 µs; one frame = 33,334 µs.
      expect(check(info(videoUs: 1000022 + 33334)), isNull);
      expect(check(info(videoUs: 1000023 + 33334)), isNotNull);
      expect(check(info(videoUs: 1000023 - 33334)), isNull);
      expect(check(info(videoUs: 1000022 - 33334)), isNotNull);
      expect(check(info(frames: 30)), isNotNull);
      expect(check(info(video: false)), isNotNull);
    });
  });
}
