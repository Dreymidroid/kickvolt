part of 'source_picker_cubit.dart';

@freezed
sealed class SourcePickerState with _$SourcePickerState {
  const factory SourcePickerState.idle() = SourcePickerIdle;

  /// A system picker is open or the library is loading.
  const factory SourcePickerState.busy() = SourcePickerBusy;

  /// The user chose a song; the UI should start the import.
  const factory SourcePickerState.picked(PickedSource source) =
      SourcePickerPicked;

  /// Android: songs to choose from.
  const factory SourcePickerState.library(List<LibraryTrack> tracks) =
      SourcePickerLibrary;

  const factory SourcePickerState.failed(ImportFailure failure) =
      SourcePickerFailed;
}
