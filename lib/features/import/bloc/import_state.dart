part of 'import_cubit.dart';

@freezed
sealed class ImportState with _$ImportState {
  /// Copying and decoding. [progress] is 0–1.
  const factory ImportState.importing({
    required PickedSource source,
    @Default(0.0) double progress,
  }) = ImportImporting;

  const factory ImportState.done(ImportedSong song) = ImportDone;

  const factory ImportState.failed(ImportFailure failure) = ImportFailed;

  const factory ImportState.cancelled() = ImportCancelledState;
}
