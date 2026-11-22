import 'package:freezed_annotation/freezed_annotation.dart';

part 'song_section.freezed.dart';

enum SectionKind { intro, verse, build, drop, outro }

@freezed
abstract class SongSection with _$SongSection {
  const factory SongSection({
    required int startMs,
    required int endMs,
    required SectionKind kind,
  }) = _SongSection;
}
