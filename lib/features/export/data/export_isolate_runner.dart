import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../../core/audio_math/click_synth.dart';
import '../../../core/audio_math/guide_track.dart';
import '../../../core/audio_math/preview_mix.dart';
import '../domain/entities/export_failure.dart';
import '../domain/entities/export_options.dart';

/// Cooperative cancel token for an export job (isolate + native encoder).
class ExportCancelToken {
  bool _cancelled = false;
  final List<Future<void> Function()> _handlers = [];

  bool get isCancelled => _cancelled;

  void addHandler(Future<void> Function() handler) {
    if (_cancelled) {
      unawaited(handler());
      return;
    }
    _handlers.add(handler);
  }

  void removeHandler(Future<void> Function() handler) {
    _handlers.remove(handler);
  }

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    final copy = List<Future<void> Function()>.of(_handlers);
    _handlers.clear();
    for (final h in copy) {
      try {
        await h();
      } catch (_) {}
    }
  }
}

/// Result of rendering one WAV step inside the export isolate.
class ExportStepWavResult {
  const ExportStepWavResult({
    required this.sampleRate,
    required this.channels,
    required this.frameCount,
  });

  final int sampleRate;
  final int channels;
  final int frameCount;
}

/// Runs one WAV export step (`guide`, `song`, or `preview`) in a background
/// isolate with cooperative cancellation and a 2-second grace period before
/// hard kill (§4.7, §3 lesson from M5).
///
/// Guarantees that when [cancelToken.cancel] completes, the worker isolate has
/// exited and all open file handles in the pack folder are closed so the folder
/// can be deleted immediately on Windows.
Future<ExportStepWavResult> runExportStepInIsolate({
  required ExportFileKind kind,
  required String songWavPath,
  required String outputWavPath,
  required List<int> beatSamples,
  required ClickStyle style,
  required int guideChannels,
  int? expectedProjectSampleCount,
  ExportCancelToken? cancelToken,
  void Function(double fraction)? onProgress,
}) async {
  if (cancelToken != null && cancelToken.isCancelled) {
    throw const ExportCancelledException();
  }

  final receivePort = ReceivePort();
  final exitPort = ReceivePort();
  final exited = Completer<void>();
  final workerReady = Completer<SendPort>();
  final spawned = Completer<Isolate?>();
  final completer = Completer<ExportStepWavResult>();
  Future<void>? shutdown;

  exitPort.listen((_) {
    if (!exited.isCompleted) exited.complete();
  });

  void closePorts() {
    receivePort.close();
    exitPort.close();
  }

  late final Future<void> Function() onCancelHandler;

  Future<void> stopWorker({required bool cancel}) {
    return shutdown ??= () async {
      cancelToken?.removeHandler(onCancelHandler);
      final iso = await spawned.future;
      if (iso != null) {
        if (cancel) {
          await Future.any<Object?>([workerReady.future, exited.future])
              .timeout(const Duration(seconds: 2), onTimeout: () => null);
          if (workerReady.isCompleted && !exited.isCompleted) {
            (await workerReady.future).send(true);
          }
          await exited.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () => iso.kill(priority: Isolate.immediate),
          );
        }
        await exited.future.timeout(
          const Duration(milliseconds: 300),
          onTimeout: () {},
        );
      }
      closePorts();
    }();
  }

  var cancelling = false;
  var finishedWhileCancelling = false;
  onCancelHandler = () async {
    cancelling = true;
    await stopWorker(cancel: true);
    if (finishedWhileCancelling) {
      try {
        final f = File(outputWavPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    try {
      final part = File('$outputWavPath.part');
      if (await part.exists()) await part.delete();
    } catch (_) {}
    if (!completer.isCompleted) {
      completer.completeError(const ExportCancelledException());
    }
  };
  cancelToken?.addHandler(onCancelHandler);

  receivePort.listen((Object? message) {
    if (message is! List<Object?> || message.isEmpty) return;
    final tag = message[0];
    if (tag == 'init') {
      if (!workerReady.isCompleted) {
        workerReady.complete(message[1] as SendPort);
      }
      return;
    }
    if (cancelling && tag == 'done') finishedWhileCancelling = true;
    if (completer.isCompleted || cancelling) return;
    if (tag == 'progress') {
      onProgress?.call((message[1] as num).toDouble().clamp(0.0, 1.0));
    } else if (tag == 'done') {
      completer.complete(
        ExportStepWavResult(
          sampleRate: message[1] as int,
          channels: message[2] as int,
          frameCount: message[3] as int,
        ),
      );
      unawaited(stopWorker(cancel: false));
    } else if (tag == 'error') {
      final kindTag = message[1] as String;
      final detail = message[2] as String;
      if (kindTag == 'cancelled') {
        completer.completeError(const ExportCancelledException());
      } else if (kindTag == 'enospc') {
        completer.completeError(
          FileSystemException(
            detail,
            outputWavPath,
            const OSError('No space left on device', 28),
          ),
        );
      } else {
        completer.completeError(StateError(detail));
      }
      unawaited(stopWorker(cancel: false));
    } else {
      completer.completeError(StateError(message.join(' ')));
      unawaited(stopWorker(cancel: true));
    }
  });

  try {
    final iso = await Isolate.spawn<_ExportStepIsolateRequest>(
      _exportStepIsolateEntry,
      _ExportStepIsolateRequest(
        kindIndex: kind.index,
        songWavPath: songWavPath,
        outputWavPath: outputWavPath,
        beatSamples: beatSamples,
        styleIndex: style.index,
        guideChannels: guideChannels,
        expectedProjectSampleCount: expectedProjectSampleCount,
        sendPort: receivePort.sendPort,
      ),
      onError: receivePort.sendPort,
      onExit: exitPort.sendPort,
    );
    spawned.complete(iso);
  } catch (e, st) {
    spawned.complete(null);
    cancelToken?.removeHandler(onCancelHandler);
    closePorts();
    if (!completer.isCompleted) completer.completeError(e, st);
  }

  return completer.future;
}

class _ExportStepIsolateRequest {
  const _ExportStepIsolateRequest({
    required this.kindIndex,
    required this.songWavPath,
    required this.outputWavPath,
    required this.beatSamples,
    required this.styleIndex,
    required this.guideChannels,
    required this.expectedProjectSampleCount,
    required this.sendPort,
  });

  final int kindIndex;
  final String songWavPath;
  final String outputWavPath;
  final List<int> beatSamples;
  final int styleIndex;
  final int guideChannels;
  final int? expectedProjectSampleCount;
  final SendPort sendPort;
}

Future<void> _exportStepIsolateEntry(_ExportStepIsolateRequest req) async {
  var cancelled = false;
  final cancelPort = ReceivePort();
  cancelPort.listen((_) {
    cancelled = true;
    cancelPort.close();
  });
  req.sendPort.send(<Object?>['init', cancelPort.sendPort]);

  final kind = ExportFileKind.values[req.kindIndex];
  final style = ClickStyle.values[req.styleIndex];

  void sendProgress(double f) {
    if (!cancelled) {
      req.sendPort.send(<Object?>['progress', f]);
    }
  }

  try {
    switch (kind) {
      case ExportFileKind.guide:
        final stats = await renderGuideTrack(
          songWavPath: req.songWavPath,
          outputWavPath: req.outputWavPath,
          beatSamples: req.beatSamples,
          style: style,
          channels: req.guideChannels,
          expectedProjectSampleCount: req.expectedProjectSampleCount,
          isCancelled: () => cancelled,
          onProgress: sendProgress,
        );
        req.sendPort.send(<Object?>[
          'done',
          stats.sampleRate,
          stats.channels,
          stats.frameCount,
        ]);

      case ExportFileKind.song:
        final info = await copySongWavStreaming(
          songWavPath: req.songWavPath,
          outputWavPath: req.outputWavPath,
          isCancelled: () => cancelled,
          onProgress: sendProgress,
        );
        req.sendPort.send(<Object?>[
          'done',
          info.sampleRate,
          info.channels,
          info.frameCount,
        ]);

      case ExportFileKind.preview:
        final stats = await renderPreviewMix(
          songWavPath: req.songWavPath,
          outputWavPath: req.outputWavPath,
          beatSamples: req.beatSamples,
          style: style,
          isCancelled: () => cancelled,
          onProgress: sendProgress,
        );
        req.sendPort.send(<Object?>[
          'done',
          stats.sampleRate,
          stats.channels,
          stats.frameCount,
        ]);
    }
  } on GuideTrackCancelledException {
    req.sendPort.send(<Object?>['error', 'cancelled', 'Cancelled']);
  } on PreviewMixCancelledException {
    req.sendPort.send(<Object?>['error', 'cancelled', 'Cancelled']);
  } on FileSystemException catch (e) {
    final isEnospc = e.osError?.errorCode == 28 ||
        (e.osError?.message.toLowerCase().contains('no space') ?? false);
    req.sendPort.send(<Object?>[
      'error',
      isEnospc ? 'enospc' : 'other',
      e.toString(),
    ]);
  } catch (e) {
    req.sendPort.send(<Object?>['error', 'other', e.toString()]);
  } finally {
    cancelPort.close();
  }
}
