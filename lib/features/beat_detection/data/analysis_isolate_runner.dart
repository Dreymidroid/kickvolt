import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../projects/domain/entities/detection_settings.dart';
import '../domain/beat_analyzer.dart';
import '../domain/entities/beat_analysis.dart';
import 'analysis_cache_codec.dart';

/// Token to cancel a running beat analysis or re-track isolate job.
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
/// on Windows), waiting for `workerReady` if cancel arrives while the isolate
/// is still spawning, then kills the isolate with `Isolate.immediate` as a
/// hard fallback after a 2-second grace period.
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
  final exited = Completer<void>();
  final workerReady = Completer<SendPort>();
  final spawned = Completer<Isolate?>();
  final completer = Completer<BeatAnalysis>()..future.ignore();
  Future<void>? shutdown;
  var lastFraction = 0.0;

  exitPort.listen((_) {
    if (!exited.isCompleted) exited.complete();
  });

  void closePorts() {
    receivePort.close();
    exitPort.close();
  }

  Future<void> stopWorker({required bool cancel}) {
    return shutdown ??= () async {
      cancelToken?._onCancel = null;
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
  cancelToken?._onCancel = () async {
    cancelling = true;
    await stopWorker(cancel: true);
    if (!completer.isCompleted) {
      completer.completeError(const AnalysisCancelledException());
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
    if (completer.isCompleted || cancelling) return;
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
      try {
        final analysis = decodeBeatAnalysis(bytes);
        completer.complete(analysis);
      } catch (e, st) {
        completer.completeError(e, st);
      }
      unawaited(stopWorker(cancel: false));
    } else if (tag == 'error') {
      final errText = message[1] as String;
      if (errText.contains('AnalysisCancelledException')) {
        completer.completeError(const AnalysisCancelledException());
      } else {
        completer.completeError(StateError(errText));
      }
      unawaited(stopWorker(cancel: false));
    } else {
      completer.completeError(StateError(message.join(' ')));
      unawaited(stopWorker(cancel: true));
    }
  });

  try {
    final iso = await Isolate.spawn<_IsolateRequest>(
      _analysisIsolateEntry,
      _IsolateRequest(wavPath: wavPath, sendPort: receivePort.sendPort),
      onError: receivePort.sendPort,
      onExit: exitPort.sendPort,
    );
    spawned.complete(iso);
  } catch (e, st) {
    spawned.complete(null);
    cancelToken?._onCancel = null;
    closePorts();
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

/// Runs [retrack] in a dedicated background isolate (`Isolate.spawn`) with
/// cooperative cancel + `Isolate.kill` (§4.2).
///
/// Only the small `song.wav` PCM windows around tracked beats are read inside
/// the isolate, and the file handle is closed in `finally` before exit.
Future<BeatAnalysis> runRetrackInIsolate(
  String wavPath,
  BeatAnalysis analysis,
  TrackingOptions options, {
  AnalysisCancelToken? cancelToken,
}) async {
  if (cancelToken != null && cancelToken.isCancelled) {
    throw const AnalysisCancelledException();
  }

  final receivePort = ReceivePort();
  final exitPort = ReceivePort();
  final exited = Completer<void>();
  final workerReady = Completer<SendPort>();
  final spawned = Completer<Isolate?>();
  final completer = Completer<BeatAnalysis>()..future.ignore();
  Future<void>? shutdown;

  exitPort.listen((_) {
    if (!exited.isCompleted) exited.complete();
  });

  void closePorts() {
    receivePort.close();
    exitPort.close();
  }

  Future<void> stopWorker({required bool cancel}) {
    return shutdown ??= () async {
      cancelToken?._onCancel = null;
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
  cancelToken?._onCancel = () async {
    cancelling = true;
    await stopWorker(cancel: true);
    if (!completer.isCompleted) {
      completer.completeError(const AnalysisCancelledException());
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
    if (completer.isCompleted || cancelling) return;
    if (tag == 'done') {
      final bytes = (message[1] as TransferableTypedData)
          .materialize()
          .asUint8List();
      try {
        final updated = decodeBeatAnalysis(bytes);
        completer.complete(updated);
      } catch (e, st) {
        completer.completeError(e, st);
      }
      unawaited(stopWorker(cancel: false));
    } else if (tag == 'error') {
      final errText = message[1] as String;
      if (errText.contains('AnalysisCancelledException')) {
        completer.completeError(const AnalysisCancelledException());
      } else {
        completer.completeError(StateError(errText));
      }
      unawaited(stopWorker(cancel: false));
    } else {
      completer.completeError(StateError(message.join(' ')));
      unawaited(stopWorker(cancel: true));
    }
  });

  try {
    final encodedAnalysis = encodeBeatAnalysis(analysis);
    final iso = await Isolate.spawn<_RetrackIsolateRequest>(
      _retrackIsolateEntry,
      _RetrackIsolateRequest(
        wavPath: wavPath,
        analysisBytes: TransferableTypedData.fromList(<Uint8List>[
          encodedAnalysis,
        ]),
        targetBpm: options.targetBpm,
        tempoModeIndex: options.tempoMode.index,
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
    if (!completer.isCompleted) {
      completer.completeError(e, st);
    }
  }

  return completer.future;
}

class _RetrackIsolateRequest {
  const _RetrackIsolateRequest({
    required this.wavPath,
    required this.analysisBytes,
    required this.targetBpm,
    required this.tempoModeIndex,
    required this.sendPort,
  });

  final String wavPath;
  final TransferableTypedData analysisBytes;
  final double? targetBpm;
  final int tempoModeIndex;
  final SendPort sendPort;
}

Future<void> _retrackIsolateEntry(_RetrackIsolateRequest req) async {
  var cancelled = false;
  final cancelPort = ReceivePort();
  cancelPort.listen((_) {
    cancelled = true;
    cancelPort.close();
  });
  req.sendPort.send(<Object?>['init', cancelPort.sendPort]);

  try {
    final baseAnalysis = decodeBeatAnalysis(
      req.analysisBytes.materialize().asUint8List(),
    );
    final options = TrackingOptions(
      targetBpm: req.targetBpm,
      tempoMode: TempoMode.values[req.tempoModeIndex],
    );
    final updated = await retrack(
      baseAnalysis,
      options,
      wavPath: req.wavPath,
      isCancelled: () => cancelled,
    );
    final bytes = encodeBeatAnalysis(updated);
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
