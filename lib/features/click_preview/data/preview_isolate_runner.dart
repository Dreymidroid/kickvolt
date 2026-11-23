import 'dart:async';
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
/// Signals the worker to stop between chunks so its `finally` block closes
/// both file handles and deletes the `.part` file before exiting; falls back
/// to `Isolate.immediate` kill only after a 2-second grace period.
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
  final exitCompleter = Completer<void>();
  final completer = Completer<PreviewMixStats>();
  Isolate? isolate;
  SendPort? workerCancelPort;
  var finished = false;

  exitPort.listen((_) {
    exitPort.close();
    if (!exitCompleter.isCompleted) {
      exitCompleter.complete();
    }
  });

  Future<void> cleanUp({bool isCancel = false}) async {
    if (!finished) {
      finished = true;
      cancelToken?._onCancel = null;
      final iso = isolate;
      isolate = null;
      if (iso != null) {
        if (isCancel && workerCancelPort != null) {
          workerCancelPort!.send(true);
          await exitCompleter.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              iso.kill(priority: Isolate.immediate);
            },
          );
        } else {
          iso.kill(priority: Isolate.immediate);
        }
        await exitCompleter.future.timeout(
          const Duration(milliseconds: 300),
          onTimeout: () {},
        );
      } else {
        exitPort.close();
      }
      receivePort.close();
    } else if (isCancel) {
      await exitCompleter.future.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () {},
      );
    }
  }

  cancelToken?._onCancel = () async {
    await cleanUp(isCancel: true);
    if (!completer.isCompleted) {
      completer.completeError(const ClickPreviewCancelledException());
    }
  };

  receivePort.listen((Object? message) {
    if (message is List<Object?>) {
      final tag = message[0];
      if (tag == 'init') {
        workerCancelPort = message[1] as SendPort;
        if (cancelToken != null && cancelToken.isCancelled) {
          workerCancelPort?.send(true);
        }
        return;
      }
      if (finished || completer.isCompleted) return;
      if (tag == 'progress') {
        onProgress?.call((message[1] as num).toDouble().clamp(0.0, 1.0));
      } else if (tag == 'done') {
        final stats = PreviewMixStats(
          sampleRate: message[1] as int,
          channels: message[2] as int,
          frameCount: message[3] as int,
          peakBufferBytes: message[4] as int,
        );
        unawaited(cleanUp());
        completer.complete(stats);
      } else if (tag == 'error') {
        final err = message[1] as String;
        unawaited(cleanUp());
        if (err.contains('PreviewMixCancelledException')) {
          completer.completeError(const ClickPreviewCancelledException());
        } else {
          completer.completeError(StateError(err));
        }
      }
    }
  });

  try {
    isolate = await Isolate.spawn<_PreviewIsolateRequest>(
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
    if (cancelToken != null && cancelToken.isCancelled) {
      await cleanUp(isCancel: true);
      if (!completer.isCompleted) {
        completer.completeError(const ClickPreviewCancelledException());
      }
    }
  } catch (e, st) {
    await cleanUp();
    if (!completer.isCompleted) {
      completer.completeError(e, st);
    }
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
