import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app_theme.dart';
import 'package:kickvolt/features/how_to/how_to.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, HowToTab tab) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: HowToScreen(initialTab: tab),
      ),
    );
    await tester.pump();
  }

  bool hasRich(String s) => find
      .byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(s),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('CapCut tab: four steps, Auto generate, no Open buttons', (
    tester,
  ) async {
    await pump(tester, HowToTab.capCut);
    expect(find.text('Import both files'), findsOneWidget);
    expect(find.text('Mute the guide'), findsOneWidget);
    expect(hasRich('Auto generate'), isTrue);
    expect(find.text('Open CapCut'), findsNothing);
    expect(find.textContaining('Bulk › Shift all beats'), findsOneWidget);
  });

  testWidgets('VN tab: corrected copy, Auto Beats, no Open VN', (tester) async {
    await pump(tester, HowToTab.capCut);
    await tester.tap(find.text('VN'));
    await tester.pump();
    expect(hasRich('Auto Beats'), isTrue);
    expect(hasRich('Then tap ✓'), isTrue);
    expect(hasRich('Music › Yours › ⋮ › File App'), isTrue);
    expect(hasRich('choose auto-detect'), isFalse);
    expect(find.text('Open VN'), findsNothing);
  });

  testWidgets('initialTab VN opens the VN guide', (tester) async {
    await pump(tester, HowToTab.vn);
    expect(hasRich('Auto Beats'), isTrue);
  });
}
