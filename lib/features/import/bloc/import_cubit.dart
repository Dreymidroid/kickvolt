import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/di/locator.dart';
import '../data/repositories/import_repository.dart';
import '../domain/entities/import_failure.dart';
import '../domain/entities/imported_song.dart';
import '../domain/entities/picked_source.dart';

part 'import_cubit.freezed.dart';
part 'import_state.dart';

/// Copies and decodes one picked song (the Analyzing screen).
class ImportCubit extends Cubit<ImportState> {
  ImportCubit({required PickedSource source, ImportRepository? repository})
    : _repository = repository ?? locator<ImportRepository>(),
      super(ImportState.importing(source: source));

  final ImportRepository _repository;
  final _token = ImportCancelToken();

  Future<void> start() async {
    final s = state;
    if (s is! ImportImporting) return;
    try {
      final song = await _repository.importSong(
        s.source,
        cancelToken: _token,
        onProgress: (p) {
          final cur = state;
          // Progress is monotonic; ignore late or out-of-order reports.
          if (!isClosed && cur is ImportImporting && p > cur.progress) {
            emit(cur.copyWith(progress: p.clamp(0.0, 1.0)));
          }
        },
      );
      if (isClosed) return;
      if (_token.isCancelled) {
        emit(const ImportState.cancelled());
        return;
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
