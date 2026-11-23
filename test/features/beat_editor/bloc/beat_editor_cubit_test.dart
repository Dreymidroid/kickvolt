import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/demo_project.dart';
import '../../playback/fake_audio_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleRate = 44100;
  const playhead15s = 15 * sampleRate; // 661,500 frames

  late FakeDemoProjectRepository repo;

  setUp(() => repo = FakeDemoProjectRepository());

  group('demo project fixture', () {
    test('matches the design counts in sample frames', () async {
      final p = await repo.getProject('demo');
      expect(p.beatCount, 358);
      expect(p.strongCount, 90);
      expect(p.dropCount, 3);
      expect(p.bpm, 128.0);
      expect(p.sampleRate, 44100);
      expect(p.beats[32].sample, playhead15s);
    });
  });

  group('BeatEditorCubit', () {
    test('loads the project at the requested playhead sample', () async {
      final player = FakeAudioPlayback();
      final c = BeatEditorCubit(playback: player, repository: repo);
      await c.load('demo', initialPlayheadSample: playhead15s);
      expect(c.state, isA<BeatEditorReady>());
      expect(c.playheadSample, playhead15s);
      expect(player.openedPath, '/fake/projects/demo/song.wav');
      expect(
        player.calls,
        contains('seek ${playhead15s * 1000000 ~/ sampleRate}'),
      );
      await c.close();
    });

    blocTest<BeatEditorCubit, BeatEditorState>(
      'add at playhead snaps to the grid, then undo and redo restore it',
      build: () =>
          BeatEditorCubit(playback: FakeAudioPlayback(), repository: repo),
      act: (c) async {
        await c.load('demo', initialPlayheadSample: playhead15s);
        c
          ..toggleSnap() // off
          ..seekTo(playhead15s + 8820) // +200 ms
          ..addBeatAtPlayhead()
          ..undo()
          ..redo();
      },
      skip: 3, // loading, ready, snap off (seeking doesn't emit)
      expect: () => [
        isA<BeatEditorReady>()
            .having((s) => s.project.beatCount, 'beats', 359)
            .having((s) => s.canUndo, 'canUndo', isTrue)
            .having((s) => s.canRedo, 'canRedo', isFalse),
        isA<BeatEditorReady>()
            .having((s) => s.project.beatCount, 'beats', 358)
            .having((s) => s.canUndo, 'canUndo', isFalse)
            .having((s) => s.canRedo, 'canRedo', isTrue),
        isA<BeatEditorReady>()
            .having((s) => s.project.beatCount, 'beats', 359)
            .having((s) => s.canUndo, 'canUndo', isTrue)
            .having((s) => s.canRedo, 'canRedo', isFalse),
      ],
    );

    blocTest<BeatEditorCubit, BeatEditorState>(
      'does not add a duplicate within 20 ms of an existing beat',
      build: () =>
          BeatEditorCubit(playback: FakeAudioPlayback(), repository: repo),
      act: (c) async {
        await c.load(
          'demo',
          initialPlayheadSample: playhead15s,
        ); // beat 33 is at 15 s
        c.addBeatAtPlayhead();
      },
      skip: 2,
      expect: () => [],
    );

    test('zoom spans the whole song down to ~20 ms per screen', () async {
      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
      );
      await c.load('demo');
      c.setViewportWidth(390);

      c.setZoom(1e9);
      // 390 px / (0.02 s * 12.8 px/s)
      expect(c.zoom.value, closeTo(1523.4, 0.1));
      final visibleMs = 390 / c.pxPerSample / sampleRate * 1000;
      expect(visibleMs, closeTo(20, 0.01));

      c.setZoom(0);
      // Demo song is 168.75 s: the whole song just fits.
      expect(c.zoom.value, closeTo(390 / (168.75 * 12.8), 1e-6));
      final s = c.state as BeatEditorReady;
      expect(390 / c.pxPerSample, closeTo(s.project.sampleCount, 1));
      await c.close();
    });

    test('seek clamps to the song and never reaches sampleCount', () async {
      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
      );
      await c.load('demo');
      final s = c.state as BeatEditorReady;
      c.seekTo(-5);
      expect(c.playheadSample, 0);
      c.seekTo(1 << 40);
      expect(c.playheadSample, s.project.sampleCount - 1);
      await c.close();
    });

    group('playback', () {
      late FakeAudioPlayback player;
      late BeatEditorCubit c;

      setUp(() async {
        player = FakeAudioPlayback();
        c = BeatEditorCubit(playback: player, repository: repo);
        await c.load('demo');
        player.calls.clear();
      });
      tearDown(() => c.close());

      test('play shows Pause at once and follows the player', () async {
        c.togglePlay();
        expect((c.state as BeatEditorReady).playing, isTrue);
        await Future<void>.microtask(() {});
        expect(player.calls, ['play']);

        player.push(playing: true);
        player.push(position: const Duration(seconds: 2));
        expect((c.state as BeatEditorReady).playing, isFalse);
        expect(c.playheadSample, 2 * sampleRate);
      });

      test('toggling while playing pauses', () async {
        player.push(playing: true);
        c.togglePlay();
        await Future<void>.microtask(() {});
        expect(player.calls, ['pause']);
      });

      test('speed is forwarded to the player', () async {
        c.setSpeed(0.75);
        expect((c.state as BeatEditorReady).speed, 0.75);
        await Future<void>.microtask(() {});
        expect(player.calls, ['speed 0.75']);
      });

      test('scrubbing moves the playhead and seeks only on release', () async {
        player.push(playing: true);
        c.scrubStart();
        c.scrubTo(sampleRate);
        c.scrubTo(3 * sampleRate);
        expect(c.playheadSample, 3 * sampleRate);
        await Future<void>.microtask(() {});
        expect(player.calls, ['pause']);

        await c.scrubEnd();
        expect(player.calls, ['pause', 'seek 3000000', 'play']);
      });

      test('selecting a beat seeks to it', () async {
        c.selectBeat(32);
        await Future<void>.microtask(() {});
        expect(player.calls, ['seek 15000000']);
        expect(c.playheadSample, playhead15s);
      });

      test('close releases the player', () async {
        await c.close();
        expect(player.disposed, isTrue);
      });
    });

    test('if the song cannot be played the editor still works', () async {
      final player = FakeAudioPlayback()..openError = Exception('no codec');
      final c = BeatEditorCubit(playback: player, repository: repo);
      await c.load('demo');
      final s = c.state as BeatEditorReady;
      expect(s.playbackUnavailable, isTrue);

      c.togglePlay();
      expect((c.state as BeatEditorReady).playing, isFalse);
      c.seekTo(sampleRate);
      expect(c.playheadSample, sampleRate);
      expect(player.calls, isEmpty);
      await c.close();
    });

    test('snap uses bpm and beatPhaseSample when adding at playhead', () async {
      // 120 BPM at 48,000 Hz => grid = 24,000 frames; phase offset = 1,000 frames.
      final phased = createDemoProject(
        id: 'phased',
        sampleRate: 48000,
        bpm: 120.0,
        beatPhaseSample: 1000,
        includeBeats: false,
      );
      repo.put(phased);
      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
      );
      await c.load('phased', initialPlayheadSample: 26500);
      c.addBeatAtPlayhead();

      final s = c.state as BeatEditorReady;
      // Nearest grid point to 26,500 is 1,000 + 1 * 24,000 = 25,000.
      expect(s.project.beats.single.sample, 25000);
      await c.close();
    });

    test('with bpm == null addBeatAtPlayhead does not snap', () async {
      final unknownTempo = createDemoProject(
        id: 'nobpm',
        sampleRate: 44100,
        bpm: null,
        includeBeats: false,
      );
      repo.put(unknownTempo);
      final c = BeatEditorCubit(
        playback: FakeAudioPlayback(),
        repository: repo,
      );
      await c.load('nobpm', initialPlayheadSample: 12345);
      c.addBeatAtPlayhead();

      final s = c.state as BeatEditorReady;
      expect(s.project.beats.single.sample, 12345);
      await c.close();
    });

    test('debounces saveProject across rapid edits and flushes pending save on close()', () {
      fakeAsync((async) {
        final c = BeatEditorCubit(
          playback: FakeAudioPlayback(),
          repository: repo,
          saveDebounce: const Duration(milliseconds: 500),
        );
        unawaited(c.load('demo', initialPlayheadSample: playhead15s));
        async.flushMicrotasks();

        c
          ..selectBeat(32)
          ..nudgeSelected(1)
          ..nudgeSelected(1)
          ..nudgeSelected(1);
        // Still within debounce window: no save yet.
        async.elapse(const Duration(milliseconds: 400));
        expect(repo.savedProjects, isEmpty);

        async.elapse(const Duration(milliseconds: 100));
        expect(repo.savedProjects.length, 1);
        expect(
          repo.savedProjects.single.beats[32].sample,
          playhead15s + 44 * 3,
        );

        // Edit again and immediately close before debounce fires -> flushed in close().
        c.nudgeSelected(10);
        expect(repo.savedProjects.length, 1);
        unawaited(c.close());
        async.flushMicrotasks();
        expect(repo.savedProjects.length, 2);
        expect(
          repo.savedProjects.last.beats[32].sample,
          playhead15s + 44 * 3 + 441,
        );
      });
    });

    test('saves never overlap and land in edit order', () {
      fakeAsync((async) {
        final release = Completer<void>();
        var gated = true;
        repo.saveGate = () async {
          if (gated) {
            gated = false;
            await release.future;
          }
        };
        final c = BeatEditorCubit(
          playback: FakeAudioPlayback(),
          repository: repo,
          saveDebounce: const Duration(milliseconds: 200),
        );
        unawaited(c.load('demo', initialPlayheadSample: playhead15s));
        async.flushMicrotasks();

        c
          ..selectBeat(32)
          ..nudgeSelected(1);
        async.elapse(const Duration(milliseconds: 200));
        // First save is now running and held. Edit again and close at once:
        // the flush must wait for it rather than run alongside it.
        c.nudgeSelected(10);
        unawaited(c.close());
        async.flushMicrotasks();
        expect(repo.savedProjects, isEmpty);

        release.complete();
        async.flushMicrotasks();
        expect(repo.maxConcurrentSaves, 1);
        expect(repo.savedProjects.map((p) => p.beats[32].sample), [
          playhead15s + 44,
          playhead15s + 44 + 441,
        ]);
      });
    });

    test('failed save emits saveError without losing the in-memory edit', () {
      fakeAsync((async) {
        repo.saveError = const ProjectCorruptException('disk full');
        final c = BeatEditorCubit(
          playback: FakeAudioPlayback(),
          repository: repo,
          saveDebounce: const Duration(milliseconds: 200),
        );
        unawaited(c.load('demo', initialPlayheadSample: playhead15s));
        async.flushMicrotasks();
        c
          ..selectBeat(32)
          ..nudgeSelected(10);

        async.elapse(const Duration(milliseconds: 200));
        final s = c.state as BeatEditorReady;
        expect(s.project.beats[32].sample, playhead15s + 441);
        expect(s.saveError, 'disk full');
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });
  });
}
