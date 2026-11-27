import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:kickvolt/features/settings/settings.dart';

import '../../../fixtures/demo_project.dart';
import '../../../fixtures/editor_fakes.dart';
import '../../../fixtures/export_fakes.dart';

void main() {
  late FakeDemoProjectRepository projectRepo;
  late FakeSettingsRepository settingsRepo;
  late FakeEntitlementService entitlements;
  late RecordingHaptics haptics;
  late FakeShareService shareService;
  late FakeCubitAudioNative audioNative;
  late FakeExportRepository exportRepo;
  late ExportCubit cubit;

  setUp(() {
    projectRepo = FakeDemoProjectRepository();
    settingsRepo = FakeSettingsRepository();
    entitlements = FakeEntitlementService();
    haptics = RecordingHaptics();
    shareService = FakeShareService();
    audioNative = FakeCubitAudioNative();
    exportRepo = FakeExportRepository();
    cubit = ExportCubit(
      repository: exportRepo,
      projectRepository: projectRepo,
      settingsRepository: settingsRepo,
      entitlements: entitlements,
      haptics: haptics,
      shareService: shareService,
      audio: audioNative,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('loads options from settings defaults and updates plan on option changes', () async {
    await settingsRepo.save(
      const AppSettings(
        defaultClickStyle: ClickStyle.kick,
        defaultAudioFormat: AudioFormat.m4a,
        includePreviewByDefault: true,
        monoGuideTrack: true,
      ),
    );

    await cubit.load('demo');
    final s0 = cubit.state as ExportEditing;
    expect(s0.options.clickStyle, ClickStyle.kick);
    expect(s0.options.format, AudioFormat.m4a);
    expect(s0.options.includePreview, isTrue);
    expect(s0.options.monoGuide, isTrue);
    expect(s0.plan.files.length, 3);
    expect(s0.plan.files.first.channels, 1); // mono guide

    // Change options on the Export screen -> plan updates, settings untouched.
    cubit.setClickStyle(ClickStyle.rim);
    cubit.setFormat(AudioFormat.wav);
    cubit.setIncludePreview(false);

    final s1 = cubit.state as ExportEditing;
    expect(s1.options.clickStyle, ClickStyle.rim);
    expect(s1.options.format, AudioFormat.wav);
    expect(s1.options.includePreview, isFalse);
    expect(s1.plan.files.length, 2);
    expect(s1.plan.files.map((f) => f.fileName).toList(), [
      'MidnightRun_beats.wav',
      'MidnightRun_song.wav',
    ]);
    expect(settingsRepo.current.defaultClickStyle, ClickStyle.kick);
  });

  test('export -> progress -> done, recordExport called once, successNotification fired', () async {
    await cubit.load('demo');

    final states = <ExportState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.startExport();
    await sub.cancel();

    expect(states.whereType<ExportExporting>(), isNotEmpty);
    expect(cubit.state, isA<ExportDone>());
    expect(entitlements.recordedCount, 1);
    expect(haptics.events, ['successNotification']);

    // Share and Save to Files on ExportDone.
    await cubit.share();
    expect(shareService.sharedBatches.length, 1);
    expect(shareService.sharedBatches.first.length, 2);

    final saved = await cubit.saveToFiles();
    expect(saved, 2);
    expect((cubit.state as ExportDone).saved, isTrue);
  });

  test('each failure kind transitions to ExportFailed; retry and switchFormatAndRetry work', () async {
    await cubit.load('demo');

    for (final kind in ExportFailureKind.values) {
      exportRepo.nextFailure = ExportFailure(kind: kind);
      await cubit.startExport();
      expect(cubit.state, isA<ExportFailed>());
      expect((cubit.state as ExportFailed).failure.kind, kind);
      expect(entitlements.recordedCount, 0);
      cubit.dismissFailure();
      expect(cubit.state, isA<ExportEditing>());
    }

    // diskFull on WAV -> switchFormatAndRetry switches to M4A and succeeds.
    exportRepo.nextFailure = const ExportFailure(
      kind: ExportFailureKind.diskFull,
    );
    await cubit.startExport();
    expect(cubit.state, isA<ExportFailed>());

    await cubit.switchFormatAndRetry();
    expect(cubit.state, isA<ExportDone>());
    expect((cubit.state as ExportDone).pack.format, AudioFormat.m4a);
    expect(entitlements.recordedCount, 1);
  });

  test('canExport() == false never starts the export', () async {
    entitlements.allowed = false;
    await cubit.load('demo');
    await cubit.startExport();

    expect(exportRepo.calls, isEmpty);
    expect(cubit.state, isA<ExportEditing>());
    expect(entitlements.recordedCount, 0);
  });

  test(
    'cancel stops the running export and returns to ExportEditing',
    () async {
      exportRepo.autoComplete = false;
      await cubit.load('demo');

      final future = cubit.startExport();
      await pumpEventQueue();
      expect(cubit.state, isA<ExportExporting>());

      await cubit.cancel();
      await future;

      expect(cubit.state, isA<ExportEditing>());
      expect(exportRepo.calls.single.cancel.isCancelled, isTrue);
      expect(entitlements.recordedCount, 0);
    },
  );

  group('guide video (M7)', () {
    test('toggle allowed with hasGuideVideo; plan gains the MP4', () async {
      await cubit.load('demo');
      final s0 = cubit.state as ExportEditing;
      expect(s0.videoAllowed, isTrue);
      expect(s0.options.includeVideo, isFalse);

      cubit.setIncludeVideo(true);
      final s1 = cubit.state as ExportEditing;
      expect(s1.options.includeVideo, isTrue);
      expect(s1.plan.files.map((f) => f.fileName), [
        'MidnightRun_beats.wav',
        'MidnightRun_guide.mp4',
        'MidnightRun_song.wav',
      ]);
      expect(s1.plan.guideVideo, isNotNull);

      await cubit.startExport();
      expect(exportRepo.calls.single.options.includeVideo, isTrue);
    });

    test('starts from the "Guide video in packs" setting', () async {
      await settingsRepo.save(const AppSettings(includeVideoByDefault: true));
      await cubit.load('demo');
      expect((cubit.state as ExportEditing).options.includeVideo, isTrue);
    });

    test('without hasGuideVideo: row disabled, toggle ignored, onLocked is '
        'a no-op, setting ignored', () async {
      entitlements.hasGuideVideo = false;
      await settingsRepo.save(const AppSettings(includeVideoByDefault: true));
      await cubit.load('demo');
      final s0 = cubit.state as ExportEditing;
      expect(s0.videoAllowed, isFalse);
      expect(s0.options.includeVideo, isFalse);

      cubit.setIncludeVideo(true);
      cubit.onVideoLocked();
      final s1 = cubit.state as ExportEditing;
      expect(s1.options.includeVideo, isFalse);
      expect(s1.plan.guideVideo, isNull);
    });

    test('video failure -> retry without video', () async {
      await cubit.load('demo');
      cubit.setIncludeVideo(true);
      exportRepo.nextFailure = const ExportFailure(
        kind: ExportFailureKind.encodeFailed,
        failedFile: ExportFileKind.video,
      );
      await cubit.startExport();
      final failed = cubit.state as ExportFailed;
      expect(failed.failure.isVideoFailure, isTrue);
      expect(failed.videoAllowed, isTrue);

      await cubit.retryWithoutVideo();
      expect(exportRepo.calls, hasLength(2));
      expect(exportRepo.calls.last.options.includeVideo, isFalse);
      final done = cubit.state as ExportDone;
      expect(
        done.pack.files.any((f) => f.kind == ExportFileKind.video),
        isFalse,
      );
    });
  });
}
