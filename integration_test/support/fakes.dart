import 'dart:ui' show Rect;

import 'package:kickvolt/core/core.dart';
import 'package:kickvolt/features/features.dart';

/// Stands in for the system file/video pickers: returns whatever the test
/// put in [next]. Everything after the pick (copy, native decode, detection)
/// is the real app.
class FixtureSourcePicker implements SourcePicker {
  PickedSource? next;
  int picks = 0;

  @override
  bool get usesNativeLibraryPicker => false;

  @override
  Future<List<LibraryTrack>> listLibraryTracks() async => const [];

  @override
  Future<PickedSource?> pickFile() async {
    picks++;
    return next;
  }

  @override
  Future<PickedSource?> pickLibraryTrack() async => null;

  @override
  Future<PickedSource?> pickVideo() async {
    picks++;
    return next;
  }
}

/// Records share requests instead of opening the share sheet.
class RecordingShareService implements ShareService {
  final calls = <List<String>>[];

  @override
  Future<void> shareFiles(
    List<String> paths, {
    Rect? sharePositionOrigin,
  }) async {
    calls.add(List.of(paths));
  }
}

/// Records haptic events (the device would buzz otherwise; harmless, but
/// recording lets flows assert on them).
class RecordingHaptics implements Haptics {
  final events = <String>[];

  @override
  Future<void> heavyImpact() async => events.add('heavy');

  @override
  Future<void> lightImpact() async => events.add('light');

  @override
  Future<void> selectionClick() async => events.add('selection');

  @override
  Future<void> successNotification() async => events.add('success');

  @override
  Future<void> warningNotification() async => events.add('warning');
}

/// The real native bridge, except [saveToFiles], which would open the SAF
/// folder picker. Its calls are recorded and it reports every file saved.
class SaveRecordingAudioNative implements AudioNative {
  SaveRecordingAudioNative(this.real);

  final AudioNative real;
  final saveCalls = <List<String>>[];

  @override
  Future<int> saveToFiles(List<String> paths) async {
    saveCalls.add(List.of(paths));
    return paths.length;
  }

  @override
  Future<int> beginBackgroundWork(String name) =>
      real.beginBackgroundWork(name);

  @override
  Future<void> cancel(String jobId) => real.cancel(jobId);

  @override
  Future<void> copyContentUri(String uri, String destPath) =>
      real.copyContentUri(uri, destPath);

  @override
  Future<DecodeResult> decodeToWav({
    required String jobId,
    required String inputPath,
    required String outputPath,
    void Function(double fraction)? onProgress,
  }) => real.decodeToWav(
    jobId: jobId,
    inputPath: inputPath,
    outputPath: outputPath,
    onProgress: onProgress,
  );

  @override
  Future<MediaInfo> encodeM4a({
    required String jobId,
    required String wavPath,
    required String outPath,
    int bitrate = kDefaultM4aBitrate,
    void Function(double fraction)? onProgress,
  }) => real.encodeM4a(
    jobId: jobId,
    wavPath: wavPath,
    outPath: outPath,
    bitrate: bitrate,
    onProgress: onProgress,
  );

  @override
  Future<MediaInfo> encodeGuideVideo({
    required String jobId,
    required GuideVideoSpec spec,
    void Function(double fraction)? onProgress,
  }) => real.encodeGuideVideo(jobId: jobId, spec: spec, onProgress: onProgress);

  @override
  Future<void> endBackgroundWork(int token) => real.endBackgroundWork(token);

  @override
  Future<int> freeDiskBytes(String path) => real.freeDiskBytes(path);

  @override
  Future<List<LibraryTrack>> listMusicLibrary() => real.listMusicLibrary();

  @override
  Future<LibraryTrack?> pickFromMusicLibrary() => real.pickFromMusicLibrary();

  @override
  Future<MediaInfo> probeMedia(String path) => real.probeMedia(path);

  @override
  Future<bool> requestAudioPermission() => real.requestAudioPermission();
}
