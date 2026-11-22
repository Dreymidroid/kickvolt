import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/audio_native/audio_native_client.dart';
import '../../domain/entities/import_failure.dart';
import '../../domain/entities/picked_source.dart';

/// Opens the system pickers. Returns null when the user cancels.
abstract interface class SourcePicker {
  Future<PickedSource?> pickFile();
  Future<PickedSource?> pickVideo();

  /// iOS only: the native music picker.
  Future<PickedSource?> pickLibraryTrack();

  /// Android only: songs to show in our own list.
  Future<List<LibraryTrack>> listLibraryTracks();

  /// Whether the music library uses the native iOS picker (true) or our
  /// MediaStore list (false).
  bool get usesNativeLibraryPicker;
}

class SourcePickerImpl implements SourcePicker {
  SourcePickerImpl({required this._audio, ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final AudioNative _audio;
  final ImagePicker _imagePicker;

  @override
  bool get usesNativeLibraryPicker => Platform.isIOS;

  @override
  Future<PickedSource?> pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file == null) return null;
    // Android may hand back a content:// URI instead of a cached path.
    return PickedSource(
      kind: ImportSourceKind.file,
      location: file.path ?? file.uri.toString(),
      displayName: file.name,
    );
  }

  @override
  Future<PickedSource?> pickVideo() async {
    final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video == null) return null;
    return PickedSource(
      kind: ImportSourceKind.video,
      location: video.path,
      displayName: video.name.isNotEmpty ? video.name : p.basename(video.path),
    );
  }

  @override
  Future<PickedSource?> pickLibraryTrack() async {
    try {
      final track = await _audio.pickFromMusicLibrary();
      return track == null ? null : fromLibraryTrack(track);
    } on AudioNativeException catch (e) {
      throw ImportFailure(
        ImportFailureKind.fromAudioError(e.kind),
        detail: e.message,
      );
    }
  }

  @override
  Future<List<LibraryTrack>> listLibraryTracks() async {
    try {
      return await _audio.listMusicLibrary();
    } on AudioNativeException catch (e) {
      throw ImportFailure(
        ImportFailureKind.fromAudioError(e.kind),
        detail: e.message,
      );
    }
  }

  static PickedSource fromLibraryTrack(LibraryTrack t) => PickedSource(
    kind: ImportSourceKind.library,
    location: t.uri,
    displayName: t.title,
    durationMs: t.durationMs,
  );
}
