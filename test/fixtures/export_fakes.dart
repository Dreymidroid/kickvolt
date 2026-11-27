import 'dart:async';
import 'dart:ui' show Rect;

import 'package:kickvolt/core/audio_native/audio_native_client.dart';
import 'package:kickvolt/core/entitlements/entitlement_service.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:kickvolt/features/projects/projects.dart';

class FakeEntitlementService implements EntitlementService {
  bool allowed = true;
  ExportQuota quota = const ExportQuota.unlimited();
  int recordedCount = 0;

  @override
  Stream<Entitlements> get changes => const Stream.empty();

  @override
  Future<Entitlements> current() async => const Entitlements();

  @override
  Future<ExportQuota> exportQuota() async => quota;

  @override
  Future<bool> canExport() async => allowed;

  @override
  Future<void> recordExport() async {
    recordedCount++;
  }
}

class FakeShareService implements ShareService {
  final sharedBatches = <List<String>>[];
  final origins = <Rect?>[];

  @override
  Future<void> shareFiles(
    List<String> paths, {
    Rect? sharePositionOrigin,
  }) async {
    sharedBatches.add(List<String>.of(paths));
    origins.add(sharePositionOrigin);
  }
}

class FakeExportRepository implements ExportRepository {
  bool autoComplete = true;
  ExportFailure? nextFailure;
  Object? nextRawError;
  final calls =
      <({Project project, ExportOptions options, ExportCancelToken cancel})>[];
  void Function(ExportProgress)? lastOnProgress;
  Completer<BeatPack>? pendingCompleter;

  static BeatPack makeDummyPack(Project project, ExportOptions options) {
    final plan = planBeatPack(project, options);
    return BeatPack(
      projectId: project.id,
      packId: '20261126-120000',
      directoryPath: '/fake/exports/20261126-120000',
      format: options.format,
      sampleRate: project.sampleRate,
      frameCount: project.sampleCount,
      durationMs: project.durationMs,
      clickCount: plan.clickCount,
      files: [
        for (final f in plan.files)
          ExportedFile(
            path: '/fake/exports/20261126-120000/${f.fileName}',
            kind: f.kind,
            displayName: f.fileName,
            frameCount: f.frameCount,
            byteSize: f.estimatedWavBytes,
            clickCount: f.clickCount,
          ),
      ],
    );
  }

  @override
  Future<BeatPack> export(
    Project project,
    ExportOptions options, {
    required ExportCancelToken cancel,
    void Function(ExportProgress)? onProgress,
  }) async {
    calls.add((project: project, options: options, cancel: cancel));
    lastOnProgress = onProgress;

    if (nextFailure != null) {
      final f = nextFailure!;
      nextFailure = null;
      throw ExportFailureException(f);
    }
    if (nextRawError != null) {
      final err = nextRawError!;
      nextRawError = null;
      throw err;
    }

    if (!autoComplete) {
      final c = Completer<BeatPack>();
      pendingCompleter = c;
      cancel.addHandler(() async {
        if (!c.isCompleted) {
          c.completeError(const ExportCancelledException());
        }
      });
      return c.future;
    }

    onProgress?.call(
      const ExportProgress(
        overallFraction: 0.5,
        stepText: 'Placing 358 clicks…',
        files: [],
      ),
    );
    return makeDummyPack(project, options);
  }

  @override
  Future<void> cleanUpStaleParts() async {}

  @override
  Future<List<BeatPack>> packsFor(String projectId) async => const [];
}

class FakeCubitAudioNative implements AudioNative {
  int savedResult = 2;
  final saveCalls = <List<String>>[];

  @override
  Future<int> saveToFiles(List<String> paths) async {
    saveCalls.add(List<String>.of(paths));
    return savedResult;
  }

  @override
  Future<int> beginBackgroundWork(String name) async => 0;

  @override
  Future<void> endBackgroundWork(int token) async {}

  @override
  Future<void> cancel(String jobId) async {}

  @override
  Future<void> copyContentUri(String uri, String destPath) async {}

  @override
  Future<DecodeResult> decodeToWav({
    required String jobId,
    required String inputPath,
    required String outputPath,
    void Function(double fraction)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<MediaInfo> encodeM4a({
    required String jobId,
    required String wavPath,
    required String outPath,
    int bitrate = kDefaultM4aBitrate,
    void Function(double fraction)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<int> freeDiskBytes(String path) async => 1 << 40;

  @override
  Future<List<LibraryTrack>> listMusicLibrary() async => const [];

  @override
  Future<bool> requestAudioPermission() async => true;

  @override
  Future<LibraryTrack?> pickFromMusicLibrary() async => null;

  @override
  Future<MediaInfo> probeMedia(String path) => throw UnimplementedError();
}
