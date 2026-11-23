/// Turns sparse, jittery position reports from the player into a smooth
/// playhead for every display frame.
///
/// Between reports the position is extrapolated from the last anchor at
/// the current speed. A report that disagrees by up to [maxDriftUs] is
/// blended in over [slewUs] instead of jumping, and while playing the
/// output never moves backwards. Bigger disagreements (seeks, stalls) and
/// any pause/speed change re-anchor immediately.
class PlayheadClock {
  PlayheadClock({this.maxDriftUs = 50000, this.slewUs = 250000});

  final int maxDriftUs;
  final int slewUs;

  int _anchorPosUs = 0;
  int _anchorWallUs = 0;
  int _correctionUs = 0;
  int _lastOutUs = 0;
  double _speed = 1;
  bool _advancing = false;

  bool get advancing => _advancing;
  double get speed => _speed;

  /// A position report: the player was at [positionUs] at wall-clock time
  /// [wallUs] (same clock as [positionUsAt]), and is [advancing] (playing
  /// and not buffering) at [speed].
  void report({
    required int positionUs,
    required int wallUs,
    required bool advancing,
    required double speed,
  }) {
    if (advancing && _advancing && speed == _speed) {
      final predicted = _raw(wallUs);
      final error = positionUs - predicted;
      if (error.abs() <= maxDriftUs) {
        _anchorPosUs = predicted;
        _anchorWallUs = wallUs;
        _correctionUs = error;
        return;
      }
    }
    jumpTo(positionUs, wallUs: wallUs, advancing: advancing, speed: speed);
  }

  /// Re-anchors with no smoothing (seek, pause, speed change).
  void jumpTo(
    int positionUs, {
    required int wallUs,
    bool? advancing,
    double? speed,
  }) {
    _anchorPosUs = positionUs;
    _anchorWallUs = wallUs;
    _correctionUs = 0;
    _lastOutUs = positionUs;
    if (advancing != null) _advancing = advancing;
    if (speed != null) _speed = speed;
  }

  /// Playhead position at [wallUs].
  int positionUsAt(int wallUs) {
    final p = _raw(wallUs);
    if (_advancing && p < _lastOutUs) return _lastOutUs;
    _lastOutUs = p;
    return p;
  }

  int _raw(int wallUs) {
    if (!_advancing) return _anchorPosUs;
    final elapsed = wallUs > _anchorWallUs ? wallUs - _anchorWallUs : 0;
    final applied = elapsed >= slewUs
        ? _correctionUs
        : _correctionUs * elapsed ~/ slewUs;
    return _anchorPosUs + (elapsed * _speed).round() + applied;
  }
}
