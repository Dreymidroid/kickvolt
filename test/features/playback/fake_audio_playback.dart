import 'dart:async';

import 'package:kickvolt/features/playback/playback.dart';

/// Records calls and lets tests push player snapshots.
class FakeAudioPlayback implements AudioPlayback {
  final _controller = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final calls = <String>[];
  final openedPaths = <String>[];
  String? openedPath;
  Duration? openedInitialPosition;
  Object? openError;
  bool disposed = false;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  void push({
    Duration position = Duration.zero,
    bool playing = false,
    bool? advancing,
    double speed = 1,
    bool completed = false,
  }) => _controller.add(
    PlaybackSnapshot(
      position: position,
      updateTime: DateTime.now(),
      playing: playing,
      advancing: advancing ?? playing,
      speed: speed,
      completed: completed,
    ),
  );

  @override
  Future<void> open(
    String path, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (openError != null) throw openError!;
    openedPath = path;
    openedInitialPosition = initialPosition;
    openedPaths.add(path);
    calls.add('open $path @${initialPosition.inMicroseconds}');
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inMicroseconds}');

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed $speed');

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}
