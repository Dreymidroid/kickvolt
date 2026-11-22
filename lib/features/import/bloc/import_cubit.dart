import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/di/locator.dart';
import '../../projects/data/repositories/project_repository.dart';
import '../data/repositories/import_repository.dart';
import '../domain/entities/import_failure.dart';
import '../domain/entities/imported_song.dart';
import '../domain/entities/picked_source.dart';

part 'import_cubit.freezed.dart';
part 'import_state.dart';

/// Copies and decodes one picked song (the Analyzing screen), then persists
/// the initial project before reporting [ImportState.done].
class ImportCubit extends Cubit<ImportState> {
  ImportCubit({
    required PickedSource source,
    ImportRepository? repository,
    ProjectRepository? projectRepository,
  }) : _repository = repository ?? locator<ImportRepository>(),
       _projectRepository = projectRepository ?? locator<ProjectRepository>(),
       super(ImportState.importing(source: source));

  final ImportRepository _repository;
  final ProjectRepository _projectRepository;
  final _token = ImportCancelToken();

  static const _decodeProgressShare = 0.9;

  Future<void> start() async {
    final s = state;
    if (s is! ImportImporting) return;
    try {
      final song = await _repository.importSong(
        s.source,
        cancelToken: _token,
        onProgress: (p) {
          final cur = state;
          final scaled = (p * _decodeProgressShare).clamp(
            0.0,
            _decodeProgressShare,
          );
          // Progress is monotonic; ignore late or out-of-order reports.
          if (!isClosed && cur is ImportImporting && scaled > cur.progress) {
            emit(cur.copyWith(progress: scaled));
          }
        },
      );
      if (isClosed) return;
      if (_token.isCancelled) {
        await _projectRepository.deleteProject(song.projectId);
        if (!isClosed) emit(const ImportState.cancelled());
        return;
      }

      await _projectRepository.createFromImport(song);
      if (isClosed) return;
      if (_token.isCancelled) {
        await _projectRepository.deleteProject(song.projectId);
        if (!isClosed) emit(const ImportState.cancelled());
        return;
      }

      final cur = state;
      if (cur is ImportImporting && cur.progress < 1.0) {
        emit(cur.copyWith(progress: 1.0));
      }
      HapticFeedback.mediumImpact();
      emit(ImportState.done(song));
    } on ImportCancelled {
      if (!isClosed) emit(const ImportState.cancelled());
    } on ImportFailure catch (e) {
      if (!isClosed) emit(ImportState.failed(e));
    } catch (e) {
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

  Future<void> cancel() => _token.cancel();

  @override
  Future<void> close() async {
    // Leaving the screen stops the native job; the repository cleans up.
    await _token.cancel();
    return super.close();
  }
}
