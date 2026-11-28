import 'package:flutter/rendering.dart' show RenderBox, RenderFlex;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app_theme.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/settings/settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/demo_project.dart';
import '../../../fixtures/editor_fakes.dart';
import '../../playback/fake_audio_playback.dart';

/// Regression: on a 360 dp wide phone (Xiaomi 23106RN0DA, 720 px @ 320 dpi)
/// the editor's transport row (speed control + 48/64/48 px buttons, all
/// fixed widths) overflowed by 4 px. Found by the on-device integration
/// tests, 2026-11-27.
///
/// Only the [TransportBar] row is measured: host tests render
/// text with a fallback font, so text-driven sizes elsewhere don't match a
/// phone.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('transport row fits at $width dp wide', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final project = createDemoProject();
      final settings = FakeSettingsRepository(
        const AppSettings(coachMarksDone: true),
      );
      final outputRoute = FakeOutputRouteService(kind: OutputKind.builtIn);
      addTearDown(outputRoute.dispose);
      final cubit = BeatEditorCubit(
        repository: FakeDemoProjectRepository(project),
        playback: FakeAudioPlayback(),
        clickPreviewRepository: FakeClickPreviewRepository(),
        settingsRepository: settings,
        outputRouteService: outputRoute,
        haptics: RecordingHaptics(settings: settings),
        saveDebounce: Duration.zero,
      );
      await cubit.load(project.id);

      // Text-driven overflows elsewhere (fallback test font) are not this
      // test's concern; keep them from failing it.
      final previous = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: BeatEditorScreen(projectId: project.id, cubit: cubit),
          ),
        );
        await tester.pump();
      } finally {
        FlutterError.onError = previous;
      }

      expect(find.byType(TransportBar), findsOneWidget);
      // The transport's top-level Row: its children must fit inside it.
      final row = tester.renderObject<RenderFlex>(
        find
            .descendant(
              of: find.byType(TransportBar),
              matching: find.byType(Row),
            )
            .first,
      );
      var childrenWidth = 0.0;
      row.visitChildren((c) => childrenWidth += (c as RenderBox).size.width);
      expect(
        childrenWidth,
        lessThanOrEqualTo(row.size.width),
        reason: 'transport row overflows by ${childrenWidth - row.size.width}',
      );
    });
  }
}
