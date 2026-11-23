import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/domain/command_stack.dart';
import 'package:kickvolt/features/beat_editor/domain/edit_command.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/demo_project.dart';

void _assertBeatInvariants(Project p) {
  final last = math.max(0, p.sampleCount - 1);
  for (var i = 0; i < p.beats.length; i++) {
    final s = p.beats[i].sample;
    expect(s, greaterThanOrEqualTo(0), reason: 'beat $i below 0');
    expect(s, lessThanOrEqualTo(last), reason: 'beat $i above sampleCount - 1');
    if (i > 0) {
      expect(
        s,
        greaterThan(p.beats[i - 1].sample),
        reason: 'beats must be strictly sorted and unique at $i',
      );
    }
  }
}

void main() {
  late Project base;
  final t0 = DateTime.utc(2026, 11, 23, 12, 0, 0);

  setUp(() {
    base =
        createDemoProject(
          id: 'cmd_test',
          sampleRate: 44100,
          bpm: 120.0,
          beatPhaseSample: 500,
          includeBeats: false,
        ).copyWith(
          sampleCount: 44100 * 10, // 441,000 frames (10 s)
          beats: const [
            Beat(sample: 500, type: BeatType.downbeat),
            Beat(sample: 22550, type: BeatType.beat),
            Beat(sample: 44600, type: BeatType.strong),
            Beat(sample: 66650, type: BeatType.beat),
            Beat(sample: 88700, type: BeatType.drop),
          ],
          sections: [
            Section(
              startSample: 0,
              endSample: 44100 * 5,
              name: SectionPreset.verse.name,
              colorArgb: SectionPreset.verse.colorArgb,
            ),
            Section(
              startSample: 44100 * 5,
              endSample: 44100 * 10,
              name: SectionPreset.drop.name,
              colorArgb: SectionPreset.drop.colorArgb,
            ),
          ],
        );
  });

  group('Individual commands apply + revert round-trip', () {
    test('AddBeats inserts sorted beats and revert removes only them', () {
      final cmd = AddBeats(const [
        Beat(sample: 10000, type: BeatType.beat),
        Beat(sample: 55000, type: BeatType.strong),
      ], selectSample: 10000);
      final after = cmd.apply(base);
      _assertBeatInvariants(after);
      expect(after.beats.length, base.beats.length + 2);
      expect(cmd.selectAfterApply(after), 1);
      final reverted = cmd.revert(after);
      expect(reverted, base);
      expect(cmd.selectAfterRevert(reverted), isNull);
    });

    test(
      'DeleteBeat removes beat and revert restores beat, type and index',
      () {
        final cmd = DeleteBeat(index: 2, beat: base.beats[2]);
        final after = cmd.apply(base);
        _assertBeatInvariants(after);
        expect(after.beats.length, base.beats.length - 1);
        expect(cmd.selectAfterApply(after), isNull);
        final reverted = cmd.revert(after);
        expect(reverted, base);
        expect(cmd.selectAfterRevert(reverted), 2);
      },
    );

    test(
      'MoveBeat moves beat and revert restores original sample + selection',
      () {
        final cmd = MoveBeat(index: 1, fromSample: 22550, toSample: 23000);
        final after = cmd.apply(base);
        _assertBeatInvariants(after);
        expect(after.beats[1].sample, 23000);
        expect(cmd.selectAfterApply(after), 1);
        final reverted = cmd.revert(after);
        expect(reverted, base);
        expect(cmd.selectAfterRevert(reverted), 1);
      },
    );

    test(
      'SetBeatType changes type and revert restores old type + selection',
      () {
        final cmd = SetBeatType(
          index: 1,
          oldType: BeatType.beat,
          newType: BeatType.drop,
        );
        final after = cmd.apply(base);
        expect(after.beats[1].type, BeatType.drop);
        expect(cmd.selectAfterApply(after), 1);
        final reverted = cmd.revert(after);
        expect(reverted, base);
        expect(cmd.selectAfterRevert(reverted), 1);
      },
    );

    test('ShiftAll moves beats and beatPhaseSample, clamping at both ends', () {
      // Shift negative beyond beat 0 (sample 500) -> clamps to -500.
      final leftCmd = ShiftAll(deltaSamples: -2000);
      final left = leftCmd.apply(base);
      _assertBeatInvariants(left);
      expect(left.beats.first.sample, 0);
      expect(left.beats[1].sample, 22550 - 500);
      expect(left.beatPhaseSample, 0);
      expect(leftCmd.revert(left), base);

      // Shift positive beyond lastFrame (440,999) from last beat (88,700).
      final rightCmd = ShiftAll(deltaSamples: 500000);
      final right = rightCmd.apply(base);
      _assertBeatInvariants(right);
      final expectedDelta = (base.sampleCount - 1) - 88700;
      expect(right.beats.last.sample, base.sampleCount - 1);
      expect(right.beats.first.sample, 500 + expectedDelta);
      expect(right.beatPhaseSample, 500 + expectedDelta);
      expect(rightCmd.revert(right), base);
    });

    test(
      'ClearRange removes all beats in [start, end] including hidden ones',
      () {
        final filtered = base.copyWith(
          detection: base.detection.copyWith(filter: BeatFilter.drops),
        );
        final cmd = ClearRange(startSample: 20000, endSample: 70000);
        final after = cmd.apply(filtered);
        _assertBeatInvariants(after);
        // Beats at 22550, 44600, 66650 are removed even though filter is drops.
        expect(after.beats.map((b) => b.sample).toList(), [500, 88700]);
        final reverted = cmd.revert(after);
        expect(reverted, filtered);
      },
    );

    test(
      'SnapRange snaps beats in range and merges collisions by precedence',
      () {
        // 120 BPM at 44100 Hz => grid = 22050, phase = 500.
        // Grid lines: 500, 22550, 44600, 66650...
        final messy = base.copyWith(
          beats: const [
            Beat(sample: 500, type: BeatType.downbeat),
            // Both within half a grid of 22550: strong vs beat -> strong wins.
            Beat(sample: 21000, type: BeatType.beat),
            Beat(sample: 23500, type: BeatType.strong),
            // Both near 44600: drop vs downbeat -> drop wins.
            Beat(sample: 44000, type: BeatType.downbeat),
            Beat(sample: 45200, type: BeatType.drop),
            // Both near 66650: downbeat vs strong -> downbeat wins.
            Beat(sample: 66000, type: BeatType.strong),
            Beat(sample: 67000, type: BeatType.downbeat),
          ],
        );
        final cmd = SnapRange(startSample: 20000, endSample: 70000);
        final after = cmd.apply(messy);
        _assertBeatInvariants(after);
        expect(after.beats, const [
          Beat(sample: 500, type: BeatType.downbeat),
          Beat(sample: 22550, type: BeatType.strong),
          Beat(sample: 44600, type: BeatType.drop),
          Beat(sample: 66650, type: BeatType.downbeat),
        ]);
        expect(cmd.revert(after), messy);
      },
    );

    test('SetSections replaces sections and revert restores old list', () {
      final next = [
        Section(
          startSample: 0,
          endSample: base.sampleCount,
          name: 'Song',
          colorArgb: SectionPreset.intro.colorArgb,
        ),
      ];
      final cmd = SetSections(oldSections: base.sections, newSections: next);
      final after = cmd.apply(base);
      expect(after.sections, next);
      expect(cmd.revert(after), base);
    });

    test('ReplaceAll replaces and reverts all five editable fields', () {
      final cmd = ReplaceAll(
        oldBeats: base.beats,
        newBeats: const [Beat(sample: 1000, type: BeatType.drop)],
        oldSections: base.sections,
        newSections: const [],
        oldBpm: base.bpm,
        newBpm: 140.0,
        oldBeatPhaseSample: base.beatPhaseSample,
        newBeatPhaseSample: 1000,
        oldDetection: base.detection,
        newDetection: const DetectionSettings(
          sensitivity: 0.8,
          filter: BeatFilter.drops,
          status: DetectionStatus.succeeded,
        ),
      );
      final after = cmd.apply(base);
      _assertBeatInvariants(after);
      expect(after.bpm, 140.0);
      expect(after.beatPhaseSample, 1000);
      expect(after.sections, isEmpty);
      expect(after.detection.status, DetectionStatus.succeeded);
      expect(after.detection.filter, BeatFilter.drops);

      final reverted = cmd.revert(after);
      expect(reverted, base);
    });
  });

  group('CommandStack behaviour', () {
    test(
      'nudge coalescing merges within 1 s, splits at 1 s+ or after other cmd',
      () {
        final stack = CommandStack();
        var p = base;

        final r1 = stack.execute(
          p,
          MoveBeat(index: 1, fromSample: 22550, toSample: 22600),
          at: t0,
        );
        p = r1.project;

        // 500 ms later -> merges.
        final r2 = stack.execute(
          p,
          MoveBeat(index: 1, fromSample: 22600, toSample: 22700),
          at: t0.add(const Duration(milliseconds: 500)),
        );
        p = r2.project;
        expect(stack.undoLength, 1);

        // Exactly 1000 ms later -> does NOT merge.
        final r3 = stack.execute(
          p,
          MoveBeat(index: 1, fromSample: 22700, toSample: 22800),
          at: t0.add(const Duration(milliseconds: 1500)),
        );
        p = r3.project;
        expect(stack.undoLength, 2);

        // Different command then nudge within 100 ms -> does NOT merge.
        final r4 = stack.execute(
          p,
          SetBeatType(
            index: 1,
            oldType: BeatType.beat,
            newType: BeatType.strong,
          ),
          at: t0.add(const Duration(milliseconds: 1600)),
        );
        p = r4.project;
        final r5 = stack.execute(
          p,
          MoveBeat(index: 1, fromSample: 22800, toSample: 22900),
          at: t0.add(const Duration(milliseconds: 1700)),
        );
        p = r5.project;
        expect(stack.undoLength, 4);

        // Undo step by step.
        p = stack.undo(p)!.project;
        expect(p.beats[1].sample, 22800);
        p = stack.undo(p)!.project;
        expect(p.beats[1].type, BeatType.beat);
        p = stack.undo(p)!.project;
        expect(p.beats[1].sample, 22700);
        p = stack.undo(p)!.project;
        expect(p.beats[1].sample, 22550);
        expect(p, base);
      },
    );

    test('caps history at 100 entries and clears redo on new command', () {
      final stack = CommandStack();
      var p = base;
      var t = t0;
      for (var i = 0; i < 120; i++) {
        t = t.add(const Duration(seconds: 2));
        final oldSample = p.beats[1].sample;
        final res = stack.execute(
          p,
          MoveBeat(index: 1, fromSample: oldSample, toSample: oldSample + 1),
          at: t,
        );
        p = res.project;
      }
      expect(stack.undoLength, 100);
      expect(stack.canUndo, isTrue);
      expect(stack.canRedo, isFalse);

      p = stack.undo(p)!.project;
      expect(stack.canRedo, isTrue);
      expect(stack.undoLength, 99);

      // New command clears redo.
      t = t.add(const Duration(seconds: 2));
      p = stack
          .execute(
            p,
            SetBeatType(
              index: 1,
              oldType: p.beats[1].type,
              newType: BeatType.strong,
            ),
            at: t,
          )
          .project;
      expect(stack.canRedo, isFalse);
      expect(stack.redoLength, 0);
    });

    test('seeded random sequence of 250 commands: undo all -> original, redo all -> final', () {
      final rng = math.Random(20261123);
      // Use maxEntries = 300 so all 250 commands fit for full undo/redo round-trip.
      final stack = CommandStack(maxEntries: 300);
      var p = base;
      var t = t0;
      final lastFrame = p.sampleCount - 1;

      for (var step = 0; step < 250; step++) {
        t = t.add(const Duration(seconds: 2));
        final op = rng.nextInt(8);
        EditCommand? cmd;

        switch (op) {
          case 0: // AddBeats
            final count = 1 + rng.nextInt(3);
            final toAdd = <Beat>[];
            for (var k = 0; k < count; k++) {
              final s = rng.nextInt(lastFrame + 1);
              final type = BeatType.values[rng.nextInt(BeatType.values.length)];
              toAdd.add(Beat(sample: s, type: type));
            }
            cmd = AddBeats(toAdd);
          case 1: // DeleteBeat
            if (p.beats.isNotEmpty) {
              final idx = rng.nextInt(p.beats.length);
              cmd = DeleteBeat(index: idx, beat: p.beats[idx]);
            }
          case 2: // MoveBeat
            if (p.beats.isNotEmpty) {
              final idx = rng.nextInt(p.beats.length);
              final lo = idx > 0 ? p.beats[idx - 1].sample + 1 : 0;
              final hi = idx < p.beats.length - 1
                  ? p.beats[idx + 1].sample - 1
                  : lastFrame;
              if (lo <= hi) {
                final target = lo + rng.nextInt(hi - lo + 1);
                cmd = MoveBeat(
                  index: idx,
                  fromSample: p.beats[idx].sample,
                  toSample: target,
                );
              }
            }
          case 3: // SetBeatType
            if (p.beats.isNotEmpty) {
              final idx = rng.nextInt(p.beats.length);
              final newType =
                  BeatType.values[rng.nextInt(BeatType.values.length)];
              cmd = SetBeatType(
                index: idx,
                oldType: p.beats[idx].type,
                newType: newType,
              );
            }
          case 4: // ShiftAll
            final delta = rng.nextInt(40001) - 20000;
            cmd = ShiftAll(deltaSamples: delta);
          case 5: // ClearRange
            final a = rng.nextInt(lastFrame + 1);
            final b = rng.nextInt(lastFrame + 1);
            cmd = ClearRange(
              startSample: math.min(a, b),
              endSample: math.max(a, b),
            );
          case 6: // SnapRange
            if (p.bpm != null) {
              final a = rng.nextInt(lastFrame + 1);
              final b = rng.nextInt(lastFrame + 1);
              cmd = SnapRange(
                startSample: math.min(a, b),
                endSample: math.max(a, b),
              );
            }
          case 7: // ReplaceAll
            final nextBeats = <Beat>[
              for (var k = 0; k < 5; k++)
                Beat(
                  sample: rng.nextInt(lastFrame + 1),
                  type: BeatType.values[rng.nextInt(BeatType.values.length)],
                ),
            ];
            cmd = ReplaceAll(
              oldBeats: p.beats,
              newBeats: nextBeats,
              oldSections: p.sections,
              newSections: [
                Section(
                  startSample: 0,
                  endSample: p.sampleCount,
                  name: 'S$step',
                  colorArgb: SectionPreset.verse.colorArgb,
                ),
              ],
              oldBpm: p.bpm,
              newBpm: 90.0 + rng.nextInt(60),
              oldBeatPhaseSample: p.beatPhaseSample,
              newBeatPhaseSample: rng.nextInt(2000),
              oldDetection: p.detection,
              newDetection: p.detection.copyWith(
                sensitivity: (rng.nextInt(10) + 1) / 10.0,
              ),
            );
        }

        if (cmd != null) {
          p = stack.execute(p, cmd, at: t).project;
          _assertBeatInvariants(p);
        }
      }

      final finalProject = p;

      // Undo all -> original.
      while (stack.canUndo) {
        p = stack.undo(p)!.project;
        _assertBeatInvariants(p);
      }
      expect(p, base);

      // Redo all -> final.
      while (stack.canRedo) {
        p = stack.redo(p)!.project;
        _assertBeatInvariants(p);
      }
      expect(p, finalProject);
    });
  });
}
