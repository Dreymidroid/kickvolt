import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app_theme.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:kickvolt/features/settings/settings.dart';
import 'package:kickvolt/shared/shared.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/demo_project.dart';
import '../../../fixtures/editor_fakes.dart';
import '../../playback/fake_audio_playback.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const sampleRate = 44100;
  const playhead15s = 15 * sampleRate; // Beat 33 (index 32) is at 15.000 s.

  Finder iconButtonFor(String label) => find.ancestor(
    of: find.bySemanticsLabel(label),
    matching: find.byType(KvIconButton),
  );

  bool isButtonEnabled(WidgetTester tester, String label) {
    final btn = tester.widget<KvIconButton>(iconButtonFor(label));
    return btn.onPressed != null;
  }

  Future<
    ({
      BeatEditorCubit cubit,
      FakeAudioPlayback player,
      FakeDemoProjectRepository repo,
      RecordingHaptics haptics,
    })
  >
  pumpEditor(
    WidgetTester tester, {
    Project? project,
    int initialPlayheadSample = playhead15s,
    AppSettings initialSettings = const AppSettings(
      latencyOffsetMs: 40,
      latencyCalibratedOn: OutputKind.builtIn,
      coachMarksDone: true,
    ),
    int Function()? nowUs,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeDemoProjectRepository(project);
    final player = FakeAudioPlayback();
    final settings = FakeSettingsRepository(initialSettings);
    final outputRoute = FakeOutputRouteService(kind: OutputKind.builtIn);
    final haptics = RecordingHaptics(settings: settings);
    final previewRepo = FakeClickPreviewRepository();
    addTearDown(outputRoute.dispose);

    final id = (project ?? createDemoProject()).id;
    final cubit = BeatEditorCubit(
      repository: repo,
      playback: player,
      clickPreviewRepository: previewRepo,
      settingsRepository: settings,
      outputRouteService: outputRoute,
      haptics: haptics,
      nowUs: nowUs,
      saveDebounce: Duration.zero,
    );
    await cubit.load(id, initialPlayheadSample: initialPlayheadSample);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: BeatEditorScreen(projectId: id, cubit: cubit),
      ),
    );
    await tester.pump();
    return (cubit: cubit, player: player, repo: repo, haptics: haptics);
  }

  BeatEditorReady ready(BeatEditorCubit c) => c.state as BeatEditorReady;

  group('BeatEditorScreen widget tests (§8)', () {
    testWidgets(
      '(1) & (7) tap marker -> info card -> nudge +10 -> undo -> redo & undo/redo button enabled state',
      (tester) async {
        final env = await pumpEditor(tester);
        final cubit = env.cubit;

        // Initially undo/redo buttons are disabled.
        expect(isButtonEnabled(tester, 'Undo'), isFalse);
        expect(isButtonEnabled(tester, 'Redo'), isFalse);

        // Tap the centre of BeatTimeline where Beat 33 (index 32) sits at 15.000 s.
        final timelineCenter = tester.getCenter(find.byType(BeatTimeline));
        await tester.tapAt(timelineCenter);
        await tester.pump();

        expect(ready(cubit).selectedIndex, 32);
        expect(find.byType(BeatInfoCard), findsOneWidget);
        expect(find.byType(BeatInspectorPanel), findsOneWidget);
        expect(ready(cubit).project.beats[32].sample, playhead15s);

        // Nudge +10 ms (+441 samples at 44.1 kHz).
        await tester.tap(find.bySemanticsLabel('Nudge right 10 milliseconds'));
        await tester.pump();
        expect(ready(cubit).project.beats[32].sample, playhead15s + 441);

        // Undo is now enabled; redo is still disabled.
        expect(isButtonEnabled(tester, 'Undo'), isTrue);
        expect(isButtonEnabled(tester, 'Redo'), isFalse);

        // Tap Undo -> restores original sample, enables Redo, disables Undo.
        await tester.tap(iconButtonFor('Undo'));
        await tester.pump();
        expect(ready(cubit).project.beats[32].sample, playhead15s);
        expect(isButtonEnabled(tester, 'Undo'), isFalse);
        expect(isButtonEnabled(tester, 'Redo'), isTrue);

        // Tap Redo -> reapplies +441 samples.
        await tester.tap(iconButtonFor('Redo'));
        await tester.pump();
        expect(ready(cubit).project.beats[32].sample, playhead15s + 441);
      },
    );

    testWidgets('(2) delete + undo restores the same beat and type', (
      tester,
    ) async {
      final env = await pumpEditor(tester);
      final cubit = env.cubit;
      final originalBeat = ready(cubit).project.beats[32];

      // Select Beat 33 (index 32, strong).
      await tester.tapAt(tester.getCenter(find.byType(BeatTimeline)));
      await tester.pump();

      // Tap Delete.
      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(ready(cubit).project.beatCount, 357);
      expect(ready(cubit).selectedIndex, isNull);

      // Tap Undo -> restores exact beat & type and selects it again.
      await tester.tap(iconButtonFor('Undo'));
      await tester.pump();
      expect(ready(cubit).project.beatCount, 358);
      expect(ready(cubit).project.beats[32], originalBeat);
      expect(ready(cubit).selectedIndex, 32);
    });

    testWidgets(
      '(3) Tap tab: play, tap pad 4 times, pause -> 4 beats added at expected samples, 1 undo removes all 4',
      (tester) async {
        final empty = createDemoProject(
          id: 'tap_widget',
          sampleRate: sampleRate,
          bpm: null,
          includeBeats: false,
        );
        var wallUs = 1000000;
        final env = await pumpEditor(
          tester,
          project: empty,
          initialPlayheadSample: 0,
          nowUs: () => wallUs,
        );
        final cubit = env.cubit;
        final player = env.player;

        // Switch to Tap tab.
        await tester.tap(find.text('Tap'));
        await tester.pump();
        expect(find.text('Press play, then tap along'), findsOneWidget);

        // Start playing at 1.000 s.
        player.push(
          position: const Duration(seconds: 1),
          playing: true,
          advancing: true,
        );
        await tester.pump();
        expect(find.text('TAP'), findsOneWidget);

        // Tap the pad 4 times, 500 ms apart (1.0, 1.5, 2.0, 2.5 s) with 40 ms lag fix.
        final padCenter = tester.getCenter(find.text('TAP'));
        for (var i = 0; i < 4; i++) {
          await tester.tapAt(padCenter);
          await tester.pump();
          wallUs += 500000;
        }
        expect(find.text('+4'), findsOneWidget);

        // Pause -> commits all 4 as one AddBeats command.
        player.push(
          position: const Duration(milliseconds: 3000),
          playing: false,
        );
        await tester.pump();

        expect(ready(cubit).project.beats.length, 4);
        final expectedSamples = [
          (0.960 * sampleRate).round(),
          (1.460 * sampleRate).round(),
          (1.960 * sampleRate).round(),
          (2.460 * sampleRate).round(),
        ];
        expect(
          ready(cubit).project.beats.map((b) => b.sample).toList(),
          expectedSamples,
        );

        // One undo removes all 4 beats.
        await tester.tap(iconButtonFor('Undo'));
        await tester.pump();
        expect(ready(cubit).project.beats, isEmpty);
      },
    );

    testWidgets('(4) Bulk: Clear range + undo; Shift all -20 ms Apply + undo', (
      tester,
    ) async {
      // Offset demo beats by +0.1 s (4410 frames) so ShiftAll(-20 ms) is not
      // clamped at frame 0.
      final baseDemo = createDemoProject(id: 'bulk_widget');
      final shiftedDemo = baseDemo.copyWith(
        beats: [
          for (final b in baseDemo.beats) b.copyWith(sample: b.sample + 4410),
        ],
      );
      final env = await pumpEditor(tester, project: shiftedDemo);
      final cubit = env.cubit;
      final countBefore = ready(cubit).project.beatCount;
      final beat32Before = ready(cubit).project.beats[32].sample;

      await tester.tap(find.text('Bulk'));
      await tester.pump();
      expect(find.text('Clear range'), findsOneWidget);

      // Clear range + undo.
      await tester.tap(find.text('Clear range'));
      await tester.pump();
      expect(ready(cubit).project.beatCount, lessThan(countBefore));

      await tester.tap(iconButtonFor('Undo'));
      await tester.pump();
      expect(ready(cubit).project.beatCount, countBefore);

      // Shift all -20 ms -> Apply -> Undo.
      final minusBtn = find.bySemanticsLabel('Shift earlier');
      for (var i = 0; i < 20; i++) {
        await tester.tap(minusBtn);
      }
      await tester.pump();
      expect(find.text('−20 ms'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(ready(cubit).project.beats[32].sample, beat32Before - 882);
      expect(find.text('0 ms'), findsOneWidget);

      await tester.tap(iconButtonFor('Undo'));
      await tester.pump();
      expect(ready(cubit).project.beats[32].sample, beat32Before);
    });

    testWidgets('(5) long-press on waveform adds a beat', (tester) async {
      final empty = createDemoProject(
        id: 'long_press',
        sampleRate: sampleRate,
        bpm: null,
        includeBeats: false,
      );
      final env = await pumpEditor(
        tester,
        project: empty,
        initialPlayheadSample: playhead15s,
      );
      final cubit = env.cubit;

      await tester.longPressAt(tester.getCenter(find.byType(BeatTimeline)));
      await tester.pump();
      expect(ready(cubit).project.beats.length, 1);
      expect(
        (ready(cubit).project.beats.single.sample - playhead15s).abs(),
        lessThanOrEqualTo(5),
      );
      expect(ready(cubit).selectedIndex, 0);
    });

    testWidgets('(6) Sections: split + rename + undo', (tester) async {
      final noSections = createDemoProject(
        id: 'sec_widget',
        sampleRate: sampleRate,
      ).copyWith(sections: const []);
      final env = await pumpEditor(
        tester,
        project: noSections,
        initialPlayheadSample: playhead15s,
      );
      final cubit = env.cubit;

      await tester.tap(find.text('Sections'));
      await tester.pump();

      // Split at playhead -> creates 2 sections ("Song" + "Verse").
      await tester.tap(find.text('Split at playhead'));
      await tester.pump();
      expect(ready(cubit).project.sections.length, 2);
      expect(find.text('Song'), findsOneWidget);

      // Rename first section to "Intro Cut".
      await tester.tap(find.text('Rename').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Intro Cut');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(ready(cubit).project.sections.first.name, 'Intro Cut');
      expect(find.text('Intro Cut'), findsOneWidget);

      // Undo rename -> back to "Song".
      await tester.tap(iconButtonFor('Undo'));
      await tester.pump();
      expect(ready(cubit).project.sections.first.name, 'Song');

      // Undo split -> back to empty.
      await tester.tap(iconButtonFor('Undo'));
      await tester.pump();
      expect(ready(cubit).project.sections, isEmpty);
    });
  });
}
