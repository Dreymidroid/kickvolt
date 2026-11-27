import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app_theme.dart';
import 'package:kickvolt/features/beat_editor/presentation/widgets/coach_marks_overlay.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<int Function()> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final wave = GlobalKey();
    final tools = GlobalKey();
    final exp = GlobalKey();
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 60,
                right: 8,
                child: SizedBox(key: exp, width: 86, height: 40),
              ),
              Positioned(
                top: 140,
                left: 0,
                right: 0,
                height: 290,
                child: SizedBox(key: wave),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 84,
                child: SizedBox(key: tools),
              ),
              Positioned.fill(
                child: CoachMarksOverlay(
                  waveformKey: wave,
                  toolsKey: tools,
                  exportPillKey: exp,
                  onDismissed: () => dismissed++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return () => dismissed;
  }

  testWidgets('three steps then Got it dismisses', (tester) async {
    final dismissed = await pump(tester);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Your beats live here'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Pick how you mark'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('Export when it looks right'), findsOneWidget);
    expect(dismissed(), 0);
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(dismissed(), 1);
  });

  testWidgets('Skip tips dismisses immediately', (tester) async {
    final dismissed = await pump(tester);
    await tester.tap(find.text('Skip tips'));
    await tester.pump();
    expect(dismissed(), 1);
  });
}
