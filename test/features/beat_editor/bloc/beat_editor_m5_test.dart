import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:kickvolt/features/settings/settings.dart';

import '../../../fixtures/demo_project.dart';
import '../../../fixtures/editor_fakes.dart';
import '../../playback/fake_audio_playback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleRate = 44100;
  const playhead15s = 15 * sampleRate;

  late FakeDemoProjectRepository repo;
  late FakeAudioPlayback player;
  late FakeSettingsRepository settings;
  late FakeOutputRouteService outputRoute;
  late RecordingHaptics haptics;

  setUp(() {
    repo = FakeDemoProjectRepository();
    player = FakeAudioPlayback();
    settings = FakeSettingsRepository(
      const AppSettings(
        latencyOffsetMs: 40,
        latencyCalibratedOn: OutputKind.builtIn,
        hapticsEnabled: true,
      ),
    );
    outputRoute = FakeOutputRouteService(kind: OutputKind.builtIn);
    haptics = RecordingHaptics(settings: settings);
  });

  tearDown(() => outputRoute.dispose());

  BeatEditorReady ready(BeatEditorCubit c) => c.state as BeatEditorReady;

  group('Tap tab run & latency compensation', () {
    test('taps place beats at sampleNow - offset, skip duplicates, and commit as one undo', () async {
      final empty = createDemoProject(
        id: 'tap_song',
        sampleRate: sampleRate,
        bpm: null,
        includeBeats: false,
      );
      repo.put(empty);

      var wallUs = 0;
      final c = BeatEditorCubit(
        repository: repo,
        playback: player,
        settingsRepository: settings,
        outputRouteService: outputRoute,
        haptics: haptics,
        nowUs: () => wallUs,
      );
      await c.load('tap_song');
      expect(ready(c).latencyOffsetMs, 40);

      c.selectTool(EditorTool.tap);
      // Ignored while paused.
      c.tapBeat();
      expect(ready(c).tapRunBeats, isEmpty);

      // Start playback at 1.000 s.
      wallUs = 1000000;
      player.push(
        position: const Duration(seconds: 1),
        playing: true,
        advancing: true,
      );

      // Tap at 1.000 s -> 1.000 s - 40 ms = 0.960 s = 42,336 samples.
      c.tapBeat();
      // Duplicate 5 ms later -> skipped (< 20 ms gap).
      wallUs += 5000;
      c.tapBeat();
      // Tap 500 ms later (1.505 s) -> 1.465 s.
      wallUs += 500000;
      c.tapBeat();

      expect(ready(c).tapRunBeats.length, 2);
      expect(ready(c).tapRunBeats[0].sample, (0.960 * sampleRate).round());
      expect(ready(c).tapRunBeats[1].sample, (1.465 * sampleRate).round());
      // Not committed yet while playing.
      expect(ready(c).project.beats, isEmpty);
      expect(haptics.events, ['selectionClick', 'selectionClick']);

      // Pause commits the entire run as ONE AddBeats command.
      player.push(position: const Duration(milliseconds: 1600), playing: false);
      expect(ready(c).tapRunBeats, isEmpty);
      expect(ready(c).project.beats.length, 2);
      expect(ready(c).canUndo, isTrue);

      // One undo removes both beats.
      c.undo();
      expect(ready(c).project.beats, isEmpty);
      expect(ready(c).canUndo, isFalse);

      // Redo restores both beats.
      c.redo();
      expect(ready(c).project.beats.length, 2);
      await c.close();
    });

    test('tap snaps to BPM grid when snap is on', () async {
      // 120 BPM at 44100 Hz => grid = 22050 samples, phase = 0.
      final gridded = createDemoProject(
        id: 'snap_tap',
        sampleRate: sampleRate,
        bpm: 120.0,
        beatPhaseSample: 0,
        includeBeats: false,
      );
      repo.put(gridded);

      final c = BeatEditorCubit(
        repository: repo,
        playback: player,
        settingsRepository: FakeSettingsRepository(
          const AppSettings(
            latencyOffsetMs: 0,
            latencyCalibratedOn: OutputKind.builtIn,
          ),
        ),
        outputRouteService: outputRoute,
        haptics: haptics,
      );
      await c.load('snap_tap');
      c.selectTool(EditorTool.tap);
      // 520 ms is close to 500 ms (22050 samples).
      player.push(
        position: const Duration(milliseconds: 520),
        playing: true,
        advancing: false,
      );
      c.tapBeat();
      expect(ready(c).tapRunBeats.single.sample, 22050);

      // Leaving Tap tab commits the run.
      c.selectTool(EditorTool.edit);
      expect(ready(c).tapRunBeats, isEmpty);
      expect(ready(c).project.beats.single.sample, 22050);
      await c.close();
    });

    test('uses iOS reported output latency before calibration, and replaces it after calibration', () async {
      outputRoute.latency = const Duration(milliseconds: 28);
      final uncalibrated = FakeSettingsRepository(const AppSettings());
      final c1 = BeatEditorCubit(
        repository: repo,
        playback: player,
        settingsRepository: uncalibrated,
        outputRouteService: outputRoute,
        haptics: haptics,
      );
      await c1.load('demo');
      expect(ready(c1).latencyOffsetMs, 28);
      await c1.close();

      // Once calibrated, platform latency is NOT added on top.
      await uncalibrated.save(
        const AppSettings(
          latencyOffsetMs: 42,
          latencyCalibratedOn: OutputKind.builtIn,
        ),
      );
      final c2 = BeatEditorCubit(
        repository: repo,
        playback: FakeAudioPlayback(),
        settingsRepository: uncalibrated,
        outputRouteService: outputRoute,
        haptics: haptics,
      );
      await c2.load('demo');
      expect(ready(c2).latencyOffsetMs, 42);
      await c2.close();
    });
  });

  group('Bulk tab operations', () {
    test('clear range, shift all, and snap range go through command stack with haptics', () async {
      final c = BeatEditorCubit(
        repository: repo,
        playback: player,
        settingsRepository: settings,
        outputRouteService: outputRoute,
        haptics: haptics,
      );
      await c.load('demo', initialPlayheadSample: playhead15s);
      c.setViewportWidth(390);
      c.selectTool(EditorTool.bulk);

      // Default range is middle half of viewport around playhead.
      expect(ready(c).bulkRangeStart, isNotNull);
      expect(ready(c).bulkRangeEnd, isNotNull);
      expect(ready(c).bulkRangeStart!, lessThan(playhead15s));
      expect(ready(c).bulkRangeEnd!, greaterThan(playhead15s));

      // Clear range -> removes beats in range, warningNotification, undoable.
      final countBefore = ready(c).project.beatCount;
      c.clearBulkRange();
      expect(ready(c).project.beatCount, lessThan(countBefore));
      expect(haptics.events.last, 'warningNotification');
      c.undo();
      expect(ready(c).project.beatCount, countBefore);

      // Shift all beats by +20 ms (+882 frames) -> shifts beats, resets shiftMs to 0.
      // (Note: demo beat 0 is at sample 0, so a negative shift clamps to 0.)
      final beat32Before = ready(c).project.beats[32].sample;
      c.setBulkShiftMs(20);
      expect(ready(c).bulkShiftMs, 20);
      c.applyBulkShift();
      expect(ready(c).bulkShiftMs, 0);
      expect(ready(c).project.beats[32].sample, beat32Before + 882);
      expect(haptics.events.last, 'selectionClick');

      // Snap range brings beat 32 back onto the grid.
      c.setBulkRange(
        ready(c).project.beats[32].sample - 1000,
        ready(c).project.beats[32].sample + 1000,
        applySnap: false,
      );
      c.snapBulkRange();
      expect(
        ready(c).project.isOnGrid(ready(c).project.beats[32].sample),
        isTrue,
      );

      // Undo snap, undo shift -> back to original.
      c.undo();
      expect(ready(c).project.beats[32].sample, beat32Before + 882);
      c.undo();
      expect(ready(c).project.beats[32].sample, beat32Before);
      await c.close();
    });
  });

  group('Sections tab operations and invariants', () {
    test(
      'split, rename, recolour, delete maintain invariants and undo cleanly',
      () async {
        final noSections = createDemoProject(
          id: 'sec_test',
          sampleRate: sampleRate,
        ).copyWith(sections: const []);
        repo.put(noSections);

        final c = BeatEditorCubit(
          repository: repo,
          playback: player,
          settingsRepository: settings,
          outputRouteService: outputRoute,
          haptics: haptics,
        );
        await c.load('sec_test', initialPlayheadSample: playhead15s);

        // Split on empty sections creates "Song" and splits at nearest beat (15 s).
        c.splitSectionAtPlayhead();
        var secs = ready(c).project.sections;
        expect(secs.length, 2);
        expect(secs[0].name, 'Song');
        expect(secs[0].endSample, playhead15s);
        expect(secs[1].startSample, playhead15s);
        expect(areSectionsValid(secs, ready(c).project.sampleCount), isTrue);

        // Rename + recolour.
        c.renameSection(1, 'Chorus');
        expect(ready(c).project.sections[1].name, 'Chorus');
        c.recolourSection(1, SectionPreset.drop.colorArgb);
        expect(
          ready(c).project.sections[1].colorArgb,
          SectionPreset.drop.colorArgb,
        );
        expect(
          areSectionsValid(
            ready(c).project.sections,
            ready(c).project.sampleCount,
          ),
          isTrue,
        );

        // Delete second section merges it into first.
        c.deleteSection(1);
        secs = ready(c).project.sections;
        expect(secs.length, 1);
        expect(secs.single.startSample, 0);
        expect(secs.single.endSample, ready(c).project.sampleCount);
        expect(haptics.events.last, 'warningNotification');

        // Delete last remaining section clears list.
        c.deleteSection(0);
        expect(ready(c).project.sections, isEmpty);
        expect(
          areSectionsValid(const [], ready(c).project.sampleCount),
          isTrue,
        );

        // Undo all 5 section edits -> back to empty.
        c.undo();
        expect(ready(c).project.sections.length, 1);
        c.undo();
        expect(ready(c).project.sections.length, 2);
        c.undo();
        c.undo();
        c.undo();
        expect(ready(c).project.sections, isEmpty);
        await c.close();
      },
    );
  });

  group('Haptics global switch', () {
    test('fires nothing when hapticsEnabled is false', () async {
      await settings.save(const AppSettings(hapticsEnabled: false));
      final c = BeatEditorCubit(
        repository: repo,
        playback: player,
        settingsRepository: settings,
        outputRouteService: outputRoute,
        haptics: haptics,
      );
      await c.load('demo', initialPlayheadSample: playhead15s);
      c
        ..selectBeat(32)
        ..nudgeSelected(10)
        ..deleteSelected();
      expect(haptics.events, isEmpty);
      await c.close();
    });
  });
}
