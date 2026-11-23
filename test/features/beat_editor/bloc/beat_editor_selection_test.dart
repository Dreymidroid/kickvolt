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

  Future<BeatEditorCubit> loaded({
    String id = 'demo',
    int initialPlayheadSample = playhead15s,
  }) async {
    final c = BeatEditorCubit(playback: FakeAudioPlayback(), repository: repo);
    await c.load(id, initialPlayheadSample: initialPlayheadSample);
    return c;
  }

  BeatEditorReady ready(BeatEditorCubit c) => c.state as BeatEditorReady;

  // Beat 33 (index 32) is the strong beat at exactly 15.000 s (661,500 samples).
  const idx = 32;

  group('selection', () {
    test('selecting centres the playhead on the marker sample', () async {
      final c = await loaded();
      c
        ..seekTo(9 * sampleRate)
        ..selectBeat(idx);
      expect(ready(c).selectedIndex, idx);
      expect(c.playheadSample, playhead15s);
      await c.close();
    });

    test('null or out-of-range clears it', () async {
      final c = await loaded();
      c.selectBeat(idx);
      c.selectBeat(9999);
      expect(ready(c).selectedIndex, isNull);
      await c.close();
    });

    test('leaving the Edit tab clears the selection', () async {
      final c = await loaded();
      c
        ..selectBeat(idx)
        ..selectTool(EditorTool.tap);
      expect(ready(c).selectedIndex, isNull);
      await c.close();
    });
  });

  group('nudge', () {
    test(
      'moves the marker in sample frames and keeps the playhead on it',
      () async {
        final c = await loaded();
        c
          ..selectBeat(idx)
          ..nudgeSelected(10); // +10 ms at 44.1 kHz = +441 frames
        expect(ready(c).project.beats[idx].sample, playhead15s + 441);
        expect(c.playheadSample, playhead15s + 441);
        await c.close();
      },
    );

    test(
      'nudge ±1 ms moves 44 frames at 44.1 kHz and 48 frames at 48 kHz',
      () async {
        final c44 = await loaded();
        c44
          ..selectBeat(idx)
          ..nudgeSelected(1);
        expect(ready(c44).project.beats[idx].sample, playhead15s + 44);
        c44.nudgeSelected(-1);
        expect(ready(c44).project.beats[idx].sample, playhead15s);
        await c44.close();

        final p48 = createDemoProject(id: 'demo48', sampleRate: 48000);
        repo.put(p48);
        final c48 = await loaded(
          id: 'demo48',
          initialPlayheadSample: 15 * 48000,
        );
        c48
          ..selectBeat(idx)
          ..nudgeSelected(1);
        expect(ready(c48).project.beats[idx].sample, 15 * 48000 + 48);
        c48.nudgeSelected(-1);
        expect(ready(c48).project.beats[idx].sample, 15 * 48000);
        await c48.close();
      },
    );

    test('rapid nudges are one undo step', () async {
      final c = await loaded();
      c
        ..selectBeat(idx)
        ..nudgeSelected(10)
        ..nudgeSelected(10)
        ..nudgeSelected(-1);
      expect(ready(c).project.beats[idx].sample, playhead15s + 441 + 441 - 44);
      expect(ready(c).canUndo, isTrue);
      c.undo();
      expect(ready(c).project.beats[idx].sample, playhead15s);
      expect(ready(c).canUndo, isFalse);
      expect(ready(c).selectedIndex, idx);
      await c.close();
    });

    test('cannot cross a neighbouring marker', () async {
      final c = await loaded();
      final nextSample = ready(c).project.beats[idx + 1].sample;
      c
        ..selectBeat(idx)
        ..nudgeSelected(100000);
      expect(ready(c).project.beats[idx].sample, nextSample - 1);
      await c.close();
    });

    test('off the grid after a nudge, on the grid when snapped', () async {
      final c = await loaded();
      final p = ready(c).project;
      expect(p.isOnGrid(p.beats[idx].sample), isTrue);
      c
        ..selectBeat(idx)
        ..nudgeSelected(10);
      final q = ready(c).project;
      expect(q.isOnGrid(q.beats[idx].sample), isFalse);
      await c.close();
    });
  });

  group('type and delete', () {
    test('changes the type and is undoable', () async {
      final c = await loaded();
      c
        ..selectBeat(idx)
        ..setSelectedType(BeatType.drop);
      expect(ready(c).project.beats[idx].type, BeatType.drop);
      expect(ready(c).project.dropCount, 4);
      c.undo();
      expect(ready(c).project.beats[idx].type, BeatType.strong);
      await c.close();
    });

    test('delete removes the marker and clears the selection', () async {
      final c = await loaded();
      c
        ..selectBeat(idx)
        ..deleteSelected();
      expect(ready(c).project.beatCount, 357);
      expect(ready(c).selectedIndex, isNull);
      c.undo();
      expect(ready(c).project.beatCount, 358);
      await c.close();
    });
  });

  group('0-beat project safety', () {
    test(
      'select, nudge, setType, delete, undo, redo are no-ops and do not throw',
      () async {
        repo.put(
          createDemoProject(id: 'empty', bpm: null, includeBeats: false),
        );
        final c = await loaded(id: 'empty', initialPlayheadSample: 0);
        expect(() {
          c
            ..selectBeat(0)
            ..nudgeSelected(10)
            ..setSelectedType(BeatType.strong)
            ..deleteSelected()
            ..undo()
            ..redo()
            ..toggleSnap();
        }, returnsNormally);
        expect(ready(c).project.beats, isEmpty);
        expect(ready(c).selectedIndex, isNull);
        await c.close();
      },
    );
  });

  group('hit test', () {
    test('finds the marker under a tap and ignores empty space', () async {
      final p = await repo.getProject('demo');
      int? hit(double dx, {double dy = 300}) => TimelinePainter.beatAt(
        project: p,
        playheadSample: playhead15s,
        zoom: 4,
        dx: dx,
        dy: dy,
        width: 390,
      );
      expect(hit(195), idx); // playhead is exactly on beat 33
      expect(hit(195 + 24), idx + 1); // next beat is 24 px right
      expect(hit(195 + 12), isNull); // halfway between two beats
      expect(hit(195 + 9), idx); // just inside the slop
      expect(hit(195, dy: 20), isNull); // ruler area
    });
  });
}
