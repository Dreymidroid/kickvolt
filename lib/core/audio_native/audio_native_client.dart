import 'dart:async';

import 'package:flutter/services.dart';

import 'audio_api.g.dart';

export 'audio_api.g.dart'
    show DecodeResult, GuideVideoSpec, LibraryTrack, MediaInfo;

/// Default bitrate for M4A (AAC-LC) exports: 192 kbps (§5.1).
const int kDefaultM4aBitrate = 192000;

/// Why a native audio call failed. Mirrors the error codes in
/// `pigeons/audio_api.dart`.
enum AudioErrorKind {
  drmProtected,
  cloudItem,
  noAudioTrack,
  unsupportedFormat,
  decodeFailed,
  encodeFailed,
  diskFull,
  permissionDenied,
  cancelled,
  unknown;

  static AudioErrorKind fromCode(String code) => switch (code) {
    'drm_protected' => drmProtected,
    'cloud_item' => cloudItem,
    'no_audio_track' => noAudioTrack,
    'unsupported_format' => unsupportedFormat,
    'decode_failed' => decodeFailed,
    'encode_failed' => encodeFailed,
    'disk_full' => diskFull,
    'permission_denied' => permissionDenied,
    'cancelled' => cancelled,
    _ => unknown,
  };
}

class AudioNativeException implements Exception {
  const AudioNativeException(this.kind, [this.message]);
  final AudioErrorKind kind;
  final String? message;

  @override
  String toString() => 'AudioNativeException(${kind.name}): $message';
}

/// Dart face of the native audio bridge. An interface so repositories can
/// be tested without a platform.
abstract interface class AudioNative {
  /// Decodes [inputPath] to a 16-bit PCM WAV at [outputPath].
  /// [onProgress] receives 0–1. Cancel with [cancel] using the same [jobId].
  Future<DecodeResult> decodeToWav({
    required String jobId,
    required String inputPath,
    required String outputPath,
    void Function(double fraction)? onProgress,
  });

  Future<void> cancel(String jobId);

  /// iOS music library picker. Null when the user cancels.
  Future<LibraryTrack?> pickFromMusicLibrary();

  /// Android MediaStore songs.
  Future<List<LibraryTrack>> listMusicLibrary();

  /// Requests runtime audio/music-library permission. Returns `true` if
  /// granted, `false` if denied.
  Future<bool> requestAudioPermission();

  /// Android: copy a `content://` URI into app storage.
  Future<void> copyContentUri(String uri, String destPath);

  Future<int> freeDiskBytes(String path);

  /// Encodes a 16-bit PCM WAV at [wavPath] to AAC in an MPEG-4 container
  /// (.m4a) at [outPath] with [bitrate] bits/s, preserving sample rate and
  /// channel count. Cancel with [cancel] using the same [jobId].
  Future<MediaInfo> encodeM4a({
    required String jobId,
    required String wavPath,
    required String outPath,
    int bitrate = kDefaultM4aBitrate,
    void Function(double fraction)? onProgress,
  });

  /// Probes duration and format of an audio file as the platform sees it.
  Future<MediaInfo> probeMedia(String path);

  /// Lets the user pick a folder (Android SAF / iOS document picker) and
  /// copies [paths] into it. Returns how many were saved; 0 if cancelled.
  Future<int> saveToFiles(List<String> paths);

  /// iOS: begins a background task so an export can finish when the app is
  /// backgrounded. Android: no-op (returns 0).
  Future<int> beginBackgroundWork(String name);

  /// iOS: ends a background task started by [beginBackgroundWork]. Android: no-op.
  Future<void> endBackgroundWork(int token);

  /// Encodes the M7 guide video described by [spec] (H.264 + the guide WAV as
  /// AAC in an MP4). [onProgress] receives the fraction of frames written.
  /// Cancel with [cancel] using the same [jobId].
  Future<MediaInfo> encodeGuideVideo({
    required String jobId,
    required GuideVideoSpec spec,
    void Function(double fraction)? onProgress,
  });
}

class AudioNativeClient implements AudioNative, AudioProgressApi {
  AudioNativeClient({AudioHostApi? host}) : _host = host ?? AudioHostApi() {
    AudioProgressApi.setUp(this);
  }

  final AudioHostApi _host;
  final _progress = <String, void Function(double)>{};

  @override
  void onProgress(String jobId, double fraction) =>
      _progress[jobId]?.call(fraction);

  @override
  Future<DecodeResult> decodeToWav({
    required String jobId,
    required String inputPath,
    required String outputPath,
    void Function(double fraction)? onProgress,
  }) async {
    if (onProgress != null) _progress[jobId] = onProgress;
    try {
      return await _guard(
        () => _host.decodeToWav(jobId, inputPath, outputPath),
      );
    } finally {
      _progress.remove(jobId);
    }
  }

  @override
  Future<void> cancel(String jobId) => _guard(() => _host.cancelJob(jobId));

  @override
  Future<LibraryTrack?> pickFromMusicLibrary() =>
      _guard(_host.pickFromMusicLibrary);

  @override
  Future<List<LibraryTrack>> listMusicLibrary() =>
      _guard(_host.listMusicLibrary);

  @override
  Future<bool> requestAudioPermission() => _guard(_host.requestAudioPermission);

  @override
  Future<void> copyContentUri(String uri, String destPath) =>
      _guard(() => _host.copyContentUri(uri, destPath));

  @override
  Future<int> freeDiskBytes(String path) =>
      _guard(() => _host.freeDiskBytes(path));

  @override
  Future<MediaInfo> encodeM4a({
    required String jobId,
    required String wavPath,
    required String outPath,
    int bitrate = kDefaultM4aBitrate,
    void Function(double fraction)? onProgress,
  }) async {
    if (onProgress != null) _progress[jobId] = onProgress;
    try {
      return await _guard(
        () => _host.encodeM4a(jobId, wavPath, outPath, bitrate),
      );
    } finally {
      _progress.remove(jobId);
    }
  }

  @override
  Future<MediaInfo> probeMedia(String path) =>
      _guard(() => _host.probeMedia(path));

  @override
  Future<int> saveToFiles(List<String> paths) =>
      _guard(() => _host.saveToFiles(paths));

  @override
  Future<int> beginBackgroundWork(String name) =>
      _guard(() => _host.beginBackgroundWork(name));

  @override
  Future<void> endBackgroundWork(int token) =>
      _guard(() => _host.endBackgroundWork(token));

  @override
  Future<MediaInfo> encodeGuideVideo({
    required String jobId,
    required GuideVideoSpec spec,
    void Function(double fraction)? onProgress,
  }) async {
    if (onProgress != null) _progress[jobId] = onProgress;
    try {
      return await _guard(() => _host.encodeGuideVideo(jobId, spec));
    } finally {
      _progress.remove(jobId);
    }
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw AudioNativeException(AudioErrorKind.fromCode(e.code), e.message);
    }
  }
}
