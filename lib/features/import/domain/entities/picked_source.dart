import 'package:freezed_annotation/freezed_annotation.dart';

part 'picked_source.freezed.dart';

enum ImportSourceKind { file, library, video }

/// A song the user chose, before it is copied and decoded.
@freezed
abstract class PickedSource with _$PickedSource {
  const PickedSource._();

  const factory PickedSource({
    required ImportSourceKind kind,

    /// A local file path, a `content://` URI (Android) or an
    /// `ipod-library://` URL (iOS music library).
    required String location,

    /// What to show the user, e.g. `Midnight Run.m4a`.
    required String displayName,

    /// Known up front for library tracks; otherwise null until decoded.
    int? durationMs,
  }) = _PickedSource;

  bool get isContentUri => location.startsWith('content://');

  /// iOS library items can't be copied as files; they are decoded straight
  /// from the asset URL and the decoded WAV becomes the durable copy.
  bool get isLibraryAssetUrl => location.startsWith('ipod-library://');

  /// File name without its extension, used as the project title.
  String get title {
    final dot = displayName.lastIndexOf('.');
    return dot > 0 ? displayName.substring(0, dot) : displayName;
  }

  /// Lower-case extension without the dot, or '' if none.
  String get extension {
    final dot = displayName.lastIndexOf('.');
    return dot > 0 && dot < displayName.length - 1
        ? displayName.substring(dot + 1).toLowerCase()
        : '';
  }
}
