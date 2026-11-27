import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app_theme.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/core/entitlements/entitlement_service.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/demo_project.dart';
import '../../../fixtures/editor_fakes.dart';
import '../../../fixtures/export_fakes.dart';

Widget _wrap(ExportCubit cubit) {
  return MaterialApp(
    theme: AppTheme.dark(),
    home: ExportScreen(projectId: 'demo', cubit: cubit),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets(
    'Export screen: chips, M4A warning appears/disappears, file list names, '
    'Preview toggle, and unlimited quota hides caption',
    (tester) async {
      setPhoneSize(tester);
      await cubit.load('demo');
      await tester.pumpWidget(_wrap(cubit));

      // Header & title.
      expect(find.text('Export beat pack'), findsOneWidget);
      expect(find.text('Midnight Run'), findsOneWidget);
      expect(find.textContaining('358 beats'), findsOneWidget);

      // Guide video shows Coming soon and NO PRO badge.
      expect(find.text('Guide video'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('PRO'), findsNothing);

      // Default format is WAV: no M4A warning, WAV file names in list.
      expect(find.text(kM4aWarning), findsNothing);
      expect(find.text('MidnightRun_song.wav'), findsOneWidget);
      expect(find.text('MidnightRun_beats.wav'), findsOneWidget);
      expect(find.text('Export 2 files'), findsOneWidget);

      // Unlimited quota -> caption hidden.
      expect(find.textContaining('free exports this week'), findsNothing);

      // Tap M4A -> warning appears and file extensions change to .m4a.
      await tester.tap(find.text('M4A'));
      await tester.pump();
      expect(find.text(kM4aWarning), findsOneWidget);
      expect(find.text('MidnightRun_song.m4a'), findsOneWidget);
      expect(find.text('MidnightRun_beats.m4a'), findsOneWidget);

      // Tap WAV -> warning disappears.
      await tester.tap(find.text('WAV'));
      await tester.pump();
      expect(find.text(kM4aWarning), findsNothing);

      // Tap click sound chips.
      await tester.tap(find.text('Rim'));
      await tester.pump();
      expect((cubit.state as ExportEditing).options.clickStyle, ClickStyle.rim);

      // Toggle Preview mix -> 3 files.
      await tester.tap(find.bySemanticsLabel('Include preview mix'));
      await tester.pump();
      expect(find.text('MidnightRun_preview.wav'), findsOneWidget);
      expect(find.text('Export 3 files'), findsOneWidget);
    },
  );

  testWidgets(
    'Export screen: disabled with 0 beats ("Mark some beats first") and '
    'shows quota caption when quota is finite',
    (tester) async {
      setPhoneSize(tester);
      projectRepo.put(createDemoProject(includeBeats: false));
      entitlements.quota = const ExportQuota.limited(remaining: 25, limit: 30);

      await cubit.load('demo');
      await tester.pumpWidget(_wrap(cubit));

      expect(find.text('Mark some beats first'), findsOneWidget);
      expect(
        find.text('Uses 1 of your 30 free exports this week'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Exporting screen: shows progress, step text, file rows, and Cancel',
    (tester) async {
      setPhoneSize(tester);
      exportRepo.autoComplete = false;
      await cubit.load('demo');
      await tester.pumpWidget(_wrap(cubit));

      await tester.tap(find.text('Export 2 files'));
      await tester.pump();

      expect(find.text('Building your beat pack'), findsOneWidget);
      exportRepo.lastOnProgress?.call(
        const ExportProgress(
          overallFraction: 0.72,
          stepText: 'Placing 358 clicks…',
          files: [
            ExportFileProgress(
              kind: ExportFileKind.guide,
              fileName: 'MidnightRun_beats.wav',
              fraction: 0.44,
              completed: false,
            ),
            ExportFileProgress(
              kind: ExportFileKind.song,
              fileName: 'MidnightRun_song.wav',
              fraction: 1.0,
              completed: true,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('72%'), findsOneWidget);
      expect(find.text('Placing 358 clicks…'), findsOneWidget);
      expect(find.text('44%'), findsOneWidget);
      expect(find.text('MidnightRun_beats.wav'), findsOneWidget);
      expect(find.text('MidnightRun_song.wav'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Export beat pack'), findsOneWidget);
    },
  );

  testWidgets(
    'ExportFailed screen: shows exact copy and action buttons for each failure',
    (tester) async {
      setPhoneSize(tester);
      await cubit.load('demo');
      await tester.pumpWidget(_wrap(cubit));

      // 1. diskFull on WAV -> Try again, Switch to M4A and retry, Cancel.
      exportRepo.nextFailure = const ExportFailure(
        kind: ExportFailureKind.diskFull,
        failedFileLabel: 'the guide track',
        neededMegabytes: 40,
      );
      await cubit.startExport();
      await tester.pump();

      expect(find.text('Export didn’t finish'), findsOneWidget);
      expect(
        find.text(
          'Your phone ran out of space while saving the guide track. Free up '
          'about 40 MB, or save as M4A instead of WAV (much smaller).',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Switch to M4A and retry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // 2. interrupted -> Try again, Cancel.
      cubit.dismissFailure();
      exportRepo.nextFailure = const ExportFailure(
        kind: ExportFailureKind.interrupted,
      );
      await cubit.startExport();
      await tester.pump();
      expect(
        find.text(
          'The export stopped when KickVolt was closed. Try again and keep the '
          'app open until it’s done.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Switch to M4A and retry'), findsNothing);

      // 3. encodeFailed -> Switch to WAV and retry, Cancel.
      cubit.dismissFailure();
      cubit.setFormat(AudioFormat.m4a);
      exportRepo.nextFailure = const ExportFailure(
        kind: ExportFailureKind.encodeFailed,
      );
      await cubit.startExport();
      await tester.pump();
      expect(
        find.text(
          'This phone couldn’t make an M4A of this song. WAV works everywhere.',
        ),
        findsOneWidget,
      );
      expect(find.text('Switch to WAV and retry'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      // 4. sourceMissing -> only Cancel (no Try again).
      cubit.dismissFailure();
      exportRepo.nextFailure = const ExportFailure(
        kind: ExportFailureKind.sourceMissing,
      );
      await cubit.startExport();
      await tester.pump();
      expect(
        find.text('The song’s audio file is missing. Re-import the song.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  testWidgets(
    'ExportSuccess screen: Share calls ShareService with all paths, Save to '
    'Files calls saveToFiles and updates subtitle, no Open in CapCut/VN',
    (tester) async {
      setPhoneSize(tester);
      await cubit.load('demo');
      await cubit.startExport();
      await tester.pumpWidget(_wrap(cubit));

      expect(find.text('Beat pack ready'), findsOneWidget);
      expect(find.text('Ready to share'), findsOneWidget);
      expect(find.text('Open in CapCut'), findsNothing);
      expect(find.text('Open in VN'), findsNothing);
      expect(find.text('How to use it in CapCut and VN'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pump();
      expect(shareService.sharedBatches.length, 1);
      expect(shareService.sharedBatches.single, [
        '/fake/exports/20261126-120000/MidnightRun_beats.wav',
        '/fake/exports/20261126-120000/MidnightRun_song.wav',
      ]);

      await tester.tap(find.text('Save to Files'));
      await tester.pump();
      expect(audioNative.saveCalls.length, 1);
      expect(audioNative.saveCalls.single, [
        '/fake/exports/20261126-120000/MidnightRun_beats.wav',
        '/fake/exports/20261126-120000/MidnightRun_song.wav',
      ]);
      expect(find.text('Saved to the folder you picked'), findsOneWidget);
      expect(find.text('Saved 2 files'), findsOneWidget);
    },
  );
}
