import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_summary.freezed.dart';

/// Lightweight project metadata stored in `index.json` for the Home list.
@freezed
abstract class ProjectSummary with _$ProjectSummary {
  const ProjectSummary._();

  const factory ProjectSummary({
    required String id,
    required String title,
    required int beatCount,
    double? bpm,
    required int sampleRate,
    required int sampleCount,
    required DateTime updatedAt,
    @Default(<int>[]) List<int> thumbnail,
  }) = _ProjectSummary;

  /// Display duration in milliseconds, derived from [sampleCount] and [sampleRate].
  int get durationMs => sampleRate > 0 ? sampleCount * 1000 ~/ sampleRate : 0;
}
