import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/demo_project.dart';

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
    blocTest<BeatEditorCubit, BeatEditorState>(
      'loads the project at the requested playhead sample',
      build: () => BeatEditorCubit(repository: repo),
      act: (c) => c.load('demo', initialPlayheadSample: playhead15s),
      expect: () => [
        const BeatEditorState.loading(),
        isA<BeatEditorReady>().having(
          (s) => s.playheadSample,
          'playheadSample',
          playhead15s,
        ),
      ],
    );

    blocTest<BeatEditorCubit, BeatEditorState>(
      'add at playhead snaps to the grid, then undo and redo restore it',
      build: () => BeatEditorCubit(repository: repo),
      act: (c) async {
        await c.load('demo', initialPlayheadSample: playhead15s);
        c
          ..toggleSnap() // off
          ..seekTo(playhead15s + 8820) // +200 ms
          ..addBeatAtPlayhead()
          ..undo()
          ..redo();
      },
      skip: 4, // loading, ready, snap off, seek
      expect: () => [
        isA<BeatEditorReady>()
            .having((s) => s.project.beatCount, 'beats', 359)
            .having((s) => s.undoStack.length, 'undo', 1),
        isA<BeatEditorReady>()
            .having((s) => s.project.beatCount, 'beats', 358)
            .having((s) => s.redoStack.length, 'redo', 1),
        isA<BeatEditorReady>().having((s) => s.project.beatCount, 'beats', 359),
      ],
    );

    blocTest<BeatEditorCubit, BeatEditorState>(
      'does not add a duplicate within 20 ms of an existing beat',
      build: () => BeatEditorCubit(repository: repo),
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

    blocTest<BeatEditorCubit, BeatEditorState>(
      'clamps zoom and seek',
      build: () => BeatEditorCubit(repository: repo),
      act: (c) async {
        await c.load('demo');
        c
          ..setZoom(100)
          ..seekTo(-5);
      },
      skip: 2,
      expect: () => [
        isA<BeatEditorReady>().having((s) => s.zoom, 'zoom', 16),
        // seekTo(-5) clamps to 0, which equals the current state: no emit.
      ],
    );

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
      final c = BeatEditorCubit(repository: repo);
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
      final c = BeatEditorCubit(repository: repo);
      await c.load('nobpm', initialPlayheadSample: 12345);
      c.addBeatAtPlayhead();

      final s = c.state as BeatEditorReady;
      expect(s.project.beats.single.sample, 12345);
      await c.close();
    });

    test('debounces saveProject across rapid edits and flushes pending save on close()', () async {
      final c = BeatEditorCubit(
        repository: repo,
        saveDebounce: const Duration(milliseconds: 40),
      );
      await c.load('demo', initialPlayheadSample: playhead15s);

      c
        ..selectBeat(32)
        ..nudgeSelected(1)
        ..nudgeSelected(1)
        ..nudgeSelected(1);
      // Still within debounce window: no save yet.
      expect(repo.savedProjects, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.savedProjects.length, 1);
      expect(repo.savedProjects.single.beats[32].sample, playhead15s + 44 * 3);

      // Edit again and immediately close before debounce fires -> flushed in close().
      c.nudgeSelected(10);
      expect(repo.savedProjects.length, 1);
      await c.close();
      expect(repo.savedProjects.length, 2);
      expect(
        repo.savedProjects.last.beats[32].sample,
        playhead15s + 44 * 3 + 441,
      );
    });

    test(
      'failed save emits saveError without losing the in-memory edit',
      () async {
        repo.saveError = const ProjectCorruptException('disk full');
        final c = BeatEditorCubit(
          repository: repo,
          saveDebounce: const Duration(milliseconds: 20),
        );
        await c.load('demo', initialPlayheadSample: playhead15s);
        c
          ..selectBeat(32)
          ..nudgeSelected(10);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        final s = c.state as BeatEditorReady;
        expect(s.project.beats[32].sample, playhead15s + 441);
        expect(s.saveError, 'disk full');
        await c.close();
      },
    );
  });
}
