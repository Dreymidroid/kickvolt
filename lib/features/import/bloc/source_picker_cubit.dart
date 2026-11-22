import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/audio_native/audio_native_client.dart';
import '../../../core/di/locator.dart';
import '../data/datasources/source_picker.dart';
import '../domain/entities/import_failure.dart';
import '../domain/entities/picked_source.dart';

part 'source_picker_cubit.freezed.dart';
part 'source_picker_state.dart';

/// Choosing what to import: Files, the music library or a video.
class SourcePickerCubit extends Cubit<SourcePickerState> {
  SourcePickerCubit({SourcePicker? picker})
    : _picker = picker ?? locator<SourcePicker>(),
      super(const SourcePickerState.idle());

  final SourcePicker _picker;

  bool get usesNativeLibraryPicker => _picker.usesNativeLibraryPicker;

  Future<void> pickFile() => _pick(_picker.pickFile);

  Future<void> pickVideo() => _pick(_picker.pickVideo);

  /// iOS: opens the system music picker. Android: loads songs for our list.
  Future<void> openLibrary() async {
    if (_picker.usesNativeLibraryPicker) return _pick(_picker.pickLibraryTrack);
    emit(const SourcePickerState.busy());
    try {
      emit(SourcePickerState.library(await _picker.listLibraryTracks()));
    } on ImportFailure catch (e) {
      emit(SourcePickerState.failed(e));
    } catch (e) {
      emit(
        SourcePickerState.failed(
          ImportFailure(ImportFailureKind.unknown, detail: e.toString()),
        ),
      );
    }
  }

  void chooseLibraryTrack(LibraryTrack track) =>
      emit(SourcePickerState.picked(SourcePickerImpl.fromLibraryTrack(track)));

  /// Back to idle once the UI has acted on `picked` / `failed`.
  void reset() => emit(const SourcePickerState.idle());

  Future<void> _pick(Future<PickedSource?> Function() pick) async {
    if (state is SourcePickerBusy) return;
    emit(const SourcePickerState.busy());
    try {
      final source = await pick();
      emit(
        source == null
            ? const SourcePickerState.idle()
            : SourcePickerState.picked(source),
      );
    } on ImportFailure catch (e) {
      emit(SourcePickerState.failed(e));
    } catch (e) {
      emit(
        SourcePickerState.failed(
          ImportFailure(ImportFailureKind.unknown, detail: e.toString()),
        ),
      );
    }
  }
}
