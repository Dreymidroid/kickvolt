import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/pcm_window_loader.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';

void main() {
  late Directory dir;
  late String path;
  const frames = 20000;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pcm_window_test');
    path = '${dir.path}/song.wav';
    // Use left = f % 1000, right = f % 1000 + 2 → mono = f % 1000 + 1.
    final pcm = Int16List(frames * 2);
    for (var f = 0; f < frames; f++) {
      pcm[2 * f] = f % 1000;
      pcm[2 * f + 1] = f % 1000 + 2;
    }
    File(path).writeAsBytesSync([
      ...buildWavHeader(sampleRate: 44100, channels: 2, frameCount: frames),
      ...pcm.buffer.asUint8List(),
    ]);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> nextNotify(PcmWindowLoader l) {
    final c = Completer<void>();
    void cb() {
      l.removeListener(cb);
      c.complete();
    }

    l.addListener(cb);
    return c.future.timeout(const Duration(seconds: 5));
  }

  test('loads a padded mono window covering the request', () async {
    final loader = await PcmWindowLoader.open(path);
    addTearDown(loader.dispose);
    final notified = nextNotify(loader);
    loader.ensure(5000, 5500);
    await notified;

    final w = loader.window!;
    expect(w.covers(5000, 5500), isTrue);
    expect(w.startFrame, 4500); // padded by the span on each side
    expect(w.endFrame, 6000);
    for (var f = w.startFrame; f < w.endFrame; f++) {
      expect(w.mono[f - w.startFrame], f % 1000 + 1);
    }
  });

  test('a request inside the current window does not reload', () async {
    final loader = await PcmWindowLoader.open(path);
    addTearDown(loader.dispose);
    final first = nextNotify(loader);
    loader.ensure(5000, 5500);
    await first;
    var notifications = 0;
    loader.addListener(() => notifications++);
    loader.ensure(5100, 5400);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(notifications, 0);
  });

  test('clamps to the song bounds', () async {
    final loader = await PcmWindowLoader.open(path);
    addTearDown(loader.dispose);
    final notified = nextNotify(loader);
    loader.ensure(frames - 100, frames + 500);
    await notified;
    expect(loader.window!.endFrame, frames);
    expect(loader.window!.covers(frames - 100, frames), isTrue);
  });
}
