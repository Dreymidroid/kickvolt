import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/audio_math/click_synth.dart';
import '../../../core/audio_math/wav_header.dart';
import '../../../core/di/locator.dart';
import '../../../core/haptics/haptics.dart';
import '../../playback/playback.dart';
import '../data/output_route_service.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/entities/app_settings.dart';
import '../domain/latency_calibration.dart';

part 'latency_calibration_cubit.freezed.dart';
part 'latency_calibration_state.dart';

class LatencyCalibrationCubit extends Cubit<LatencyCalibrationState> {
  LatencyCalibrationCubit({
    SettingsRepository? settingsRepository,
    OutputRouteService? outputRouteService,
    Haptics? haptics,
    this._playback,
    Future<Directory> Function()? tempDirProvider,
    this._nowUs,
  }) : _settings = settingsRepository ?? locator<SettingsRepository>(),
       _outputRoute = outputRouteService ?? locator<OutputRouteService>(),
       _haptics = haptics ?? locator<Haptics>(),
       _tempDirProvider = tempDirProvider ?? getTemporaryDirectory,
       super(const LatencyCalibrationState.loading());

  final SettingsRepository _settings;
  final OutputRouteService _outputRoute;
  final Haptics _haptics;
  AudioPlayback? _playback;
  final Future<Directory> Function() _tempDirProvider;
  final int Function()? _nowUs;

  PlayheadController? _playhead;
  StreamSubscription<OutputKind>? _routeSub;
  late final List<int> _clickSamples = calibrationClickSamples(
    sampleRate: kCalibrationSampleRate,
    bpm: kCalibrationBpm,
    durationSeconds: kCalibrationDurationSeconds,
  );
  final List<int> _tapSamples = [];
  String? _wavPath;
  bool _closing = false;

  LatencyCalibrationReady? get _ready => switch (state) {
    final LatencyCalibrationReady s => s,
    _ => null,
  };

  Future<void> init() async {
    emit(const LatencyCalibrationState.loading());
    try {
      final settings = await _settings.load();
      final kind = await _outputRoute.currentOutputKind();
      final reported = await _outputRoute.reportedOutputLatency();
      if (isClosed) return;

      final dir = await _tempDirProvider();
      final wavPath = p.join(
        dir.path,
        'kickvolt_calibration_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await _writeCalibrationWav(wavPath, _clickSamples);
      _wavPath = wavPath;
      if (isClosed) {
        await _deleteTempWav();
        return;
      }

      final playback = _playback ??= locator<AudioPlayback>();
      const sampleCount = kCalibrationSampleRate * kCalibrationDurationSeconds;
      final playhead = PlayheadController(
        playback: playback,
        sampleRate: kCalibrationSampleRate,
        sampleCount: sampleCount,
        nowUs: _nowUs,
        onPlayingChanged: _onPlayingChanged,
        onCompleted: () {
          // Loop from start if the user hasn't finished 16 taps in 30 s.
          if (!isClosed && _ready?.status == CalibrationStatus.needMoreTaps) {
            unawaited(_playhead?.seek(0));
            unawaited(_playhead?.play());
          }
        },
      );
      _playhead = playhead;

      var unavailable = false;
      try {
        await playhead.open(wavPath);
      } catch (_) {
        unavailable = true;
      }
      if (isClosed) return;

      _routeSub = _outputRoute.outputKindStream.listen((nextKind) {
        final cur = _ready;
        if (!isClosed && cur != null && cur.outputKind != nextKind) {
          emit(cur.copyWith(outputKind: nextKind));
        }
      });

      emit(
        LatencyCalibrationState.ready(
          playbackUnavailable: unavailable,
          outputKind: kind,
          calibratedOn: settings.latencyCalibratedOn,
          reportedOutputLatencyMs: reported?.inMilliseconds,
        ),
      );
    } catch (e) {
      if (!isClosed) {
        emit(LatencyCalibrationState.error(error: e.toString()));
      }
    }
  }

  void _onPlayingChanged(bool playing) {
    final cur = _ready;
    if (!isClosed && cur != null && cur.playing != playing) {
      emit(cur.copyWith(playing: playing));
    }
  }

  void togglePlay() {
    final cur = _ready;
    final p = _playhead;
    if (cur == null || p == null || cur.playbackUnavailable) return;
    if (cur.playing) {
      unawaited(p.pause());
    } else {
      emit(cur.copyWith(playing: true));
      unawaited(p.play());
    }
  }

  /// Called on pointer-down (`Listener.onPointerDown`) so the latency path
  /// matches the Tap tab identically (§7.3, §7.6).
  void recordTap() {
    final cur = _ready;
    final p = _playhead;
    if (cur == null || p == null || !cur.playing) return;
    if (cur.status != CalibrationStatus.needMoreTaps) return;

    final sample = p.sampleNow();
    _tapSamples.add(sample);
    unawaited(_haptics.selectionClick());

    final eval = evaluateCalibrationTaps(
      clickSamples: _clickSamples,
      tapSamples: _tapSamples,
      sampleRate: kCalibrationSampleRate,
      bpm: kCalibrationBpm,
    );

    emit(
      cur.copyWith(
        validTapCount: eval.validTapCount,
        status: eval.status,
        measuredOffsetMs: eval.offsetMs,
      ),
    );

    if (eval.status != CalibrationStatus.needMoreTaps) {
      unawaited(p.pause());
    }
  }

  void tryAgain() {
    final cur = _ready;
    if (cur == null) return;
    _tapSamples.clear();
    unawaited(_playhead?.pause());
    unawaited(_playhead?.seek(0));
    emit(
      cur.copyWith(
        playing: false,
        validTapCount: 0,
        status: CalibrationStatus.needMoreTaps,
        measuredOffsetMs: null,
        saved: false,
      ),
    );
  }

  Future<bool> save() async {
    final cur = _ready;
    final offset = cur?.measuredOffsetMs;
    if (cur == null || offset == null) return false;
    final updated = _settings.current.copyWith(
      latencyOffsetMs: offset,
      latencyCalibratedOn: cur.outputKind,
    );
    await _settings.save(updated);
    if (!isClosed) {
      emit(cur.copyWith(calibratedOn: cur.outputKind, saved: true));
    }
    unawaited(_haptics.successNotification());
    return true;
  }

  Future<void> _writeCalibrationWav(String path, List<int> clicks) async {
    const sampleRate = kCalibrationSampleRate;
    const frameCount = sampleRate * kCalibrationDurationSeconds;
    const channels = 1;
    final click = renderClick(ClickStyle.snap, sampleRate);

    final file = File(path);
    await file.parent.create(recursive: true);
    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.writeFrom(
        buildWavHeader(
          sampleRate: sampleRate,
          channels: channels,
          frameCount: frameCount,
        ),
      );
      const chunkFrames = 32768;
      final mono = Float64List(chunkFrames);
      final pcm = Int16List(chunkFrames);
      final bytes = Uint8List.view(pcm.buffer);
      var offset = 0;
      while (offset < frameCount) {
        final count = math.min(chunkFrames, frameCount - offset);
        mono.fillRange(0, count, 0.0);
        addClicksToChunk(
          monoOut: mono,
          chunkStart: offset,
          chunkLength: count,
          beatSamples: clicks,
          click: click,
          totalSampleCount: frameCount,
        );
        for (var i = 0; i < count; i++) {
          pcm[i] = clipInt16(mono[i] * 32767.0);
        }
        await raf.writeFrom(bytes, 0, count * 2);
        offset += count;
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
  }

  Future<void> _deleteTempWav() async {
    final path = _wavPath;
    _wavPath = null;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    await _routeSub?.cancel();
    final p = _playhead;
    if (p != null) {
      await p.dispose();
    } else {
      await _playback?.dispose();
    }
    await _deleteTempWav();
    return super.close();
  }
}
