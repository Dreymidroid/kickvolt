import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app_constants.dart';
import 'package:kickvolt/app/app_theme.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:kickvolt/features/settings/settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/editor_fakes.dart';

class _Links implements ExternalLinkService {
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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeSettingsRepository repo;
  late _Links links;

  setUp(() {
    repo = FakeSettingsRepository();
    links = _Links();
  });

  /// The toggle's own `Semantics(toggled:)` node (the row's list-item
  /// semantics carries the same label).
  Finder toggle(String label) => find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.label == label &&
        w.properties.toggled != null,
  );

  Future<SettingsCubit> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // SettingsScreen's BlocProvider(create:) owns the cubit and closes it on
    // unmount. Closing it again in addTearDown runs outside fake time and
    // never completes (the test hangs until its timeout).
    final cubit = SettingsCubit(repository: repo, linkService: links)..load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: SettingsScreen(cubit: cubit),
      ),
    );
    await tester.pump();
    return cubit;
  }

  testWidgets('rows: no Theme row, no Pro banner, no video rows', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Click sound'), findsOneWidget);
    expect(find.text('Audio format'), findsOneWidget);
    expect(find.text('Mono guide track (smaller file)'), findsOneWidget);
    expect(find.text('Preview mix in packs'), findsOneWidget);
    expect(find.text('Detection sensitivity'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Haptics'), findsOneWidget);
    expect(find.text('Tap timing (lag fix)'), findsOneWidget);
    expect(find.text('KickVolt v${AppConstants.appVersion}'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.textContaining('Pro'), findsNothing);
    expect(find.text('Video format'), findsNothing);
    expect(find.text('Guide video in packs'), findsNothing);
  });

  testWidgets('pickers and toggles persist immediately', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Click sound'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rim'));
    await tester.pumpAndSettle();
    expect(repo.current.defaultClickStyle, ClickStyle.rim);

    await tester.tap(find.text('Audio format'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M4A'));
    await tester.pumpAndSettle();
    expect(repo.current.defaultAudioFormat, AudioFormat.m4a);

    await tester.tap(find.text('Detection sensitivity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    expect(repo.current.defaultSensitivity, 0.75);

    await tester.tap(toggle('Haptics'));
    await tester.pump();
    expect(repo.current.hapticsEnabled, isFalse);

    await tester.tap(toggle('Mono guide track (smaller file)'));
    await tester.pump();
    expect(repo.current.monoGuideTrack, isTrue);

    await tester.tap(toggle('Preview mix in packs'));
    await tester.pump();
    expect(repo.current.includePreviewByDefault, isTrue);
  });

  testWidgets('feedback and privacy open the configured links', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Send feedback'));
    await tester.tap(find.text('Send feedback'));
    await tester.pump();
    await tester.tap(find.text('Privacy'));
    await tester.pump();
    expect(links.opened, [
      'mail:${AppConstants.feedbackEmail}',
      AppConstants.privacyUrl,
    ]);
  });
}
