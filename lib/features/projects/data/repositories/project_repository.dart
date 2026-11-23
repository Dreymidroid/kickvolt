import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/audio_math/overview.dart';
import '../../../../core/audio_math/wav_header.dart';
import '../../../../core/storage/project_paths.dart';
import '../../../import/domain/entities/imported_song.dart';
import '../../domain/entities/detection_settings.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_exception.dart';
import '../../domain/entities/project_source.dart';
import '../../domain/entities/project_summary.dart';
import '../mappers/project_mapper.dart';
import '../models/project_model.dart';

abstract interface class ProjectRepository {
  Future<Project> createFromImport(ImportedSong song);

  Future<List<ProjectSummary>> listProjects();

  Future<Project> getProject(String id);

  Future<Overview> getOverview(String id);

  Future<void> saveProject(Project project);

  Future<void> renameProject(String id, String title);

  Future<void> deleteProject(String id);

  Future<void> cleanUpOrphans();
}

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl({required this._paths, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Future<ProjectPaths> Function() _paths;
  final DateTime Function() _clock;

  /// Atomic writes share `<name>.tmp`, so they must not interleave.
  final _writeLock = _SerialLock();

  /// Index updates are read-modify-write; serialize them so concurrent
  /// saves, renames and deletes don't drop each other's entries.
  final _indexLock = _SerialLock();

  @override
  Future<Project> createFromImport(ImportedSong song) async {
    final paths = await _paths();
    final id = song.projectId;
    try {
      await paths.createProjectDir(id);
      final wavPath = paths.songWav(id);
      final info = await readWavInfo(File(wavPath));
      if (info.bitsPerSample != 16 || info.frameCount <= 0) {
        throw ProjectCorruptException(
          'Invalid WAV in createFromImport: $info',
          projectId: id,
        );
      }

      final ov = await computeOverview(wavPath);
      await _writeAtomicBytes(paths.overviewBin(id), encodeOverview(ov));

      final now = _clock().toUtc();
      final copiedName = song.sourceCopyPath != null
          ? p.basename(song.sourceCopyPath!)
          : null;
      final project = Project(
        id: id,
        title: song.title,
        source: ProjectSource(
          kind: song.source.kind,
          originalName: song.source.displayName,
          copiedFileName: copiedName,
        ),
        sampleRate: info.sampleRate,
        channels: info.channels,
        sampleCount: info.frameCount,
        beats: const [],
        sections: const [],
        bpm: null,
        beatPhaseSample: null,
        detection: const DetectionSettings(),
        createdAt: now,
        updatedAt: now,
      );

      await _writeProjectJson(paths, project);
      final thumb = thumbnail(ov, overviewThumbnailLength);
      await _upsertIndexEntry(
        paths,
        ProjectMapper.summaryFromProject(project, thumbnail: thumb),
      );
      return project;
    } catch (_) {
      await paths.deleteProject(id);
      rethrow;
    }
  }

  @override
  Future<List<ProjectSummary>> listProjects() async {
    final paths = await _paths();
    final projectsDir = Directory(paths.projectsDir);
    if (!await projectsDir.exists()) return const [];

    final folderIds = <String>{};
    await for (final entity in projectsDir.list(followLinks: false)) {
      if (entity is Directory) {
        folderIds.add(p.basename(entity.path));
      }
    }

    final cached = await _tryReadIndex(paths);
    if (cached != null) {
      final indexIds = {for (final s in cached) s.id};
      if (indexIds.length == cached.length &&
          indexIds.length == folderIds.length &&
          indexIds.containsAll(folderIds)) {
        final sorted = [...cached]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return sorted;
      }
    }

    return _indexLock.run(() => _rebuildIndex(paths, folderIds));
  }

  @override
  Future<Project> getProject(String id) async {
    final paths = await _paths();
    final jsonPath = paths.projectJson(id);
    final map = await _readJsonWithTmpPromotion(
      jsonPath,
      projectId: id,
      notFoundIfMissing: true,
    );
    return ProjectMapper.fromJsonMap(map!, projectId: id);
  }

  @override
  Future<Overview> getOverview(String id) async {
    final paths = await _paths();
    final binFile = File(paths.overviewBin(id));
    final tmpFile = File('${paths.overviewBin(id)}.tmp');
    try {
      if (!await binFile.exists() && await tmpFile.exists()) {
        final bytes = await tmpFile.readAsBytes();
        final ov = decodeOverview(bytes);
        await tmpFile.rename(binFile.path);
        return ov;
      }
      if (await binFile.exists()) {
        final bytes = await binFile.readAsBytes();
        return decodeOverview(bytes);
      }
      final wavFile = File(paths.songWav(id));
      if (await wavFile.exists()) {
        final ov = await computeOverview(wavFile.path);
        await _writeAtomicBytes(binFile.path, encodeOverview(ov));
        return ov;
      }
    } catch (e) {
      developer.log('Failed to load overview for $id: $e', name: 'projects');
    }
    return Overview.empty;
  }

  @override
  Future<void> saveProject(Project project) async {
    final paths = await _paths();
    await paths.createProjectDir(project.id);
    final now = _clock().toUtc();
    final updated = project.copyWith(
      createdAt: project.createdAt.toUtc(),
      updatedAt: now,
    );
    await _writeProjectJson(paths, updated);

    List<int>? existingThumb;
    final cached = await _tryReadIndex(paths);
    if (cached != null) {
      for (final s in cached) {
        if (s.id == updated.id &&
            s.thumbnail.length == overviewThumbnailLength) {
          existingThumb = s.thumbnail;
          break;
        }
      }
    }
    final thumb =
        existingThumb ?? await _loadOrComputeThumbnail(paths, updated.id);
    await _upsertIndexEntry(
      paths,
      ProjectMapper.summaryFromProject(updated, thumbnail: thumb),
    );
  }

  @override
  Future<void> renameProject(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const InvalidProjectTitleException();
    }
    final project = await getProject(id);
    await saveProject(project.copyWith(title: trimmed));
  }

  @override
  Future<void> deleteProject(String id) async {
    final paths = await _paths();
    await paths.deleteProject(id);
    await _indexLock.run(() async {
      final cached = await _tryReadIndex(paths);
      if (cached != null) {
        final remaining = [
          for (final s in cached)
            if (s.id != id) s,
        ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        await _writeIndex(paths, remaining);
      }
    });
  }

  @override
  Future<void> cleanUpOrphans() async {
    final paths = await _paths();
    final projectsDir = Directory(paths.projectsDir);
    if (!await projectsDir.exists()) return;

    await for (final entity in projectsDir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final jsonFile = File(paths.projectJson(id));
      if (await jsonFile.exists()) continue;

      final tmpFile = File('${paths.projectJson(id)}.tmp');
      if (await tmpFile.exists()) {
        try {
          final text = await tmpFile.readAsString();
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            ProjectMapper.fromJsonMap(decoded, projectId: id);
            await tmpFile.rename(jsonFile.path);
            continue;
          }
        } catch (_) {
          // Unrecoverable .tmp; fall through to delete orphan folder.
        }
      }

      try {
        await entity.delete(recursive: true);
      } catch (e) {
        developer.log(
          'Failed to delete orphan project $id: $e',
          name: 'projects',
        );
      }
    }
  }

  Future<List<ProjectSummary>> _rebuildIndex(
    ProjectPaths paths,
    Set<String> folderIds,
  ) async {
    final summaries = <ProjectSummary>[];
    for (final id in folderIds) {
      try {
        final project = await getProject(id);
        final thumb = await _loadOrComputeThumbnail(paths, id);
        summaries.add(
          ProjectMapper.summaryFromProject(project, thumbnail: thumb),
        );
      } on ProjectException catch (e) {
        developer.log(
          'Skipping unreadable project $id during index rebuild: $e',
          name: 'projects',
        );
      } catch (e) {
        developer.log(
          'Skipping project $id due to unexpected error: $e',
          name: 'projects',
        );
      }
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    try {
      await _writeIndex(paths, summaries);
    } catch (e) {
      developer.log(
        'Failed to persist rebuilt index.json: $e',
        name: 'projects',
      );
    }
    return summaries;
  }

  Future<List<int>> _loadOrComputeThumbnail(
    ProjectPaths paths,
    String id,
  ) async {
    final ov = await getOverview(id);
    return thumbnail(ov, overviewThumbnailLength);
  }

  Future<void> _upsertIndexEntry(ProjectPaths paths, ProjectSummary entry) =>
      _indexLock.run(() async {
        final current = await _tryReadIndex(paths) ?? const <ProjectSummary>[];
        final next = <ProjectSummary>[
          entry,
          for (final s in current)
            if (s.id != entry.id) s,
        ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        await _writeIndex(paths, next);
      });

  Future<List<ProjectSummary>?> _tryReadIndex(ProjectPaths paths) async {
    try {
      final map = await _readJsonWithTmpPromotion(
        paths.indexJson,
        notFoundIfMissing: false,
      );
      if (map == null) return null;
      if (map['schemaVersion'] != currentProjectSchemaVersion) return null;
      final index = ProjectIndexModel.fromJson(map);
      return [for (final m in index.projects) ProjectMapper.summaryToEntity(m)];
    } catch (e) {
      developer.log('Failed to parse index.json: $e', name: 'projects');
      return null;
    }
  }

  Future<void> _writeIndex(
    ProjectPaths paths,
    List<ProjectSummary> summaries,
  ) async {
    final model = ProjectIndexModel(
      schemaVersion: currentProjectSchemaVersion,
      projects: [for (final s in summaries) ProjectMapper.summaryFromEntity(s)],
    );
    await _writeAtomicJson(paths.indexJson, model.toJson());
  }

  Future<void> _writeProjectJson(ProjectPaths paths, Project project) async {
    await _writeAtomicJson(
      paths.projectJson(project.id),
      ProjectMapper.toJsonMap(project),
    );
  }

  /// Reads a JSON object from [targetPath]. If [targetPath] is missing but
  /// `<targetPath>.tmp` exists and parses as a JSON object, promotes the
  /// `.tmp` file to [targetPath] and returns it.
  Future<Map<String, dynamic>?> _readJsonWithTmpPromotion(
    String targetPath, {
    String? projectId,
    required bool notFoundIfMissing,
  }) async {
    final file = File(targetPath);
    final tmpFile = File('$targetPath.tmp');

    if (await file.exists()) {
      return _parseJsonFile(file, projectId: projectId);
    }

    if (await tmpFile.exists()) {
      final parsed = await _parseJsonFile(tmpFile, projectId: projectId);
      // Validate before promoting if this is a project.json file.
      if (projectId != null) {
        ProjectMapper.fromJsonMap(parsed, projectId: projectId);
      }
      try {
        await tmpFile.rename(targetPath);
      } on FileSystemException catch (e) {
        throw ProjectCorruptException(
          'Failed to promote temporary file: $e',
          projectId: projectId,
        );
      }
      return parsed;
    }

    if (notFoundIfMissing) {
      throw ProjectNotFoundException(
        projectId ?? p.basename(p.dirname(targetPath)),
      );
    }
    return null;
  }

  Future<Map<String, dynamic>> _parseJsonFile(
    File file, {
    String? projectId,
  }) async {
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw ProjectCorruptException(
          'Expected JSON object in ${p.basename(file.path)}',
          projectId: projectId,
        );
      }
      return decoded;
    } on ProjectException {
      rethrow;
    } on FormatException catch (e) {
      throw ProjectCorruptException(
        'Malformed JSON in ${p.basename(file.path)}: $e',
        projectId: projectId,
      );
    } on FileSystemException catch (e) {
      throw ProjectCorruptException(
        'Cannot read ${p.basename(file.path)}: $e',
        projectId: projectId,
      );
    }
  }

  Future<void> _writeAtomicJson(
    String targetPath,
    Map<String, dynamic> jsonMap,
  ) async {
    final encoded = const JsonEncoder.withIndent('  ').convert(jsonMap);
    await _writeAtomicBytes(targetPath, utf8.encode(encoded));
  }

  /// Writes [bytes] to `<targetPath>.tmp`, flushes to disk, and renames over
  /// [targetPath].
  Future<void> _writeAtomicBytes(String targetPath, List<int> bytes) =>
      _writeLock.run(() => _writeAtomicBytesUnlocked(targetPath, bytes));

  Future<void> _writeAtomicBytesUnlocked(
    String targetPath,
    List<int> bytes,
  ) async {
    final tmpPath = '$targetPath.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.parent.create(recursive: true);
    final raf = await tmpFile.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    await tmpFile.rename(targetPath);
  }
}

/// Runs async actions one at a time, in call order. A failed action doesn't
/// block the ones queued after it.
class _SerialLock {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
