import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_playback.dart';

/// [AudioPlayback] on just_audio (AVPlayer on iOS, ExoPlayer on Android),
/// with an audio session configured for music. Pauses on interruptions
/// (calls, Siri) and when headphones are unplugged.
class JustAudioPlayback implements AudioPlayback {
  JustAudioPlayback({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  bool _initialized = false;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> open(
    String path, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (!_initialized) {
      _initialized = true;
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _subs
        ..add(
          session.interruptionEventStream.listen((e) {
            if (e.begin) _player.pause();
          }),
        )
        ..add(session.becomingNoisyEventStream.listen((_) => _player.pause()))
        ..add(
          _player.playbackEventStream.listen((_) => _emit(), onError: (_) {}),
        )
        ..add(_player.playingStream.listen((_) => _emit()))
        ..add(_player.speedStream.listen((_) => _emit()));
    }
    await _player.setFilePath(path, initialPosition: initialPosition);
  }

  void _emit() {
    if (_snapshots.isClosed) return;
    final e = _player.playbackEvent;
    final state = e.processingState;
    _snapshots.add(
      PlaybackSnapshot(
        position: e.updatePosition,
        updateTime: e.updateTime,
        playing: _player.playing,
        advancing: _player.playing && state == ProcessingState.ready,
        speed: _player.speed,
        completed: state == ProcessingState.completed,
      ),
    );
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    if (!await session.setActive(true)) return;
    // just_audio's play() future completes when playback stops; don't wait.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _snapshots.close();
    await _player.dispose();
  }
}
