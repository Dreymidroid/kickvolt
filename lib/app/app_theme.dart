import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/styles/kv_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    const c = KvColors.dark;
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final inter = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: c.text1, displayColor: c.text1);
    TextStyle? grotesk(TextStyle? s) =>
        GoogleFonts.spaceGrotesk(textStyle: s, fontWeight: FontWeight.w700);

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      colorScheme: ColorScheme.dark(
        primary: c.volt,
        onPrimary: c.onVolt,
        secondary: c.sectionVerse,
        onSecondary: c.onVolt,
        surface: c.surface1,
        onSurface: c.text1,
        onSurfaceVariant: c.text2,
        surfaceContainerLow: c.surface1,
        surfaceContainer: c.surface2,
        surfaceContainerHigh: c.surface3,
        outline: c.border,
        outlineVariant: c.border,
        error: c.error,
        onError: c.onVolt,
      ),
      textTheme: inter.copyWith(
        displayLarge: grotesk(inter.displayLarge),
        displayMedium: grotesk(inter.displayMedium),
        displaySmall: grotesk(inter.displaySmall),
        headlineLarge: grotesk(inter.headlineLarge),
        headlineMedium: grotesk(inter.headlineMedium),
        headlineSmall: grotesk(inter.headlineSmall),
      ),
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.volt,
          foregroundColor: c.onVolt,
          minimumSize: const Size(44, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      extensions: const [c],
    );
  }
}
