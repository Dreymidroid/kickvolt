import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Space Grotesk for headings, Inter for UI, JetBrains Mono for times, BPM
/// and counts.
abstract final class KvText {
  static TextStyle heading({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  static TextStyle ui({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Every family/weight the app uses, so they can be loaded before first
  /// paint (CustomPainter text won't repaint when a font arrives late).
  static List<TextStyle> get preload => [
    for (final w in [FontWeight.w400, FontWeight.w600, FontWeight.w700])
      ui(weight: w),
    ui(weight: FontWeight.w800),
    for (final w in [FontWeight.w400, FontWeight.w600, FontWeight.w700])
      mono(weight: w),
    heading(),
    heading(weight: FontWeight.w600),
  ];
}
