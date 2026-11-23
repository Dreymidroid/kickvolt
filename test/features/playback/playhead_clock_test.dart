import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/playback/playback.dart';

const ms = 1000;

void main() {
  late PlayheadClock clock;

  setUp(() => clock = PlayheadClock(maxDriftUs: 50 * ms, slewUs: 250 * ms));

  void play(int posUs, int wallUs, {double speed = 1}) => clock.report(
    positionUs: posUs,
    wallUs: wallUs,
    advancing: true,
    speed: speed,
  );

  test('extrapolates between reports at the current speed', () {
    play(1000 * ms, 0);
    expect(clock.positionUsAt(100 * ms), 1100 * ms);
    expect(clock.positionUsAt(500 * ms), 1500 * ms);

    clock = PlayheadClock();
    play(0, 0, speed: 0.5);
    expect(clock.positionUsAt(1000 * ms), 500 * ms);
  });

  test('small drift is blended in over the slew window, never backwards', () {
    play(0, 0);
    expect(clock.positionUsAt(100 * ms), 100 * ms);
    // Player says it is 30 ms behind our estimate.
    play(70 * ms, 100 * ms);
    final outputs = [
      for (var t = 100; t <= 500; t += 16) clock.positionUsAt(t * ms),
    ];
    for (var i = 1; i < outputs.length; i++) {
      expect(outputs[i], greaterThanOrEqualTo(outputs[i - 1]));
    }
    // After the slew window the correction is fully applied.
    expect(clock.positionUsAt(600 * ms), 70 * ms + 500 * ms);
  });

  test('a small forward correction speeds up instead of jumping', () {
    play(0, 0);
    clock.positionUsAt(100 * ms);
    play(140 * ms, 100 * ms); // 40 ms ahead
    expect(clock.positionUsAt(116 * ms), lessThan(140 * ms + 16 * ms));
    expect(clock.positionUsAt(350 * ms), 140 * ms + 250 * ms);
  });

  test('large disagreement (seek or stall) jumps immediately', () {
    play(0, 0);
    clock.positionUsAt(100 * ms);
    play(5000 * ms, 100 * ms);
    expect(clock.positionUsAt(100 * ms), 5000 * ms);

    // Backward seek while playing is allowed too.
    play(1000 * ms, 200 * ms);
    expect(clock.positionUsAt(200 * ms), 1000 * ms);
  });

  test('pausing freezes the position', () {
    play(0, 0);
    clock.report(
      positionUs: 300 * ms,
      wallUs: 300 * ms,
      advancing: false,
      speed: 1,
    );
    expect(clock.positionUsAt(300 * ms), 300 * ms);
    expect(clock.positionUsAt(9000 * ms), 300 * ms);
    expect(clock.advancing, isFalse);
  });

  test('a speed change re-anchors without smoothing', () {
    play(0, 0);
    play(1000 * ms, 1000 * ms, speed: 0.75);
    expect(clock.speed, 0.75);
    expect(clock.positionUsAt(2000 * ms), 1750 * ms);
  });

  test('jumpTo moves the playhead even while playing', () {
    play(10000 * ms, 0);
    clock.positionUsAt(100 * ms);
    clock.jumpTo(2000 * ms, wallUs: 100 * ms);
    expect(clock.positionUsAt(100 * ms), 2000 * ms);
    expect(clock.positionUsAt(200 * ms), 2100 * ms);
  });
}
