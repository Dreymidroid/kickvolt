import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../../core/audio_math/wav_header.dart';
import '../../../../core/audio_native/audio_native_client.dart';
import '../../../../core/storage/project_paths.dart';
import '../../domain/entities/import_failure.dart';
import '../../domain/entities/imported_song.dart';
import '../../domain/entities/picked_source.dart';

/// Lets the UI stop an import that is running.
class ImportCancelToken {
  bool _cancelled = false;
  Future<void> Function()? _onCancel;

  bool get isCancelled => _cancelled;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _onCancel?.call();
  }
}

abstract interface class ImportRepository {
  /// Copies [source] into a new project folder and decodes it to
  /// `song.wav`. Throws [ImportFailure] or [ImportCancelled]; on any failure
  /// the project folder is removed.
  Future<ImportedSong> importSong(
    PickedSource source, {
    void Function(double fraction)? onProgress,
    ImportCancelToken? cancelToken,
  });
}

class ImportRepositoryImpl implements ImportRepository {
  ImportRepositoryImpl({
    required this._audio,
    required this._paths,
    String Function()? newId,
  }) : _newId = newId ?? const Uuid().v4;

  final AudioNative _audio;
  final Future<ProjectPaths> Function() _paths;
  final String Function() _newId;

  /// Copying is ~5% of the bar; decoding the rest.
  static const _copyShare = 0.05;
  static const _spaceMargin = 20 * 1024 * 1024;

  @override
  Future<ImportedSong> importSong(
    PickedSource source, {
    void Function(double fraction)? onProgress,
    ImportCancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? ImportCancelToken();
    final paths = await _paths();
    final id = _newId();
    final jobId = 'import-$id';
    await paths.createProjectDir(id);

    void checkCancelled() {
      if (token.isCancelled) throw const ImportCancelled();
    }

    try {
      onProgress?.call(0);
      String? copyPath;
      String decodeInput;
      if (source.isLibraryAssetUrl) {
        decodeInput = source.location;
      } else {
        copyPath = paths.sourceFile(id, source.extension);
        await _copySource(source, copyPath, paths.projectDir(id));
        decodeInput = copyPath;
      }
      checkCancelled();
      onProgress?.call(_copyShare);

      token._onCancel = () => _audio.cancel(jobId);
      final wavPath = paths.songWav(id);
      final result = await _audio.decodeToWav(
        jobId: jobId,
        inputPath: decodeInput,
        outputPath: wavPath,
        onProgress: (f) => onProgress?.call(_copyShare + f * (1 - _copyShare)),
      );
      token._onCancel = null;
      checkCancelled();

      final info = await _verify(wavPath, result, source);
      onProgress?.call(1);
      return ImportedSong(
        projectId: id,
        title: source.title,
        source: source,
        sourceCopyPath: copyPath,
        wavPath: wavPath,
        sampleRate: info.sampleRate,
        channels: info.channels,
        frameCount: info.frameCount,
      );
    } on AudioNativeException catch (e) {
      await paths.deleteProject(id);
      if (e.kind == AudioErrorKind.cancelled || token.isCancelled) {
        throw const ImportCancelled();
      }
      throw ImportFailure(
        ImportFailureKind.fromAudioError(e.kind),
        fileName: source.displayName,
        detail: e.message,
      );
    } on FileSystemException catch (e) {
      await paths.deleteProject(id);
      throw ImportFailure(
        _isNoSpace(e) ? ImportFailureKind.diskFull : ImportFailureKind.unknown,
        fileName: source.displayName,
        detail: e.toString(),
      );
    } catch (_) {
      await paths.deleteProject(id);
      rethrow;
    }
  }

  Future<void> _copySource(
    PickedSource source,
    String dest,
    String projectDir,
  ) async {
    if (source.isContentUri) {
      await _audio.copyContentUri(source.location, dest);
      return;
    }
    final file = File(source.location);
    if (!await file.exists()) {
      throw ImportFailure(
        ImportFailureKind.unsupported,
        fileName: source.displayName,
        detail: 'Picked file is gone: ${source.location}',
      );
    }
    final size = await file.length();
    final free = await _audio.freeDiskBytes(projectDir);
    if (free < size + _spaceMargin) {
      throw ImportFailure(
        ImportFailureKind.diskFull,
        fileName: source.displayName,
        detail: 'Need ${size + _spaceMargin} bytes, have $free',
      );
    }
    await file.copy(dest);
  }

  /// Reads the WAV back so the project's timebase comes from the file on
  /// disk, not from what the decoder said it wrote.
  Future<WavInfo> _verify(
    String wavPath,
    DecodeResult result,
    PickedSource source,
  ) async {
    final WavInfo info;
    try {
      info = await readWavInfo(File(wavPath));
    } on WavFormatException catch (e) {
      throw ImportFailure(
        ImportFailureKind.unsupported,
        fileName: source.displayName,
        detail: 'Decoder wrote an invalid WAV: $e',
      );
    }
    if (info.bitsPerSample != 16 ||
        info.frameCount == 0 ||
        info.frameCount != result.frameCount ||
        info.sampleRate != result.sampleRate ||
        info.channels != result.channels) {
      throw ImportFailure(
        ImportFailureKind.unsupported,
        fileName: source.displayName,
        detail:
            'WAV $info does not match decoder result '
            '${result.sampleRate}/${result.channels}/${result.frameCount}',
      );
    }
    return info;
  }

  static bool _isNoSpace(FileSystemException e) {
    final code = e.osError?.errorCode;
    // ENOSPC is 28 on Linux/Android and iOS/macOS.
    return code == 28 || (e.osError?.message.contains('No space') ?? false);
  }
}
