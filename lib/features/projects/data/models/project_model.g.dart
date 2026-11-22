// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectModel _$ProjectModelFromJson(
  Map<String, dynamic> json,
) => _ProjectModel(
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ?? currentProjectSchemaVersion,
  id: json['id'] as String,
  title: json['title'] as String,
  source: ProjectSourceModel.fromJson(json['source'] as Map<String, dynamic>),
  sampleRate: (json['sampleRate'] as num).toInt(),
  channels: (json['channels'] as num).toInt(),
  sampleCount: (json['sampleCount'] as num).toInt(),
  beats:
      (json['beats'] as List<dynamic>?)
          ?.map((e) => BeatModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <BeatModel>[],
  sections:
      (json['sections'] as List<dynamic>?)
          ?.map((e) => SectionModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SectionModel>[],
  bpm: (json['bpm'] as num?)?.toDouble(),
  beatPhaseSample: (json['beatPhaseSample'] as num?)?.toInt(),
  detection: json['detection'] == null
      ? const DetectionSettingsModel()
      : DetectionSettingsModel.fromJson(
          json['detection'] as Map<String, dynamic>,
        ),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ProjectModelToJson(_ProjectModel instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'id': instance.id,
      'title': instance.title,
      'source': instance.source.toJson(),
      'sampleRate': instance.sampleRate,
      'channels': instance.channels,
      'sampleCount': instance.sampleCount,
      'beats': instance.beats.map((e) => e.toJson()).toList(),
      'sections': instance.sections.map((e) => e.toJson()).toList(),
      'bpm': instance.bpm,
      'beatPhaseSample': instance.beatPhaseSample,
      'detection': instance.detection.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_ProjectSourceModel _$ProjectSourceModelFromJson(Map<String, dynamic> json) =>
    _ProjectSourceModel(
      kind: $enumDecode(_$ImportSourceKindEnumMap, json['kind']),
      originalName: json['originalName'] as String,
      copiedFileName: json['copiedFileName'] as String?,
    );

Map<String, dynamic> _$ProjectSourceModelToJson(_ProjectSourceModel instance) =>
    <String, dynamic>{
      'kind': _$ImportSourceKindEnumMap[instance.kind]!,
      'originalName': instance.originalName,
      'copiedFileName': instance.copiedFileName,
    };

const _$ImportSourceKindEnumMap = {
  ImportSourceKind.file: 'file',
  ImportSourceKind.library: 'library',
  ImportSourceKind.video: 'video',
};

_BeatModel _$BeatModelFromJson(Map<String, dynamic> json) => _BeatModel(
  sample: (json['sample'] as num).toInt(),
  type: $enumDecodeNullable(_$BeatTypeEnumMap, json['type']) ?? BeatType.beat,
);

Map<String, dynamic> _$BeatModelToJson(_BeatModel instance) =>
    <String, dynamic>{
      'sample': instance.sample,
      'type': _$BeatTypeEnumMap[instance.type]!,
    };

const _$BeatTypeEnumMap = {
  BeatType.beat: 'beat',
  BeatType.strong: 'strong',
  BeatType.drop: 'drop',
  BeatType.downbeat: 'downbeat',
};

_SectionModel _$SectionModelFromJson(Map<String, dynamic> json) =>
    _SectionModel(
      startSample: (json['startSample'] as num).toInt(),
      endSample: (json['endSample'] as num).toInt(),
      name: json['name'] as String,
      colorArgb: (json['colorArgb'] as num).toInt(),
    );

Map<String, dynamic> _$SectionModelToJson(_SectionModel instance) =>
    <String, dynamic>{
      'startSample': instance.startSample,
      'endSample': instance.endSample,
      'name': instance.name,
      'colorArgb': instance.colorArgb,
    };

_DetectionSettingsModel _$DetectionSettingsModelFromJson(
  Map<String, dynamic> json,
) => _DetectionSettingsModel(
  sensitivity: (json['sensitivity'] as num?)?.toDouble() ?? 0.5,
  filter:
      $enumDecodeNullable(_$BeatFilterEnumMap, json['filter']) ??
      BeatFilter.every,
);

Map<String, dynamic> _$DetectionSettingsModelToJson(
  _DetectionSettingsModel instance,
) => <String, dynamic>{
  'sensitivity': instance.sensitivity,
  'filter': _$BeatFilterEnumMap[instance.filter]!,
};

const _$BeatFilterEnumMap = {
  BeatFilter.every: 'every',
  BeatFilter.strong: 'strong',
  BeatFilter.drops: 'drops',
  BeatFilter.every2nd: 'every2nd',
  BeatFilter.every4th: 'every4th',
};

_ProjectSummaryModel _$ProjectSummaryModelFromJson(Map<String, dynamic> json) =>
    _ProjectSummaryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      beatCount: (json['beatCount'] as num).toInt(),
      bpm: (json['bpm'] as num?)?.toDouble(),
      sampleRate: (json['sampleRate'] as num).toInt(),
      sampleCount: (json['sampleCount'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      thumbnail:
          (json['thumbnail'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
    );

Map<String, dynamic> _$ProjectSummaryModelToJson(
  _ProjectSummaryModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'beatCount': instance.beatCount,
  'bpm': instance.bpm,
  'sampleRate': instance.sampleRate,
  'sampleCount': instance.sampleCount,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'thumbnail': instance.thumbnail,
};

_ProjectIndexModel _$ProjectIndexModelFromJson(
  Map<String, dynamic> json,
) => _ProjectIndexModel(
  schemaVersion:
      (json['schemaVersion'] as num?)?.toInt() ?? currentProjectSchemaVersion,
  projects:
      (json['projects'] as List<dynamic>?)
          ?.map((e) => ProjectSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ProjectSummaryModel>[],
);

Map<String, dynamic> _$ProjectIndexModelToJson(_ProjectIndexModel instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'projects': instance.projects.map((e) => e.toJson()).toList(),
    };
