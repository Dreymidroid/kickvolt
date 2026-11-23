part of 'import_cubit.dart';

/// Live steps displayed on the Analyzing screen (§6.1).
enum ImportStep {
  /// Decoding the source audio/video to `song.wav` and creating the project.
  reading,

  /// Computing the onset envelope and finding the tempo.
  tempo,

  /// Tracking beats, classifying strong beats and drops.
  beats,

  /// Splitting into rough sections and saving.
  sections,
}

@freezed
sealed class ImportState with _$ImportState {
  /// Copying, decoding, and running initial beat detection. [progress] is 0–1.
  const factory ImportState.importing({
    required PickedSource source,
    @Default(0.0) double progress,
    @Default(ImportStep.reading) ImportStep step,
    double? detectedBpm,
  }) = ImportImporting;

  const factory ImportState.done(ImportedSong song) = ImportDone;

  const factory ImportState.failed(ImportFailure failure) = ImportFailed;

  const factory ImportState.cancelled() = ImportCancelledState;
}
