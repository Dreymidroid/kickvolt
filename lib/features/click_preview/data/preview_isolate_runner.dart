import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../../core/audio_math/click_synth.dart';
import '../../../core/audio_math/preview_mix.dart';

/// Thrown when a click-preview render is cancelled.
class ClickPreviewCancelledException implements Exception {
  const ClickPreviewCancelledException();

  @override
  String toString() => 'ClickPreviewCancelledException';
}

/// Cooperative cancel token for a click-preview isolate job.
class ClickPreviewCancelToken {
  bool _cancelled = false;
  Future<void> Function()? _onCancel;

  bool get isCancelled => _cancelled;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _onCancel?.call();
  }
}

/// Runs [renderPreviewMix] in a background isolate with cooperative
/// cancellation (matching M4's `runAnalysisInIsolate` pattern).
///
/// Cancelling asks the worker to stop between chunks, so its `finally` block
/// closes both file handles and deletes the `.part` file before it exits; the
/// isolate is only hard-killed after a 2-second grace period. A cancel that
/// arrives while the isolate is still being spawned waits for the spawn and
/// then stops the worker the same way, so no orphan render keeps running (and
/// keeps files open, which blocks folder deletion on Windows).
///
/// When [ClickPreviewCancelToken.cancel] completes, the worker has exited (or
/// been killed) and its files are closed.
Future<PreviewMixStats> runPreviewMixInIsolate({
  required String songWavPath,
  required String outputWavPath,
  required List<int> beatSamples,
  ClickStyle style = ClickStyle.snap,
  double songGain = kPreviewSongGain,
  ClickPreviewCancelToken? cancelToken,
  void Function(double fraction)? onProgress,
}) async {
  if (cancelToken != null && cancelToken.isCancelled) {
    throw const ClickPreviewCancelledException();
  }

  final receivePort = ReceivePort();
  final exitPort = ReceivePort();
  final exited = Completer<void>();
  final workerReady = Completer<SendPort>();
  final spawned = Completer<Isolate?>();
  final completer = Completer<PreviewMixStats>();
  Future<void>? shutdown;

  exitPort.listen((_) {
    if (!exited.isCompleted) exited.complete();
  });

  void closePorts() {
    receivePort.close();
    exitPort.close();
  }

  /// Stops the worker (cooperatively when [cancel] is true) and releases the
  /// ports. Runs at most once.
  Future<void> stopWorker({required bool cancel}) {
    return shutdown ??= () async {
      cancelToken?._onCancel = null;
      final iso = await spawned.future;
      if (iso != null) {
        if (cancel) {
          // The worker sends its cancel port first thing; wait for it (or
          // for the worker to have exited already).
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
        // After done/error the worker exits by itself; wait briefly.
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
  cancelToken?._onCancel = () async {
    cancelling = true;
    await stopWorker(cancel: true);
    if (finishedWhileCancelling) {
      // The worker renamed the finished file just before it saw the cancel.
      try {
        await File(outputWavPath).delete();
      } catch (_) {}
    }
    // Settle only once the worker is gone, so callers can delete the folder.
    if (!completer.isCompleted) {
      completer.completeError(const ClickPreviewCancelledException());
    }
  };

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
        PreviewMixStats(
          sampleRate: message[1] as int,
          channels: message[2] as int,
          frameCount: message[3] as int,
          peakBufferBytes: message[4] as int,
        ),
      );
      unawaited(stopWorker(cancel: false));
    } else if (tag == 'error') {
      final err = message[1] as String;
      completer.completeError(
        err.contains('PreviewMixCancelledException')
            ? const ClickPreviewCancelledException()
            : StateError(err),
      );
      unawaited(stopWorker(cancel: false));
    } else {
      // Uncaught error forwarded by `onError`: [error, stackTrace] strings.
      completer.completeError(StateError(message.join(' ')));
      unawaited(stopWorker(cancel: true));
    }
  });

  try {
    final iso = await Isolate.spawn<_PreviewIsolateRequest>(
      _previewIsolateEntry,
      _PreviewIsolateRequest(
        songWavPath: songWavPath,
        outputWavPath: outputWavPath,
        beatSamples: beatSamples,
        styleIndex: style.index,
        songGain: songGain,
        sendPort: receivePort.sendPort,
      ),
      onError: receivePort.sendPort,
      onExit: exitPort.sendPort,
    );
    spawned.complete(iso);
  } catch (e, st) {
    spawned.complete(null);
    cancelToken?._onCancel = null;
    closePorts();
    if (!completer.isCompleted) completer.completeError(e, st);
  }

  return completer.future;
}

class _PreviewIsolateRequest {
  const _PreviewIsolateRequest({
    required this.songWavPath,
    required this.outputWavPath,
    required this.beatSamples,
    required this.styleIndex,
    required this.songGain,
    required this.sendPort,
  });

  final String songWavPath;
  final String outputWavPath;
  final List<int> beatSamples;
  final int styleIndex;
  final double songGain;
  final SendPort sendPort;
}

Future<void> _previewIsolateEntry(_PreviewIsolateRequest req) async {
  var cancelled = false;
  final cancelPort = ReceivePort();
  cancelPort.listen((_) {
    cancelled = true;
    cancelPort.close();
  });
  req.sendPort.send(<Object?>['init', cancelPort.sendPort]);

  try {
    final stats = await renderPreviewMix(
      songWavPath: req.songWavPath,
      outputWavPath: req.outputWavPath,
      beatSamples: req.beatSamples,
      style: ClickStyle.values[req.styleIndex],
      songGain: req.songGain,
      isCancelled: () => cancelled,
      onProgress: (f) {
        if (!cancelled) {
          req.sendPort.send(<Object?>['progress', f]);
        }
      },
    );
    req.sendPort.send(<Object?>[
      'done',
      stats.sampleRate,
      stats.channels,
      stats.frameCount,
      stats.peakBufferBytes,
    ]);
  } catch (e) {
    req.sendPort.send(<Object?>['error', e.toString()]);
  } finally {
    cancelPort.close();
  }
}
