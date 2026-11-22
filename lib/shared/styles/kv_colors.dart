import 'package:material_ui/material_ui.dart';

import '../../features/beat_editor/domain/entities/song_section.dart';

/// Design tokens from design/kickvolt-design/HANDOFF.md.
@immutable
class KvColors extends ThemeExtension<KvColors> {
  const KvColors({
    required this.background,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.volt,
    required this.onVolt,
    required this.error,
    required this.warning,
    required this.sectionIntro,
    required this.sectionVerse,
    required this.sectionBuild,
    required this.sectionDrop,
    required this.wavePlayed,
    required this.waveUnplayed,
    required this.waveOverview,
    required this.waveGlow,
  });

  static const dark = KvColors(
    background: Color(0xFF0B0B10),
    surface1: Color(0xFF14141C),
    surface2: Color(0xFF1C1C27),
    surface3: Color(0xFF272735),
    border: Color(0xFF2C2C3C),
    text1: Color(0xFFF4F4F8),
    text2: Color(0xFFA6A6B8),
    text3: Color(0xFF8A8AA0),
    volt: Color(0xFFC6FF3D),
    onVolt: Color(0xFF0B0B10),
    error: Color(0xFFFF6B6B),
    warning: Color(0xFFFF8A4C),
    sectionIntro: Color(0xFF9B8CFF),
    sectionVerse: Color(0xFF45D4FF),
    sectionBuild: Color(0xFFFF6FB5),
    sectionDrop: Color(0xFFFF8A4C),
    wavePlayed: Color(0xFFECEAFF),
    waveUnplayed: Color(0xFF7D7AA8),
    waveOverview: Color(0xFF8F8CB8),
    waveGlow: Color(0x47AAA0FF), // rgba(170,160,255,.28)
  );

  final Color background;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color text1;
  final Color text2;
  final Color text3;

  /// Beats, primary actions, focus. Text on it uses [onVolt].
  final Color volt;
  final Color onVolt;
  final Color error;
  final Color warning;
  final Color sectionIntro;
  final Color sectionVerse;
  final Color sectionBuild;
  final Color sectionDrop;
  final Color wavePlayed;
  final Color waveUnplayed;
  final Color waveOverview;
  final Color waveGlow;

  /// Strong-beat / marker glow: drop-shadow 0 0 6px volt @ 75%.
  Color get voltGlow => volt.withValues(alpha: 0.75);

  /// Primary button glow: 0 0 28px volt @ 28%.
  List<BoxShadow> get primaryGlow => [
    BoxShadow(color: volt.withValues(alpha: 0.28), blurRadius: 28),
  ];

  Color section(SectionKind kind) => switch (kind) {
    SectionKind.intro || SectionKind.outro => sectionIntro,
    SectionKind.verse => sectionVerse,
    SectionKind.build => sectionBuild,
    SectionKind.drop => sectionDrop,
  };

  @override
  KvColors copyWith({
    Color? background,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? volt,
    Color? onVolt,
    Color? error,
    Color? warning,
    Color? sectionIntro,
    Color? sectionVerse,
    Color? sectionBuild,
    Color? sectionDrop,
    Color? wavePlayed,
    Color? waveUnplayed,
    Color? waveOverview,
    Color? waveGlow,
  }) {
    return KvColors(
      background: background ?? this.background,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      text1: text1 ?? this.text1,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      volt: volt ?? this.volt,
      onVolt: onVolt ?? this.onVolt,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      sectionIntro: sectionIntro ?? this.sectionIntro,
      sectionVerse: sectionVerse ?? this.sectionVerse,
      sectionBuild: sectionBuild ?? this.sectionBuild,
      sectionDrop: sectionDrop ?? this.sectionDrop,
      wavePlayed: wavePlayed ?? this.wavePlayed,
      waveUnplayed: waveUnplayed ?? this.waveUnplayed,
      waveOverview: waveOverview ?? this.waveOverview,
      waveGlow: waveGlow ?? this.waveGlow,
    );
  }

  @override
  KvColors lerp(KvColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return KvColors(
      background: l(background, other.background),
      surface1: l(surface1, other.surface1),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      border: l(border, other.border),
      text1: l(text1, other.text1),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      volt: l(volt, other.volt),
      onVolt: l(onVolt, other.onVolt),
      error: l(error, other.error),
      warning: l(warning, other.warning),
      sectionIntro: l(sectionIntro, other.sectionIntro),
      sectionVerse: l(sectionVerse, other.sectionVerse),
      sectionBuild: l(sectionBuild, other.sectionBuild),
      sectionDrop: l(sectionDrop, other.sectionDrop),
      wavePlayed: l(wavePlayed, other.wavePlayed),
      waveUnplayed: l(waveUnplayed, other.waveUnplayed),
      waveOverview: l(waveOverview, other.waveOverview),
      waveGlow: l(waveGlow, other.waveGlow),
    );
  }
}

extension KvColorsContext on BuildContext {
  KvColors get kv => Theme.of(this).extension<KvColors>()!;
}
