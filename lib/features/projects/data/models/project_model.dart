import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../import/domain/entities/picked_source.dart';
import '../../domain/entities/beat.dart';
import '../../domain/entities/detection_settings.dart';

part 'project_model.freezed.dart';
part 'project_model.g.dart';

const int currentProjectSchemaVersion = 2;

@freezed
abstract class ProjectModel with _$ProjectModel {
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory ProjectModel({
    @Default(currentProjectSchemaVersion) int schemaVersion,
    required String id,
    required String title,
    required ProjectSourceModel source,
    required int sampleRate,
    required int channels,
    required int sampleCount,
    @Default(<BeatModel>[]) List<BeatModel> beats,
    @Default(<SectionModel>[]) List<SectionModel> sections,
    double? bpm,
    int? beatPhaseSample,
    @Default(DetectionSettingsModel()) DetectionSettingsModel detection,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ProjectModel;

  factory ProjectModel.fromJson(Map<String, dynamic> json) =>
      _$ProjectModelFromJson(json);
}

@freezed
abstract class ProjectSourceModel with _$ProjectSourceModel {
  const factory ProjectSourceModel({
    required ImportSourceKind kind,
    required String originalName,
    String? copiedFileName,
  }) = _ProjectSourceModel;

  factory ProjectSourceModel.fromJson(Map<String, dynamic> json) =>
      _$ProjectSourceModelFromJson(json);
}

@freezed
abstract class BeatModel with _$BeatModel {
  const factory BeatModel({
    required int sample,
    @Default(BeatType.beat) BeatType type,
  }) = _BeatModel;

  factory BeatModel.fromJson(Map<String, dynamic> json) =>
      _$BeatModelFromJson(json);
}

@freezed
abstract class SectionModel with _$SectionModel {
  const factory SectionModel({
    required int startSample,
    required int endSample,
    required String name,
    required int colorArgb,
  }) = _SectionModel;

  factory SectionModel.fromJson(Map<String, dynamic> json) =>
      _$SectionModelFromJson(json);
}

@freezed
abstract class DetectionSettingsModel with _$DetectionSettingsModel {
  const factory DetectionSettingsModel({
    @Default(0.5) double sensitivity,
    @Default(BeatFilter.every) BeatFilter filter,
    @Default(DetectionStatus.notRun) DetectionStatus status,
    @Default(TempoMode.steady) TempoMode tempoMode,
    double? tempoOverrideBpm,
  }) = _DetectionSettingsModel;

  factory DetectionSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$DetectionSettingsModelFromJson(json);
}

@freezed
abstract class ProjectSummaryModel with _$ProjectSummaryModel {
  const factory ProjectSummaryModel({
    required String id,
    required String title,
    required int beatCount,
    double? bpm,
    required int sampleRate,
    required int sampleCount,
    required DateTime updatedAt,
    @Default(<int>[]) List<int> thumbnail,
  }) = _ProjectSummaryModel;

  factory ProjectSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$ProjectSummaryModelFromJson(json);
}

@freezed
abstract class ProjectIndexModel with _$ProjectIndexModel {
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory ProjectIndexModel({
    @Default(currentProjectSchemaVersion) int schemaVersion,
    @Default(<ProjectSummaryModel>[]) List<ProjectSummaryModel> projects,
  }) = _ProjectIndexModel;

  factory ProjectIndexModel.fromJson(Map<String, dynamic> json) =>
      _$ProjectIndexModelFromJson(json);
}
