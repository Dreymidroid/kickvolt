import 'export_options.dart';

/// User-facing reasons an export can fail (§7.3).
enum ExportFailureKind {
  diskFull,
  interrupted,
  encodeFailed,
  sourceMissing,
  other,
}

class ExportFailure {
  const ExportFailure({
    required this.kind,
    this.failedFileLabel = 'the guide track',
    this.neededMegabytes = 40,
    this.failedFile,
    this.detail,
  });

  final ExportFailureKind kind;

  /// Human-readable file name for diskFull copy (e.g. "the guide track",
  /// "the song", "the preview mix").
  final String failedFileLabel;

  /// Estimated megabytes to free up for diskFull copy.
  final int neededMegabytes;

  /// The file being made when it failed, when known. An [ExportFailureKind
  /// .encodeFailed] on [ExportFileKind.video] offers "Export without video".
  final ExportFileKind? failedFile;

  /// True when the guide video (M7) is what couldn't be made.
  bool get isVideoFailure =>
      kind == ExportFailureKind.encodeFailed &&
      failedFile == ExportFileKind.video;

  /// Technical error string shown in small text for [ExportFailureKind.other].
  final String? detail;

  static String labelForKind(ExportFileKind kind) => switch (kind) {
    ExportFileKind.guide => 'the guide track',
    ExportFileKind.song => 'the song',
    ExportFileKind.preview => 'the preview mix',
    ExportFileKind.video => 'the guide video',
  };

  /// Title on the error sheet (§7.3).
  String get title => 'Export didn’t finish';

  /// Message body on the error sheet (§7.3).
  String get message => switch (kind) {
    ExportFailureKind.diskFull =>
      'Your phone ran out of space while saving $failedFileLabel. Free up '
          'about $neededMegabytes MB, or save as M4A instead of WAV (much '
          'smaller).',
    ExportFailureKind.interrupted =>
      'The export stopped when KickVolt was closed. Try again and keep the '
          'app open until it’s done.',
    ExportFailureKind.encodeFailed when isVideoFailure =>
      'This phone couldn’t make the guide video. Export without it?',
    ExportFailureKind.encodeFailed =>
      'This phone couldn’t make an M4A of this song. WAV works everywhere.',
    ExportFailureKind.sourceMissing =>
      'The song’s audio file is missing. Re-import the song.',
    ExportFailureKind.other => 'Something went wrong while exporting.',
  };
}

class ExportFailureException implements Exception {
  const ExportFailureException(this.failure);

  final ExportFailure failure;

  @override
  String toString() =>
      'ExportFailureException(${failure.kind.name}): ${failure.detail ?? failure.message}';
}

/// Thrown when an export is cancelled by the user.
class ExportCancelledException implements Exception {
  const ExportCancelledException();

  @override
  String toString() => 'ExportCancelledException';
}
