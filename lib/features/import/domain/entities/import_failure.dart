import '../../../../core/audio_native/audio_native_client.dart';

/// User-facing reasons an import can fail.
enum ImportFailureKind {
  /// Not a format we can read (or an unknown decoder problem).
  unsupported,

  /// Copy-protected (Apple Music / DRM).
  protected,

  /// iOS library song that isn't downloaded.
  notDownloaded,

  /// Video or file without an audio track.
  noAudio,
  diskFull,
  permissionDenied,
  unknown;

  static ImportFailureKind fromAudioError(AudioErrorKind kind) =>
      switch (kind) {
        AudioErrorKind.drmProtected => protected,
        AudioErrorKind.cloudItem => notDownloaded,
        AudioErrorKind.noAudioTrack => noAudio,
        AudioErrorKind.unsupportedFormat ||
        AudioErrorKind.decodeFailed => unsupported,
        AudioErrorKind.diskFull => diskFull,
        AudioErrorKind.permissionDenied => permissionDenied,
        AudioErrorKind.cancelled || AudioErrorKind.unknown => unknown,
      };
}

class ImportFailure implements Exception {
  const ImportFailure(this.kind, {this.fileName, this.detail});

  final ImportFailureKind kind;
  final String? fileName;

  /// Technical detail for logs; not shown to users.
  final String? detail;

  String get title => switch (kind) {
    ImportFailureKind.unsupported => 'Can’t open this file',
    ImportFailureKind.protected => 'This song is copy-protected',
    ImportFailureKind.notDownloaded => 'Song not downloaded',
    ImportFailureKind.noAudio => 'No audio in this file',
    ImportFailureKind.diskFull => 'Your phone is out of space',
    ImportFailureKind.permissionDenied => 'Music access is off',
    ImportFailureKind.unknown => 'Import failed',
  };

  /// Body text; [fileName] is shown in bold before it where relevant.
  String get message => switch (kind) {
    ImportFailureKind.unsupported =>
      'isn’t a format we can read, or it’s copy-protected. Try MP3, M4A, '
          'WAV or AAC, or pull the audio from a video instead.',
    ImportFailureKind.protected =>
      'is protected (for example an Apple Music download), so it can’t be '
          'read. Use a song file you own, or pull the audio from a video.',
    ImportFailureKind.notDownloaded =>
      'is in the cloud. Download it to your phone in the Music app, then '
          'try again.',
    ImportFailureKind.noAudio =>
      'has no sound to work with. Pick a clip that has the song in it.',
    ImportFailureKind.diskFull =>
      'needs more free space than your phone has. Free up some space and '
          'try again.',
    ImportFailureKind.permissionDenied =>
      'Allow KickVolt to read your music in Settings, or import from Files '
          'instead.',
    ImportFailureKind.unknown =>
      'couldn’t be imported. Try again, or try another file.',
  };

  @override
  String toString() => 'ImportFailure(${kind.name}, $fileName): $detail';
}

/// Thrown when the user cancels an import.
class ImportCancelled implements Exception {
  const ImportCancelled();
}
