import 'dart:developer' as developer;
import 'dart:io';

import '../../../../core/storage/project_paths.dart';
import '../../../projects/data/repositories/project_repository.dart';
import '../../domain/beat_analyzer.dart';
import '../../domain/beat_classifier.dart';
import '../../domain/entities/beat_analysis.dart';
import '../../domain/entities/detection_result.dart';
import '../analysis_cache_codec.dart';
import '../analysis_isolate_runner.dart';

abstract interface class BeatDetectionRepository {
  /// Returns the cached [BeatAnalysis] for [projectId] if a valid,
  /// current-version `analysis.bin` exists on disk, or null otherwise.
  Future<BeatAnalysis?> getCachedAnalysis(String projectId);

  /// Analyses `projects/<projectId>/song.wav` in a background isolate,
  /// reporting progress via [onProgress] and supporting cancellation via
  /// [cancelToken]. If a valid cached analysis already exists and
  /// [forceReanalyze] is false, returns the cached analysis.
  Future<BeatAnalysis> analyze(
    String projectId, {
    void Function(AnalysisProgress progress)? onProgress,
    AnalysisCancelToken? cancelToken,
    bool forceReanalyze = false,
  });

  /// Runs fast (< 5 ms) classification on [analysis] for [sensitivity] (`0..1`).
  DetectionResult classify(BeatAnalysis analysis, double sensitivity);
}

class BeatDetectionRepositoryImpl implements BeatDetectionRepository {
  BeatDetectionRepositoryImpl({required this._paths, this._projectRepository});

  final Future<ProjectPaths> Function() _paths;
  final ProjectRepository? _projectRepository;

  /// In-memory cache of the most recent analyses by projectId so slider drags
  /// in the Auto-detect sheet don't even touch disk once loaded.
  final Map<String, BeatAnalysis> _memoryCache = {};

  @override
  Future<BeatAnalysis?> getCachedAnalysis(String projectId) async {
    final mem = _memoryCache[projectId];
    if (mem != null) return mem;

    final paths = await _paths();
    final cachePath = paths.analysisFile(projectId);
    final file = File(cachePath);
    final tmpFile = File('$cachePath.tmp');

    try {
      if (!await file.exists() && await tmpFile.exists()) {
        final bytes = await tmpFile.readAsBytes();
        final decoded = decodeBeatAnalysis(bytes);
        await tmpFile.rename(file.path);
        _memoryCache[projectId] = decoded;
        return decoded;
      }
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final decoded = decodeBeatAnalysis(bytes);
        _memoryCache[projectId] = decoded;
        return decoded;
      }
    } catch (e) {
      developer.log(
        'Ignoring corrupt or old analysis.bin for $projectId: $e',
        name: 'beat_detection',
      );
    }
    return null;
  }

  @override
  Future<BeatAnalysis> analyze(
    String projectId, {
    void Function(AnalysisProgress progress)? onProgress,
    AnalysisCancelToken? cancelToken,
    bool forceReanalyze = false,
  }) async {
    if (!forceReanalyze) {
      final cached = await getCachedAnalysis(projectId);
      if (cached != null) {
        onProgress?.call(
          AnalysisProgress(
            stage: AnalysisStage.sections,
            fraction: 1.0,
            bpm: cached.bpm > 0 ? cached.bpm : null,
          ),
        );
        return cached;
      }
    }

    final paths = await _paths();
    final wavPath = paths.songWav(projectId);
    final analysis = await runAnalysisInIsolate(
      wavPath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    if (cancelToken != null && cancelToken.isCancelled) {
      throw const AnalysisCancelledException();
    }

    _memoryCache[projectId] = analysis;

    // Persist atomically through the serialized writer if project dir still exists.
    try {
      final projDir = Directory(paths.projectDir(projectId));
      if (await projDir.exists()) {
        final encoded = encodeBeatAnalysis(analysis);
        final targetPath = paths.analysisFile(projectId);
        final repo = _projectRepository;
        if (repo != null) {
          await repo.writeProjectBinaryFile(targetPath, encoded);
        } else {
          await _writeAtomicFallback(targetPath, encoded);
        }
      }
    } catch (e) {
      developer.log(
        'Failed to cache analysis.bin for $projectId: $e',
        name: 'beat_detection',
      );
    }

    return analysis;
  }

  @override
  DetectionResult classify(BeatAnalysis analysis, double sensitivity) =>
      classifyBeats(analysis, sensitivity: sensitivity);

  Future<void> _writeAtomicFallback(String targetPath, List<int> bytes) async {
    final tmpFile = File('$targetPath.tmp');
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
