import 'package:freezed_annotation/freezed_annotation.dart';

part 'section.freezed.dart';

@freezed
abstract class Section with _$Section {
  const factory Section({
    required int startSample,
    required int endSample,
    required String name,
    required int colorArgb,
  }) = _Section;
}

/// Default section presets and their HANDOFF design token colours.
class SectionPreset {
  const SectionPreset({required this.name, required this.colorArgb});

  final String name;
  final int colorArgb;

  static const intro = SectionPreset(name: 'Intro', colorArgb: 0xFF9B8CFF);
  static const verse = SectionPreset(name: 'Verse', colorArgb: 0xFF45D4FF);
  static const build = SectionPreset(name: 'Build', colorArgb: 0xFFFF6FB5);
  static const drop = SectionPreset(name: 'Drop', colorArgb: 0xFFFF8A4C);
  static const outro = SectionPreset(name: 'Outro', colorArgb: 0xFF9B8CFF);

  static const List<SectionPreset> all = [intro, verse, build, drop, outro];
}

const List<SectionPreset> sectionPresets = SectionPreset.all;
