import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/playback/playback.dart';

import 'fake_audio_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioPlayback player;
  late PlayheadController c;
  final playingChanges = <bool>[];
  var completed = 0;

  setUp(() {
    player = FakeAudioPlayback();
    playingChanges.clear();
    completed = 0;
    c = PlayheadController(
      playback: player,
      sampleRate: 48000,
      sampleCount: 48000 * 10,
      onPlayingChanged: playingChanges.add,
      onCompleted: () => completed++,
    );
  });

  test('converts between microseconds and samples', () {
    expect(c.samplesFromUs(1000000), 48000);
    expect(c.usFromSamples(24000), 500000);
    expect(c.samplesFromUs(999999999), c.lastFrame);
    expect(c.lastFrame, 48000 * 10 - 1);
  });

  test('seek moves the playhead at once and sends the player there', () async {
    await c.seek(96000);
    expect(c.sample.value, 96000);
    expect(player.calls, ['seek 2000000']);
  });

  test('seek clamps to the last frame', () async {
    await c.seek(1 << 40);
    expect(c.sample.value, c.lastFrame);
  });

  test('scrub moves only the visible playhead', () {
    c.scrub(4800);
    expect(c.sample.value, 4800);
    expect(player.calls, isEmpty);
  });

  test('paused snapshots set the playhead from the player position', () {
    player.push(position: const Duration(seconds: 3));
    expect(c.sample.value, 144000);
  });

  test('reports play/pause changes once each', () {
    player
      ..push(playing: true)
      ..push(playing: true)
      ..push(playing: false);
    expect(playingChanges, [true, false]);
  });

  test('completion parks the playhead on the last frame and pauses', () {
    player
      ..push(playing: true)
      ..push(playing: true, completed: true);
    expect(c.sample.value, c.lastFrame);
    expect(completed, 1);
    expect(playingChanges, [true, false]);
    expect(player.calls, contains('pause'));
  });

  test('play from the end restarts at 0', () async {
    c.scrub(c.lastFrame);
    await c.play();
    expect(player.calls, ['seek 0', 'play']);
  });

  test('dispose releases the player', () async {
    await c.dispose();
    expect(player.disposed, isTrue);
  });
}
