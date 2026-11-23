import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/demo_project.dart';
import '../../../fixtures/editor_fakes.dart';
import '../../playback/fake_audio_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleRate = 44100;
  const playhead15s = 15 * sampleRate;

  late FakeDemoProjectRepository repo;
  late FakeAudioPlayback player;
  late FakeClickPreviewRepository previewRepo;

  setUp(() {
    repo = FakeDemoProjectRepository();
    player = FakeAudioPlayback();
    previewRepo = FakeClickPreviewRepository();
  });

  BeatEditorReady ready(BeatEditorCubit c) => c.state as BeatEditorReady;

  group('Click preview flow', () {
    test('Clicks on renders once, swaps player at current position with speed and playing kept; Clicks off swaps back to song.wav', () async {
      final c = BeatEditorCubit(
        repository: repo,
        playback: player,
        clickPreviewRepository: previewRepo,
      );
      await c.load('demo', initialPlayheadSample: playhead15s);
      expect(previewRepo.cleanedUpProjects, ['demo']);

      c.setSpeed(0.75);
      player.push(
        position: const Duration(seconds: 15),
        playing: true,
        advancing: false,
        speed: 0.75,
      );
      player.calls.clear();

      // Turn Clicks ON.
      c.toggleClicks();
      await pumpEventQueue();

      expect(ready(c).clicks, isTrue);
      expect(ready(c).updatingClicks, isFalse);
      expect(previewRepo.requests.length, 1);
      expect(player.openedPath, '/fake/projects/demo/preview-1.wav');
      expect(player.openedInitialPosition, const Duration(seconds: 15));
      expect(player.calls, contains('speed 0.75'));
      expect(player.calls, contains('play'));

      // Turn Clicks OFF -> swaps back to song.wav at current position, deletes old preview.
      player.calls.clear();
      c.toggleClicks();
      await pumpEventQueue();

      expect(ready(c).clicks, isFalse);
      expect(player.openedPath, '/fake/projects/demo/song.wav');
      expect(player.openedInitialPosition, const Duration(seconds: 15));
      expect(previewRepo.deletedFiles, ['/fake/projects/demo/preview-1.wav']);

      await c.close();
    });

    test('edit while Clicks on cancels in-flight render and re-renders once after 300 ms debounce', () {
      fakeAsync((async) {
        previewRepo.autoComplete = false;
        final c = BeatEditorCubit(
          repository: repo,
          playback: player,
          clickPreviewRepository: previewRepo,
          clickPreviewDebounce: const Duration(milliseconds: 300),
        );
        unawaited(c.load('demo', initialPlayheadSample: playhead15s));
        async.flushMicrotasks();

        // Turn Clicks ON -> first render starts and is held in-flight.
        c.toggleClicks();
        async.flushMicrotasks();
        expect(previewRepo.requests.length, 1);
        expect(ready(c).updatingClicks, isTrue);

        // Edit while in-flight -> cancels first render, schedules debounced re-render.
        c
          ..selectBeat(32)
          ..nudgeSelected(10);
        async.flushMicrotasks();
        expect(previewRepo.requests[0].cancel.isCancelled, isTrue);

        // Second rapid edit resets the 300 ms debounce.
        async.elapse(const Duration(milliseconds: 200));
        c.nudgeSelected(10);
        async.elapse(const Duration(milliseconds: 200));
        expect(previewRepo.requests.length, 1);

        // After 300 ms quiet -> second render fires.
        async.elapse(const Duration(milliseconds: 100));
        expect(previewRepo.requests.length, 2);

        // Complete the second render -> player swaps to preview-2.wav.
        previewRepo.requests[1].completer.complete(
          previewRepo.requests[1].outputPath,
        );
        async.flushMicrotasks();
        expect(player.openedPath, '/fake/projects/demo/preview-2.wav');
        expect(ready(c).updatingClicks, isFalse);

        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('filter change while Clicks on schedules debounced re-render', () {
      fakeAsync((async) {
        final c = BeatEditorCubit(
          repository: repo,
          playback: player,
          clickPreviewRepository: previewRepo,
          clickPreviewDebounce: const Duration(milliseconds: 300),
        );
        unawaited(c.load('demo', initialPlayheadSample: playhead15s));
        async.flushMicrotasks();

        c.toggleClicks();
        async.flushMicrotasks();
        expect(previewRepo.requests.length, 1);

        c.setFilter(BeatFilter.strong);
        async.elapse(const Duration(milliseconds: 299));
        expect(previewRepo.requests.length, 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(previewRepo.requests.length, 2);
        // Old preview deleted after swap.
        expect(previewRepo.deletedFiles, ['/fake/projects/demo/preview-1.wav']);

        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test(
      'render failure emits infoMessage (SnackBar) and turns Clicks off',
      () async {
        previewRepo.nextError = Exception('disk full');
        final c = BeatEditorCubit(
          repository: repo,
          playback: player,
          clickPreviewRepository: previewRepo,
        );
        await c.load('demo', initialPlayheadSample: playhead15s);

        c.toggleClicks();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        expect(ready(c).clicks, isFalse);
        expect(ready(c).updatingClicks, isFalse);
        expect(ready(c).infoMessage, isNotNull);
        expect(player.openedPath, '/fake/projects/demo/song.wav');

        await c.close();
      },
    );
  });
}
