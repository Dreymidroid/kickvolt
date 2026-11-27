import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../../../core/audio_math/wav_header.dart';
import '../../../../core/audio_native/audio_native_client.dart';
import '../../../../core/storage/project_paths.dart';
import '../../../projects/domain/entities/project.dart';
import '../../domain/beat_pack_plan.dart';
import '../../domain/entities/beat_pack.dart';
import '../../domain/entities/export_failure.dart';
import '../../domain/entities/export_options.dart';
import '../export_isolate_runner.dart';

/// Safety margin added to disk space pre-checks: 20 MB (§4.7).
const int kExportDiskMarginBytes = 20 * 1024 * 1024;

/// Maximum number of finished beat-pack folders kept per project (§4.6).
const int kMaxSavedPacksPerProject = 3;

/// Runs a [BeatPackPlan]: renders into `exports/<packId>/*.part`, encodes if
/// M4A, renames, verifies every file from disk, and returns the finished
/// [BeatPack] (§4.1, §4.7).
abstract interface class ExportRepository {
  Future<BeatPack> export(
    Project project,
    ExportOptions options, {
    required ExportCancelToken cancel,
    void Function(ExportProgress)? onProgress,
  });

  /// Called at app start: deletes pack folders that contain any `.part` file
  /// or are empty (§4.1, §4.7).
  Future<void> cleanUpStaleParts();

  /// Lists finished beat packs for [projectId], newest first (§4.1).
  Future<List<BeatPack>> packsFor(String projectId);
}

class ExportRepositoryImpl implements ExportRepository {
  ExportRepositoryImpl({
    required this._audio,
    required this._paths,
    DateTime Function()? clock,
    this.renderHookForTesting,
  }) : _clock = clock ?? DateTime.now;

  final AudioNative _audio;
  final Future<ProjectPaths> Function() _paths;
  final DateTime Function() _clock;

  /// Optional test hook invoked right before each file step is rendered.
  final Future<void> Function(PlannedExportFile step)? renderHookForTesting;

  int _packCounter = 0;

  @override
  Future<BeatPack> export(
    Project project,
    ExportOptions options, {
    required ExportCancelToken cancel,
    void Function(ExportProgress)? onProgress,
  }) async {
    if (cancel.isCancelled) {
      throw const ExportCancelledException();
    }

    final projectPaths = await _paths();
    final songWavPath = projectPaths.songWav(project.id);
    final songFile = File(songWavPath);
    if (!await songFile.exists()) {
      throw const ExportFailureException(
        ExportFailure(kind: ExportFailureKind.sourceMissing),
      );
    }

    // Read the actual header of song.wav so the file always wins if
    // project.sampleCount disagrees (§4.3).
    final WavInfo sourceInfo;
    try {
      sourceInfo = await readWavInfo(songFile);
    } catch (e) {
      throw ExportFailureException(
        ExportFailure(
          kind: ExportFailureKind.sourceMissing,
          detail: e.toString(),
        ),
      );
    }

    final effectiveProject =
        (sourceInfo.frameCount != project.sampleCount ||
            sourceInfo.sampleRate != project.sampleRate ||
            sourceInfo.channels != project.channels)
        ? project.copyWith(
            sampleRate: sourceInfo.sampleRate,
            channels: sourceInfo.channels,
            sampleCount: sourceInfo.frameCount,
          )
        : project;

    final plan = planBeatPack(effectiveProject, options);
    final exportsDirPath = projectPaths.exportsDir(project.id);

    // Pre-check disk space before writing anything (§4.7).
    final neededBytes = plan.estimatedDiskBytes + kExportDiskMarginBytes;
    final neededMb = math.max(10, (neededBytes / (1024 * 1024)).ceil());
    final freeBytes = await _audio.freeDiskBytes(exportsDirPath);
    if (freeBytes < neededBytes) {
      final firstKind = plan.files.isNotEmpty
          ? plan.files.first.kind
          : ExportFileKind.guide;
      throw ExportFailureException(
        ExportFailure(
          kind: ExportFailureKind.diskFull,
          failedFileLabel: ExportFailure.labelForKind(firstKind),
          neededMegabytes: neededMb,
        ),
      );
    }

    final stamp = _formatStamp(_clock(), ++_packCounter);
    final packDirPath = projectPaths.exportPackDir(project.id, stamp);
    final packDir = Directory(packDirPath);

    int? bgToken;
    try {
      bgToken = await _audio.beginBackgroundWork('kickvolt_export_$stamp');
    } catch (_) {}

    var currentKind = plan.files.isNotEmpty
        ? plan.files.first.kind
        : ExportFileKind.guide;
    var succeeded = false;

    try {
      await packDir.create(recursive: true);

      final stepCount = math.max(1, plan.files.length);
      final fileFractions = List<double>.filled(plan.files.length, 0.0);
      final fileCompleted = List<bool>.filled(plan.files.length, false);

      void emitProgress(int activeIndex, String stepText) {
        if (onProgress == null || cancel.isCancelled) return;
        // Weight each step by frames (all steps share the song's frameCount,
        // so equal frame weights across planned files).
        var total = 0.0;
        for (final f in fileFractions) {
          total += f.clamp(0.0, 1.0);
        }
        final overall = (total / stepCount).clamp(0.0, 1.0);
        onProgress(
          ExportProgress(
            overallFraction: overall,
            stepText: stepText,
            files: [
              for (var i = 0; i < plan.files.length; i++)
                ExportFileProgress(
                  kind: plan.files[i].kind,
                  fileName: plan.files[i].fileName,
                  fraction: fileFractions[i].clamp(0.0, 1.0),
                  completed: fileCompleted[i],
                ),
            ],
          ),
        );
      }

      final initialStepText = _stepTextFor(
        currentKind,
        options.format,
        plan.clickCount,
        encodingM4a: false,
      );
      emitProgress(0, initialStepText);

      // Render (and if M4A, encode) each file into `<finalName>.part` inside
      // packDir. Only after all files finish do we rename `*.part` -> final
      // names and re-verify every file from disk (§4.7 Atomicity).
      final stagedPartPaths = <String>[];
      final finalPaths = <String>[];

      for (var i = 0; i < plan.files.length; i++) {
        if (cancel.isCancelled) throw const ExportCancelledException();

        final step = plan.files[i];
        currentKind = step.kind;
        final finalPath = p.join(packDirPath, step.fileName);
        final stagedPartPath = '$finalPath.part';
        stagedPartPaths.add(stagedPartPath);
        finalPaths.add(finalPath);

        if (renderHookForTesting != null) {
          await renderHookForTesting!(step);
        }

        if (options.format == AudioFormat.wav) {
          final stepText = _stepTextFor(
            step.kind,
            options.format,
            plan.clickCount,
            encodingM4a: false,
          );
          emitProgress(i, stepText);

          // runExportStepInIsolate writes `<outputWavPath>.part` and renames to
          // `outputWavPath`. We pass `stagedPartPath` so the file stays a `.part`
          // until all files in the pack are ready to be atomically renamed.
          await runExportStepInIsolate(
            kind: step.kind,
            songWavPath: songWavPath,
            outputWavPath: stagedPartPath,
            beatSamples: plan.visibleBeatSamples,
            style: options.clickStyle,
            guideChannels: step.channels,
            expectedProjectSampleCount: project.sampleCount,
            cancelToken: cancel,
            onProgress: (f) {
              fileFractions[i] = f;
              emitProgress(i, stepText);
            },
          );
        } else {
          // M4A: render intermediate WAV (for guide and preview; for song we
          // can encode straight from song.wav, or render intermediate WAV for
          // guide/preview and delete it right after encoding).
          final String wavInputForEncode;
          String? transientWavToDelete;

          if (step.kind == ExportFileKind.song) {
            wavInputForEncode = songWavPath;
          } else {
            final transientWav = p.join(
              packDirPath,
              '_transient_${step.kind.name}.wav',
            );
            transientWavToDelete = transientWav;
            final renderText = _stepTextFor(
              step.kind,
              options.format,
              plan.clickCount,
              encodingM4a: false,
            );
            emitProgress(i, renderText);

            await runExportStepInIsolate(
              kind: step.kind,
              songWavPath: songWavPath,
              outputWavPath: transientWav,
              beatSamples: plan.visibleBeatSamples,
              style: options.clickStyle,
              guideChannels: step.channels,
              expectedProjectSampleCount: project.sampleCount,
              cancelToken: cancel,
              onProgress: (f) {
                fileFractions[i] = f * 0.5;
                emitProgress(i, renderText);
              },
            );
            wavInputForEncode = transientWav;
          }

          if (cancel.isCancelled) throw const ExportCancelledException();

          final encodeText = _stepTextFor(
            step.kind,
            options.format,
            plan.clickCount,
            encodingM4a: true,
          );
          final baseFrac = step.kind == ExportFileKind.song ? 0.0 : 0.5;
          final spanFrac = step.kind == ExportFileKind.song ? 1.0 : 0.5;
          emitProgress(i, encodeText);

          final jobId = 'm4a-$stamp-${step.kind.name}';
          Future<void> cancelNative() => _audio.cancel(jobId);
          cancel.addHandler(cancelNative);
          try {
            await _audio.encodeM4a(
              jobId: jobId,
              wavPath: wavInputForEncode,
              outPath: stagedPartPath,
              onProgress: (f) {
                fileFractions[i] = baseFrac + f.clamp(0.0, 1.0) * spanFrac;
                emitProgress(i, encodeText);
              },
            );
          } finally {
            cancel.removeHandler(cancelNative);
            if (transientWavToDelete != null) {
              try {
                final f = File(transientWavToDelete);
                if (await f.exists()) await f.delete();
              } catch (_) {}
            }
          }
        }

        fileFractions[i] = 1.0;
        fileCompleted[i] = true;
        emitProgress(
          i,
          _stepTextFor(
            step.kind,
            options.format,
            plan.clickCount,
            encodingM4a: options.format == AudioFormat.m4a,
          ),
        );
      }

      if (cancel.isCancelled) throw const ExportCancelledException();

      // Atomic commit: rename every staged `.part` file to its final name, then
      // re-read and verify every file from disk (§4.7).
      final exportedFiles = <ExportedFile>[];
      for (var i = 0; i < plan.files.length; i++) {
        final step = plan.files[i];
        currentKind = step.kind;
        final stagedFile = File(stagedPartPaths[i]);
        final finalPath = finalPaths[i];
        await stagedFile.rename(finalPath);

        final finalFile = File(finalPath);
        final byteSize = await finalFile.length();
        final int verifiedFrames;

        if (options.format == AudioFormat.wav) {
          final info = await readWavInfo(finalFile);
          if (info.sampleRate != sourceInfo.sampleRate ||
              info.frameCount != sourceInfo.frameCount ||
              info.channels != step.channels) {
            throw StateError(
              'Exported WAV verification failed for ${step.fileName}: '
              'got $info, expected ${sourceInfo.sampleRate} Hz / '
              '${step.channels} ch / ${sourceInfo.frameCount} frames.',
            );
          }
          verifiedFrames = info.frameCount;
        } else {
          final media = await _audio.probeMedia(finalPath);
          if (media.sampleRate != sourceInfo.sampleRate ||
              media.channels != step.channels) {
            throw const AudioNativeException(
              AudioErrorKind.encodeFailed,
              'Encoded M4A format mismatch.',
            );
          }
          verifiedFrames = media.frameCount ?? sourceInfo.frameCount;
        }

        exportedFiles.add(
          ExportedFile(
            path: finalPath,
            kind: step.kind,
            displayName: step.fileName,
            frameCount: verifiedFrames,
            byteSize: byteSize,
            clickCount: step.clickCount,
          ),
        );
      }

      succeeded = true;
      await _pruneOldPacks(exportsDirPath);

      return BeatPack(
        projectId: project.id,
        packId: stamp,
        directoryPath: packDirPath,
        format: options.format,
        sampleRate: sourceInfo.sampleRate,
        frameCount: sourceInfo.frameCount,
        durationMs: effectiveProject.durationMs,
        clickCount: plan.clickCount,
        files: exportedFiles,
      );
    } on ExportCancelledException {
      rethrow;
    } on ExportFailureException {
      rethrow;
    } on AudioNativeException catch (e) {
      if (cancel.isCancelled || e.kind == AudioErrorKind.cancelled) {
        throw const ExportCancelledException();
      }
      if (e.kind == AudioErrorKind.diskFull) {
        throw ExportFailureException(
          ExportFailure(
            kind: ExportFailureKind.diskFull,
            failedFileLabel: ExportFailure.labelForKind(currentKind),
            neededMegabytes: neededMb,
          ),
        );
      }
      if (e.kind == AudioErrorKind.encodeFailed ||
          e.kind == AudioErrorKind.unsupportedFormat) {
        throw ExportFailureException(
          ExportFailure(
            kind: ExportFailureKind.encodeFailed,
            detail: e.message,
          ),
        );
      }
      throw ExportFailureException(
        ExportFailure(
          kind: ExportFailureKind.other,
          detail: e.message ?? e.toString(),
        ),
      );
    } on FileSystemException catch (e) {
      if (cancel.isCancelled) throw const ExportCancelledException();
      final isEnospc =
          e.osError?.errorCode == 28 ||
          (e.osError?.message.toLowerCase().contains('no space') ?? false) ||
          e.message.toLowerCase().contains('no space');
      if (isEnospc) {
        throw ExportFailureException(
          ExportFailure(
            kind: ExportFailureKind.diskFull,
            failedFileLabel: ExportFailure.labelForKind(currentKind),
            neededMegabytes: neededMb,
          ),
        );
      }
      throw ExportFailureException(
        ExportFailure(kind: ExportFailureKind.other, detail: e.message),
      );
    } catch (e) {
      if (cancel.isCancelled) throw const ExportCancelledException();
      throw ExportFailureException(
        ExportFailure(kind: ExportFailureKind.other, detail: e.toString()),
      );
    } finally {
      if (bgToken != null) {
        try {
          await _audio.endBackgroundWork(bgToken);
        } catch (_) {}
      }
      if (!succeeded) {
        try {
          if (await packDir.exists()) {
            await packDir.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> cleanUpStaleParts() async {
    final projectPaths = await _paths();
    final projectsRoot = Directory(projectPaths.projectsDir);
    if (!await projectsRoot.exists()) return;

    await for (final projEntity in projectsRoot.list()) {
      if (projEntity is! Directory) continue;
      final exportsDir = Directory(p.join(projEntity.path, 'exports'));
      if (!await exportsDir.exists()) continue;

      await for (final packEntity in exportsDir.list()) {
        if (packEntity is! Directory) continue;
        final children = await packEntity.list().toList();
        final hasPartOrTransient = children.any((e) {
          final name = p.basename(e.path);
          return name.endsWith('.part') || name.startsWith('_transient_');
        });
        if (children.isEmpty || hasPartOrTransient) {
          try {
            await packEntity.delete(recursive: true);
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<List<BeatPack>> packsFor(String projectId) async {
    final projectPaths = await _paths();
    final exportsDir = Directory(projectPaths.exportsDir(projectId));
    if (!await exportsDir.exists()) return const [];

    final packDirs = <Directory>[];
    await for (final entity in exportsDir.list()) {
      if (entity is Directory) packDirs.add(entity);
    }
    packDirs.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));

    final result = <BeatPack>[];
    for (final dir in packDirs) {
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      if (files.isEmpty ||
          files.any(
            (f) =>
                f.path.endsWith('.part') ||
                p.basename(f.path).startsWith('_transient_'),
          )) {
        continue;
      }
      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      final exported = <ExportedFile>[];
      var format = AudioFormat.wav;
      for (final f in files) {
        final name = p.basename(f.path);
        if (name.endsWith('.m4a')) format = AudioFormat.m4a;
        final kind = name.contains('_beats.')
            ? ExportFileKind.guide
            : name.contains('_preview.')
            ? ExportFileKind.preview
            : ExportFileKind.song;
        exported.add(
          ExportedFile(
            path: f.path,
            kind: kind,
            displayName: name,
            frameCount: 0,
            byteSize: await f.length(),
          ),
        );
      }
      result.add(
        BeatPack(
          projectId: projectId,
          packId: p.basename(dir.path),
          directoryPath: dir.path,
          format: format,
          sampleRate: 44100,
          frameCount: 0,
          durationMs: 0,
          clickCount: 0,
          files: exported,
        ),
      );
    }
    return result;
  }

  Future<void> _pruneOldPacks(String exportsDirPath) async {
    final exportsDir = Directory(exportsDirPath);
    if (!await exportsDir.exists()) return;

    final packDirs = <Directory>[];
    await for (final entity in exportsDir.list()) {
      if (entity is Directory) packDirs.add(entity);
    }
    if (packDirs.length <= kMaxSavedPacksPerProject) return;

    packDirs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final toDelete = packDirs.length - kMaxSavedPacksPerProject;
    for (var i = 0; i < toDelete; i++) {
      try {
        await packDirs[i].delete(recursive: true);
      } catch (_) {}
    }
  }

  static String _stepTextFor(
    ExportFileKind kind,
    AudioFormat format,
    int clickCount, {
    required bool encodingM4a,
  }) {
    final clicksLabel = '$clickCount ${clickCount == 1 ? 'click' : 'clicks'}';
    return switch (kind) {
      ExportFileKind.guide =>
        encodingM4a ? 'Encoding guide track…' : 'Placing $clicksLabel…',
      ExportFileKind.song =>
        format == AudioFormat.m4a ? 'Encoding song…' : 'Copying song…',
      ExportFileKind.preview =>
        encodingM4a ? 'Encoding preview mix…' : 'Mixing preview…',
    };
  }

  static String _formatStamp(DateTime dt, int seq) {
    final u = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final base =
        '${u.year}${two(u.month)}${two(u.day)}-'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}';
    return seq <= 1 ? base : '$base-${seq.toString().padLeft(2, '0')}';
  }
}
