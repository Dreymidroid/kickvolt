/// One state report from the audio player.
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.position,
    required this.updateTime,
    required this.playing,
    required this.advancing,
    required this.speed,
    required this.completed,
  });

  /// Where the player was at [updateTime].
  final Duration position;
  final DateTime updateTime;

  /// The user asked to play (may still be buffering).
  final bool playing;

  /// Audio is actually moving: playing and ready.
  final bool advancing;
  final double speed;

  /// Reached the end of the file.
  final bool completed;
}

/// Plays one local audio file. An interface so the editor can be tested
/// without a platform player.
abstract interface class AudioPlayback {
  /// Loads [path]. Throws if the file can't be played.
  Future<void> open(String path);

  /// Starts playing; returns once the request is sent (not when playback
  /// ends).
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// 0.5–1.0 in the editor; pitch is preserved by the platform player.
  Future<void> setSpeed(double speed);

  Stream<PlaybackSnapshot> get snapshots;

  Future<void> dispose();
}
