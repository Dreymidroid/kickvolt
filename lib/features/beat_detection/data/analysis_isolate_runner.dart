import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../domain/beat_analyzer.dart';
import '../domain/entities/beat_analysis.dart';
import 'analysis_cache_codec.dart';

/// Token to cancel a running beat analysis isolate job.
class AnalysisCancelToken {
  bool _cancelled = false;
  Future<void> Function()? _onCancel;

  bool get isCancelled => _cancelled;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _onCancel?.call();
  }
}

/// Runs [analyzeWavFile] in a dedicated background isolate (`Isolate.spawn`)
/// with live [onProgress] updates via a `SendPort` and cancellation via
/// cooperative cancel + `Isolate.kill` (§4.9).
///
/// Signals the worker isolate to abort its current chunk and close its
/// `RandomAccessFile` cleanly in its `finally` block (releasing the file lock
/// on Windows), then kills the isolate with `Isolate.immediate` as a hard
/// fallback.
Future<BeatAnalysis> runAnalysisInIsolate(
  String wavPath, {
  void Function(AnalysisProgress progress)? onProgress,
  AnalysisCancelToken? cancelToken,
}) async {
  if (cancelToken != null && cancelToken.isCancelled) {
    throw const AnalysisCancelledException();
  }

  final receivePort = ReceivePort();
  final exitPort = ReceivePort();
  final exitCompleter = Completer<void>();
  final completer = Completer<BeatAnalysis>();
  Isolate? isolate;
  SendPort? workerCancelPort;
  var finished = false;
  var lastFraction = 0.0;

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
          // Ask the worker to throw AnalysisCancelledException at its next
          // chunk check so its `finally { await raf.close(); }` runs first.
          workerCancelPort!.send(true);
          await exitCompleter.future.timeout(
            const Duration(milliseconds: 120),
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
      completer.completeError(const AnalysisCancelledException());
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
        final stageIdx = message[1] as int;
        final rawFraction = (message[2] as num).toDouble().clamp(0.0, 1.0);
        final bpm = message[3] as double?;
        final frac = rawFraction > lastFraction ? rawFraction : lastFraction;
        lastFraction = frac;
        onProgress?.call(
          AnalysisProgress(
            stage: AnalysisStage.values[stageIdx],
            fraction: frac,
            bpm: bpm,
          ),
        );
      } else if (tag == 'done') {
        final bytes = (message[1] as TransferableTypedData)
            .materialize()
            .asUint8List();
        unawaited(cleanUp());
        try {
          final analysis = decodeBeatAnalysis(bytes);
          completer.complete(analysis);
        } catch (e, st) {
          completer.completeError(e, st);
        }
      } else if (tag == 'error') {
        final errText = message[1] as String;
        unawaited(cleanUp());
        if (errText.contains('AnalysisCancelledException')) {
          completer.completeError(const AnalysisCancelledException());
        } else {
          completer.completeError(StateError(errText));
        }
      }
    }
  });

  try {
    isolate = await Isolate.spawn<_IsolateRequest>(
      _analysisIsolateEntry,
      _IsolateRequest(wavPath: wavPath, sendPort: receivePort.sendPort),
      onError: receivePort.sendPort,
      onExit: exitPort.sendPort,
    );
    if (cancelToken != null && cancelToken.isCancelled) {
      await cleanUp(isCancel: true);
      if (!completer.isCompleted) {
        completer.completeError(const AnalysisCancelledException());
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

class _IsolateRequest {
  const _IsolateRequest({required this.wavPath, required this.sendPort});

  final String wavPath;
  final SendPort sendPort;
}

Future<void> _analysisIsolateEntry(_IsolateRequest req) async {
  var cancelled = false;
  final cancelPort = ReceivePort();
  cancelPort.listen((_) {
    cancelled = true;
    cancelPort.close();
  });
  req.sendPort.send(<Object?>['init', cancelPort.sendPort]);

  try {
    final analysis = await analyzeWavFile(
      req.wavPath,
      isCancelled: () => cancelled,
      onProgress: (p) {
        if (!cancelled) {
          req.sendPort.send(<Object?>[
            'progress',
            p.stage.index,
            p.fraction,
            p.bpm,
          ]);
        }
      },
    );
    final bytes = encodeBeatAnalysis(analysis);
    req.sendPort.send(<Object?>[
      'done',
      TransferableTypedData.fromList(<Uint8List>[bytes]),
    ]);
  } catch (e) {
    req.sendPort.send(<Object?>['error', e.toString()]);
  } finally {
    cancelPort.close();
  }
}
