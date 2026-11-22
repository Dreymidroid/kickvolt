import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/beat_editor/presentation/widgets/timeline_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = DemoBeatProjectRepository();

  Future<BeatEditorCubit> loaded() async {
    final c = BeatEditorCubit(repository: repo);
    await c.load('demo', initialPlayheadMs: 15000);
    return c;
  }

  BeatEditorReady ready(BeatEditorCubit c) => c.state as BeatEditorReady;

  // Beat 33 (index 32) is the strong beat at exactly 15.000 s.
  const idx = 32;

  group('selection', () {
    test('selecting centres the playhead on the marker', () async {
      final c = await loaded();
      c
        ..seekTo(9000)
        ..selectBeat(idx);
      expect(ready(c).selectedIndex, idx);
      expect(ready(c).playheadMs, 15000);
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
    test('moves the marker and keeps the playhead on it', () async {
      final c = await loaded();
      c
        ..selectBeat(idx)
        ..nudgeSelected(10);
      expect(ready(c).project.beats[idx].timeMs, 15010);
      expect(ready(c).playheadMs, 15010);
      await c.close();
    });

    test('rapid nudges are one undo step', () async {
      final c = await loaded();
      c
        ..selectBeat(idx)
        ..nudgeSelected(10)
        ..nudgeSelected(10)
        ..nudgeSelected(-1);
      expect(ready(c).project.beats[idx].timeMs, 15019);
      expect(ready(c).undoStack.length, 1);
      c.undo();
      expect(ready(c).project.beats[idx].timeMs, 15000);
      await c.close();
    });

    test('cannot cross a neighbouring marker', () async {
      final c = await loaded();
      final next = ready(c).project.beats[idx + 1].timeMs;
      c
        ..selectBeat(idx)
        ..nudgeSelected(100000);
      expect(ready(c).project.beats[idx].timeMs, next - 1);
      await c.close();
    });

    test('off the grid after a nudge, on the grid when snapped', () async {
      final c = await loaded();
      final p = ready(c).project;
      expect(p.isOnGrid(p.beats[idx].timeMs), isTrue);
      c
        ..selectBeat(idx)
        ..nudgeSelected(10);
      final q = ready(c).project;
      expect(q.isOnGrid(q.beats[idx].timeMs), isFalse);
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

  group('hit test', () {
    test('finds the marker under a tap and ignores empty space', () async {
      final p = await repo.getProject('demo');
      int? hit(double dx, {double dy = 300}) => TimelinePainter.beatAt(
        project: p,
        playheadMs: 15000,
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
