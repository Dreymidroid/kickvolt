import 'package:freezed_annotation/freezed_annotation.dart';

import 'picked_source.dart';

part 'imported_song.freezed.dart';

/// A song copied into its project folder and decoded to PCM.
@freezed
abstract class ImportedSong with _$ImportedSong {
  const ImportedSong._();

  const factory ImportedSong({
    required String projectId,
    required String title,
    required PickedSource source,

    /// Copy of the original file, or null for iOS library items.
    String? sourceCopyPath,
    required String wavPath,
    required int sampleRate,
    required int channels,

    /// Sample frames in [wavPath]. The project's master timebase.
    required int frameCount,
  }) = _ImportedSong;

  int get durationMs => frameCount * 1000 ~/ sampleRate;
}
