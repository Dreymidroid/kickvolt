import 'package:path/path.dart' as p;

import '../../domain/entities/beat.dart';
import '../../domain/entities/detection_settings.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_exception.dart';
import '../../domain/entities/project_source.dart';
import '../../domain/entities/project_summary.dart';
import '../../domain/entities/section.dart';
import '../models/project_model.dart';

/// Maps between `project.json` / `index.json` models and domain entities.
class ProjectMapper {
  const ProjectMapper._();

  static Project fromJsonMap(Map<String, dynamic> json, {String? projectId}) {
    final rawVersion = json['schemaVersion'];
    if (rawVersion is! int) {
      throw ProjectCorruptException(
        'Missing or non-integer schemaVersion',
        projectId: projectId,
      );
    }
    if (rawVersion != currentProjectSchemaVersion) {
      throw ProjectSchemaVersionException(rawVersion, projectId: projectId);
    }

    final ProjectModel model;
    try {
      model = ProjectModel.fromJson(json);
    } catch (e) {
      throw ProjectCorruptException(
        'Malformed project.json: $e',
        projectId: projectId,
      );
    }
    return toEntity(model, projectId: projectId);
  }

  static Map<String, dynamic> toJsonMap(Project project) =>
      fromEntity(project).toJson();

  static Project toEntity(ProjectModel model, {String? projectId}) {
    if (model.sampleRate <= 0 || model.channels <= 0 || model.sampleCount < 0) {
      throw ProjectCorruptException(
        'Invalid audio parameters in project.json',
        projectId: projectId ?? model.id,
      );
    }

    // Deduplicate and sort beats by sample index.
    final sortedBeats = [
      for (final b in model.beats) Beat(sample: b.sample, type: b.type),
    ]..sort((a, b) => a.sample.compareTo(b.sample));
    final uniqueBeats = <Beat>[];
    for (final b in sortedBeats) {
      if (uniqueBeats.isEmpty || uniqueBeats.last.sample != b.sample) {
        uniqueBeats.add(b);
      }
    }

    final sortedSections = [
      for (final s in model.sections)
        Section(
          startSample: s.startSample,
          endSample: s.endSample,
          name: s.name,
          colorArgb: s.colorArgb,
        ),
    ]..sort((a, b) => a.startSample.compareTo(b.startSample));

    final copied = model.source.copiedFileName;
    return Project(
      id: model.id,
      title: model.title,
      source: ProjectSource(
        kind: model.source.kind,
        originalName: model.source.originalName,
        copiedFileName: copied == null || copied.isEmpty
            ? null
            : p.basename(copied),
      ),
      sampleRate: model.sampleRate,
      channels: model.channels,
      sampleCount: model.sampleCount,
      beats: uniqueBeats,
      sections: sortedSections,
      bpm: model.bpm,
      beatPhaseSample: model.beatPhaseSample,
      detection: DetectionSettings(
        sensitivity: model.detection.sensitivity,
        filter: model.detection.filter,
      ),
      createdAt: model.createdAt.toUtc(),
      updatedAt: model.updatedAt.toUtc(),
    );
  }

  static ProjectModel fromEntity(Project project) {
    final sortedBeats = [...project.beats]
      ..sort((a, b) => a.sample.compareTo(b.sample));
    final uniqueBeats = <BeatModel>[];
    for (final b in sortedBeats) {
      if (uniqueBeats.isEmpty || uniqueBeats.last.sample != b.sample) {
        uniqueBeats.add(BeatModel(sample: b.sample, type: b.type));
      }
    }

    final sortedSections = [...project.sections]
      ..sort((a, b) => a.startSample.compareTo(b.startSample));

    final copied = project.source.copiedFileName;
    return ProjectModel(
      schemaVersion: currentProjectSchemaVersion,
      id: project.id,
      title: project.title,
      source: ProjectSourceModel(
        kind: project.source.kind,
        originalName: project.source.originalName,
        copiedFileName: copied == null || copied.isEmpty
            ? null
            : p.basename(copied),
      ),
      sampleRate: project.sampleRate,
      channels: project.channels,
      sampleCount: project.sampleCount,
      beats: uniqueBeats,
      sections: [
        for (final s in sortedSections)
          SectionModel(
            startSample: s.startSample,
            endSample: s.endSample,
            name: s.name,
            colorArgb: s.colorArgb,
          ),
      ],
      bpm: project.bpm,
      beatPhaseSample: project.beatPhaseSample,
      detection: DetectionSettingsModel(
        sensitivity: project.detection.sensitivity,
        filter: project.detection.filter,
      ),
      createdAt: project.createdAt.toUtc(),
      updatedAt: project.updatedAt.toUtc(),
    );
  }

  static ProjectSummary summaryToEntity(ProjectSummaryModel model) =>
      ProjectSummary(
        id: model.id,
        title: model.title,
        beatCount: model.beatCount,
        bpm: model.bpm,
        sampleRate: model.sampleRate,
        sampleCount: model.sampleCount,
        updatedAt: model.updatedAt.toUtc(),
        thumbnail: List<int>.unmodifiable(model.thumbnail),
      );

  static ProjectSummaryModel summaryFromEntity(ProjectSummary summary) =>
      ProjectSummaryModel(
        id: summary.id,
        title: summary.title,
        beatCount: summary.beatCount,
        bpm: summary.bpm,
        sampleRate: summary.sampleRate,
        sampleCount: summary.sampleCount,
        updatedAt: summary.updatedAt.toUtc(),
        thumbnail: [...summary.thumbnail],
      );

  static ProjectSummary summaryFromProject(
    Project project, {
    required List<int> thumbnail,
  }) => ProjectSummary(
    id: project.id,
    title: project.title,
    beatCount: project.beatCount,
    bpm: project.bpm,
    sampleRate: project.sampleRate,
    sampleCount: project.sampleCount,
    updatedAt: project.updatedAt.toUtc(),
    thumbnail: List<int>.unmodifiable(thumbnail),
  );
}
