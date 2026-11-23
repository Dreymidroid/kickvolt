import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../data/audio_playback.dart';
import '../domain/playhead_clock.dart';

/// Owns playback for one song and publishes the playhead as a sample index
/// on [sample], updated once per display frame while audio is moving. The
/// widget tree listens to [sample] directly (via `CustomPainter.repaint`),
/// so playing never rebuilds widgets — only the painters repaint.
class PlayheadController {
  PlayheadController({
    required this._playback,
    required this.sampleRate,
    required this.sampleCount,
    int Function()? nowUs,
    this.onPlayingChanged,
    this.onCompleted,
  }) : _nowUs = nowUs ?? _monotonicUs {
    _sub = _playback.snapshots.listen(_onSnapshot);
  }

  final AudioPlayback _playback;
  final int sampleRate;
  final int sampleCount;
  final int Function() _nowUs;
  final void Function(bool playing)? onPlayingChanged;
  final VoidCallback? onCompleted;

  final ValueNotifier<int> sample = ValueNotifier(0);
  final _clock = PlayheadClock();
  late final StreamSubscription<PlaybackSnapshot> _sub;

  bool _ticking = false;
  int _tickGen = 0;
  bool _playing = false;
  int _pendingSeeks = 0;
  bool _disposed = false;

  static final _stopwatch = Stopwatch()..start();
  static int _monotonicUs() => _stopwatch.elapsedMicroseconds;

  bool get playing => _playing;

  int get lastFrame => sampleCount > 0 ? sampleCount - 1 : 0;

  int samplesFromUs(int us) =>
      (us * sampleRate / 1e6).round().clamp(0, lastFrame);

  int usFromSamples(int s) => (s * 1e6 / sampleRate).round();

  Future<void> open(String path) => _playback.open(path);

  Future<void> play() async {
    if (sample.value >= lastFrame) await seek(0);
    await _playback.play();
  }

  Future<void> pause() => _playback.pause();

  Future<void> setSpeed(double speed) => _playback.setSpeed(speed);

  /// Moves the playhead now and the audio as soon as the player allows.
  Future<void> seek(int frame) async {
    final f = frame.clamp(0, lastFrame);
    sample.value = f;
    _clock.jumpTo(usFromSamples(f), wallUs: _nowUs());
    _pendingSeeks++;
    try {
      await _playback.seek(Duration(microseconds: usFromSamples(f)));
    } finally {
      _pendingSeeks--;
    }
  }

  /// Moves only the visible playhead (finger drag); call [seek] on release.
  void scrub(int frame) {
    sample.value = frame.clamp(0, lastFrame);
  }

  void _onSnapshot(PlaybackSnapshot s) {
    if (_disposed) return;
    if (s.playing != _playing) {
      _playing = s.playing;
      onPlayingChanged?.call(_playing);
    }
    if (s.completed) {
      _stopTicking();
      _clock.jumpTo(
        usFromSamples(lastFrame),
        wallUs: _nowUs(),
        advancing: false,
      );
      sample.value = lastFrame;
      if (_playing) {
        _playing = false;
        onPlayingChanged?.call(false);
      }
      unawaited(_playback.pause());
      onCompleted?.call();
      return;
    }
    // While a seek is in flight the player may still report the old spot.
    if (_pendingSeeks > 0 && !s.advancing) return;

    final wall =
        _nowUs() - DateTime.now().difference(s.updateTime).inMicroseconds;
    _clock.report(
      positionUs: s.position.inMicroseconds,
      wallUs: wall,
      advancing: s.advancing,
      speed: s.speed,
    );
    if (s.advancing) {
      _startTicking();
    } else {
      _stopTicking();
      sample.value = samplesFromUs(_clock.positionUsAt(_nowUs()));
    }
  }

  void _startTicking() {
    if (_ticking) return;
    _ticking = true;
    final gen = ++_tickGen;
    void onFrame(Duration _) {
      // A stop/start within one frame starts a new chain; end this one.
      if (!_ticking || _disposed || gen != _tickGen) return;
      sample.value = samplesFromUs(_clock.positionUsAt(_nowUs()));
      SchedulerBinding.instance.scheduleFrameCallback(onFrame);
    }

    SchedulerBinding.instance.scheduleFrameCallback(onFrame);
  }

  void _stopTicking() => _ticking = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopTicking();
    await _sub.cancel();
    sample.dispose();
    await _playback.dispose();
  }
}
