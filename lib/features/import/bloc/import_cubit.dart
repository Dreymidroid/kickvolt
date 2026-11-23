import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/di/locator.dart';
import '../../beat_detection/beat_detection.dart';
import '../../projects/data/repositories/project_repository.dart';
import '../../projects/domain/entities/detection_settings.dart';
import '../data/repositories/import_repository.dart';
import '../domain/entities/import_failure.dart';
import '../domain/entities/imported_song.dart';
import '../domain/entities/picked_source.dart';

part 'import_cubit.freezed.dart';
part 'import_state.dart';

/// Copies and decodes one picked song (the Analyzing screen), creates the
/// project, runs initial beat detection, and saves the result before reporting
/// [ImportState.done].
class ImportCubit extends Cubit<ImportState> {
  ImportCubit({
    required PickedSource source,
    ImportRepository? repository,
    ProjectRepository? projectRepository,
    BeatDetectionRepository? detectionRepository,
  }) : _repository = repository ?? locator<ImportRepository>(),
       _projectRepository = projectRepository ?? locator<ProjectRepository>(),
       _detectionRepository =
           detectionRepository ?? locator<BeatDetectionRepository>(),
       super(ImportState.importing(source: source));

  final ImportRepository _repository;
  final ProjectRepository _projectRepository;
  final BeatDetectionRepository _detectionRepository;
  final _token = ImportCancelToken();
  final _analysisToken = AnalysisCancelToken();

  // Progress mapping (§6.1):
  // decode: 0.0–0.6, project creation: 0.6–0.65, analysis: 0.65–1.0.
  static const _decodeShare = 0.6;
  static const _projectShare = 0.65;
  static const _analysisShare = 1.0 - _projectShare;

  Future<void> start() async {
    final s = state;
    if (s is! ImportImporting) return;
    String? createdProjectId;
    try {
      final song = await _repository.importSong(
        s.source,
        cancelToken: _token,
        onProgress: (p) {
          final cur = state;
          final scaled = (p * _decodeShare).clamp(0.0, _decodeShare);
          // Progress is monotonic; ignore late or out-of-order reports.
          if (!isClosed && cur is ImportImporting && scaled > cur.progress) {
            emit(cur.copyWith(progress: scaled, step: ImportStep.reading));
          }
        },
      );
      if (isClosed) return;
      if (_isCancelled) {
        await _projectRepository.deleteProject(song.projectId);
        if (!isClosed) emit(const ImportState.cancelled());
        return;
      }

      final project = await _projectRepository.createFromImport(song);
      createdProjectId = project.id;
      if (isClosed) return;
      if (_isCancelled) {
        await _projectRepository.deleteProject(project.id);
        if (!isClosed) emit(const ImportState.cancelled());
        return;
      }

      _emitImporting(progress: _projectShare, step: ImportStep.tempo);

      final analysis = await _detectionRepository.analyze(
        project.id,
        cancelToken: _analysisToken,
        onProgress: (p) {
          final scaled = (_projectShare + p.fraction * _analysisShare).clamp(
            _projectShare,
            0.99,
          );
          final step = switch (p.stage) {
            AnalysisStage.envelope || AnalysisStage.tempo => ImportStep.tempo,
            AnalysisStage.tracking => ImportStep.beats,
            AnalysisStage.sections => ImportStep.sections,
          };
          _emitImporting(progress: scaled, step: step, detectedBpm: p.bpm);
        },
      );
      if (isClosed) return;
      if (_isCancelled) {
        await _projectRepository.deleteProject(project.id);
        if (!isClosed) emit(const ImportState.cancelled());
        return;
      }

      final result = _detectionRepository.classify(
        analysis,
        project.detection.sensitivity,
      );

      // Detection failing is NOT an import failure (§6.1): save with no beats
      // and status: failed, then open the editor.
      final updated = result.succeeded
          ? project.copyWith(
              beats: result.beats,
              bpm: result.bpm,
              beatPhaseSample: result.beatPhaseSample,
              sections: result.sections,
              detection: project.detection.copyWith(
                status: DetectionStatus.succeeded,
              ),
            )
          : project.copyWith(
              beats: const [],
              bpm: null,
              beatPhaseSample: null,
              sections: const [],
              detection: project.detection.copyWith(
                status: DetectionStatus.failed,
              ),
            );

      await _projectRepository.saveProject(updated);
      if (isClosed) return;
      if (_isCancelled) {
        await _projectRepository.deleteProject(project.id);
        if (!isClosed) emit(const ImportState.cancelled());
        return;
      }

      _emitImporting(
        progress: 1.0,
        step: ImportStep.sections,
        detectedBpm: result.bpm,
      );
      HapticFeedback.mediumImpact();
      emit(ImportState.done(song));
    } on ImportCancelled {
      if (createdProjectId != null) {
        await _projectRepository.deleteProject(createdProjectId);
      }
      if (!isClosed) emit(const ImportState.cancelled());
    } on AnalysisCancelledException {
      if (createdProjectId != null) {
        await _projectRepository.deleteProject(createdProjectId);
      }
      if (!isClosed) emit(const ImportState.cancelled());
    } on ImportFailure catch (e) {
      if (createdProjectId != null) {
        await _projectRepository.deleteProject(createdProjectId);
      }
      if (!isClosed) emit(ImportState.failed(e));
    } catch (e) {
      if (createdProjectId != null) {
        await _projectRepository.deleteProject(createdProjectId);
      }
      if (!isClosed) {
        emit(
          ImportState.failed(
            ImportFailure(
              ImportFailureKind.unknown,
              fileName: s.source.displayName,
              detail: e.toString(),
            ),
          ),
        );
      }
    }
  }

  bool get _isCancelled => _token.isCancelled || _analysisToken.isCancelled;

  void _emitImporting({
    required double progress,
    required ImportStep step,
    double? detectedBpm,
  }) {
    if (isClosed) return;
    final cur = state;
    if (cur is! ImportImporting) return;
    final nextProgress = progress > cur.progress ? progress : cur.progress;
    final nextStep = step.index > cur.step.index ? step : cur.step;
    final nextBpm = detectedBpm ?? cur.detectedBpm;
    if (nextProgress != cur.progress ||
        nextStep != cur.step ||
        nextBpm != cur.detectedBpm) {
      emit(
        cur.copyWith(
          progress: nextProgress,
          step: nextStep,
          detectedBpm: nextBpm,
        ),
      );
    }
  }

  Future<void> cancel() async {
    await Future.wait(<Future<void>>[_token.cancel(), _analysisToken.cancel()]);
  }

  @override
  Future<void> close() async {
    // Leaving the screen stops both native decode and analysis isolate.
    await cancel();
    return super.close();
  }
}
