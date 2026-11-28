import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app.dart';
import 'package:kickvolt/app/app_router.dart';
import 'package:kickvolt/core/audio_native/audio_native_client.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:kickvolt/features/settings/settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/editor_fakes.dart';
import '../fixtures/export_fakes.dart';

class _MockProjectRepository extends Mock implements ProjectRepository {}

class _MockSourcePicker extends Mock implements SourcePicker {}

class _FakeLinks implements ExternalLinkService {
  final opened = <String>[];

  @override
  Future<bool> openFeedbackEmail(String email) async {
    opened.add('mail:$email');
    return true;
  }

  @override
  Future<bool> openPrivacyPolicy(String url) async {
    opened.add(url);
    return true;
  }
}

class _RecordingAudio extends FakeCubitAudioNative {
  int permissionCalls = 0;

  @override
  Future<bool> requestAudioPermission() async {
    permissionCalls++;
    return true;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeSettingsRepository settings;
  late _RecordingAudio audio;

  setUp(() {
    final loc = GetIt.instance;
    loc.reset();
    settings = FakeSettingsRepository();
    audio = _RecordingAudio();
    final projects = _MockProjectRepository();
    when(projects.listProjects).thenAnswer((_) async => const []);
    loc.registerSingleton<SettingsRepository>(settings);
    loc.registerSingleton<ExternalLinkService>(_FakeLinks());
    loc.registerSingleton<ProjectRepository>(projects);
    loc.registerSingleton<SourcePicker>(_MockSourcePicker());
    loc.registerSingleton<AudioNative>(audio);
  });

  tearDown(() => GetIt.instance.reset());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      KickVoltApp(router: AppRouter(settingsRepository: settings)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first run opens Onboarding, never Home', (tester) async {
    await pumpApp(tester);
    expect(find.text('CapCut misses your beats.'), findsOneWidget);
    expect(find.text('Projects'), findsNothing);
    expect(find.text('No beat packs yet'), findsNothing);
  });

  testWidgets('onboardingDone opens Home directly', (tester) async {
    await settings.save(const AppSettings(onboardingDone: true));
    await pumpApp(tester);
    expect(find.text('CapCut misses your beats.'), findsNothing);
    expect(find.text('No beat packs yet'), findsOneWidget);
  });

  testWidgets('onboarding flow: 3 pages, no PRO, Allow access -> Home', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Mark once. Export a beat pack.'), findsOneWidget);
    expect(find.text('PRO'), findsNothing);
    // M7 is in: the beat-pack card shows the Video tile (no PRO badge).
    expect(find.text('Video'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Let KickVolt reach your music.'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);

    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    expect(audio.permissionCalls, 1);
    expect(settings.current.onboardingDone, isTrue);
    expect(find.text('No beat packs yet'), findsOneWidget);
  });

  testWidgets('Skip on page 1 and Not now on page 3 set onboardingDone', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(settings.current.onboardingDone, isTrue);
    expect(audio.permissionCalls, 0);
    expect(find.text('No beat packs yet'), findsOneWidget);
  });

  testWidgets('Not now on page 3 sets onboardingDone without a prompt', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(audio.permissionCalls, 0);
    expect(settings.current.onboardingDone, isTrue);
    expect(find.text('No beat packs yet'), findsOneWidget);
  });

  testWidgets('Home: no "free left" chip; buttons route', (tester) async {
    await settings.save(const AppSettings(onboardingDone: true));
    await pumpApp(tester);
    expect(find.textContaining('free left'), findsNothing);

    await tester.tap(find.text('How beat packs work'));
    await tester.pumpAndSettle();
    expect(find.text('Use your beat pack'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Export defaults'.toUpperCase()), findsOneWidget);
  });

  testWidgets('No Pro / free-left text on Home, Settings, onboarding', (
    tester,
  ) async {
    final bad = [
      find.textContaining('PRO'),
      find.textContaining('Pro'),
      find.textContaining('free left'),
      find.textContaining('free exports'),
    ];
    await pumpApp(tester);
    for (var i = 0; i < 2; i++) {
      for (final f in bad) {
        expect(f, findsNothing);
      }
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    for (final f in bad) {
      expect(f, findsNothing);
    }
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    for (final f in bad) {
      expect(f, findsNothing);
    }
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    for (final f in bad) {
      expect(f, findsNothing);
    }
  });
}
