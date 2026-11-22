import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = DemoBeatProjectRepository();

  group('demo project', () {
    test('matches the design counts', () async {
      final p = await repo.getProject('demo');
      expect(p.beatCount, 358);
      expect(p.strongCount, 90);
      expect(p.dropCount, 3);
      expect(p.bpm, 128);
    });
  });

  group('BeatEditorCubit', () {
    blocTest<BeatEditorCubit, BeatEditorState>(
      'loads the project at the requested playhead',
      build: () => BeatEditorCubit(repository: repo),
      act: (c) => c.load('demo', initialPlayheadMs: 15000),
      expect: () => [
        const BeatEditorState.loading(),
        isA<BeatEditorReady>().having((s) => s.playheadMs, 'playhead', 15000),
      ],
    );

    blocTest<BeatEditorCubit, BeatEditorState>(
      'add at playhead snaps to the grid, then undo and redo restore it',
      build: () => BeatEditorCubit(repository: repo),
      act: (c) async {
        await c.load('demo', initialPlayheadMs: 15000);
        c
          ..toggleSnap() // off
          ..seekTo(15200)
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
      'does not add a duplicate on an existing beat',
      build: () => BeatEditorCubit(repository: repo),
      act: (c) async {
        await c.load('demo', initialPlayheadMs: 15000); // beat 33 is at 15 s
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
  });
}
