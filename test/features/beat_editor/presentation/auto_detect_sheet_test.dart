import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app_theme.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:kickvolt/features/settings/settings.dart';
import 'package:kickvolt/shared/shared.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/demo_project.dart';
import '../../../fixtures/editor_fakes.dart';
import '../../playback/fake_audio_playback.dart';

class MockBeatDetectionRepository extends Mock
    implements BeatDetectionRepository {}

class FakeBeatAnalysis extends Fake implements BeatAnalysis {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(FakeBeatAnalysis());
    registerFallbackValue(AnalysisCancelToken());
    registerFallbackValue(const TrackingOptions());
  });

  BeatAnalysis buildAnalysis({
    double bpm = 128.0,
    double tempoStability = 0.035,
    SwingEstimate swing = const SwingEstimate(ratio: 0.66, confidence: 0.85),
    List<TempoCandidate>? candidates,
  }) {
    return BeatAnalysis(
      sampleRate: 44100,
      sampleCount: 44100 * 60,
      hopSize: 512,
      bpm: bpm,
      confidence: 3.5,
      beatPhaseSample: 500,
      candidates: const [
        CandidateBeat(index: 0, sample: 500, strength: 0.9, lowEnergy: 5.0),
        CandidateBeat(index: 1, sample: 22550, strength: 0.4, lowEnergy: 1.0),
        CandidateBeat(index: 2, sample: 44600, strength: 0.7, lowEnergy: 2.0),
        CandidateBeat(index: 3, sample: 66650, strength: 0.3, lowEnergy: 1.0),
      ],
      frameLowEnergy: Float32List(10),
      frameOverallEnergy: Float32List(10),
      tempoCandidates:
          candidates ??
          [
            TempoCandidate(bpm: bpm, periodFrames: 40.0, score: 1.0),
            if (bpm * 0.5 >= 40)
              TempoCandidate(bpm: bpm * 0.5, periodFrames: 80.0, score: 0.7),
            if (bpm * 2.0 <= 240)
              TempoCandidate(bpm: bpm * 2.0, periodFrames: 20.0, score: 0.6),
            const TempoCandidate(bpm: 96.0, periodFrames: 53.3, score: 0.45),
          ],
      localTempo: Float32List.fromList([39.0, 40.0, 41.5]),
      tempoStability: tempoStability,
      swing: swing,
    );
  }

  Future<BeatEditorCubit> pumpAutoDetectSheet(
    WidgetTester tester, {
    required BeatAnalysis analysis,
    Project? project,
  }) async {
    tester.view.physicalSize = const Size(390, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final p = project ?? createDemoProject();
    final repo = FakeDemoProjectRepository(p);
    final player = FakeAudioPlayback();
    final settings = FakeSettingsRepository(const AppSettings());
    final outputRoute = FakeOutputRouteService(kind: OutputKind.builtIn);
    final haptics = RecordingHaptics(settings: settings);
    final previewRepo = FakeClickPreviewRepository();
    final detectionRepo = MockBeatDetectionRepository();
    addTearDown(outputRoute.dispose);

    when(() => detectionRepo.getCachedAnalysis(any()))
        .thenAnswer((_) async => analysis);
    when(
      () => detectionRepo.retrack(
        any(),
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((inv) async {
      final opts = inv.positionalArguments[2] as TrackingOptions;
      return analysis.copyWithBpm(opts.targetBpm ?? analysis.bpm);
    });
    when(() => detectionRepo.classify(any(), any())).thenAnswer((inv) {
      final a = inv.positionalArguments[0] as BeatAnalysis;
      return DetectionResult(
        succeeded: true,
        beats: const [
          Beat(sample: 500, type: BeatType.downbeat),
          Beat(sample: 22550, type: BeatType.beat),
          Beat(sample: 44600, type: BeatType.strong),
          Beat(sample: 66650, type: BeatType.drop),
        ],
        bpm: a.bpm,
        beatPhaseSample: 500,
        sections: const [],
      );
    });

    final cubit = BeatEditorCubit(
      repository: repo,
      playback: player,
      detectionRepository: detectionRepo,
      clickPreviewRepository: previewRepo,
      settingsRepository: settings,
      outputRouteService: outputRoute,
      haptics: haptics,
      saveDebounce: Duration.zero,
    );
    await cubit.load(p.id);
    await cubit.openAutoDetectSheet();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: BeatEditorScreen(projectId: p.id, cubit: cubit),
      ),
    );
    await tester.pump();
    return cubit;
  }

  testWidgets(
    'Auto sheet shows Tempo row, chips (½x, Auto, 2x, More…), Tempo changes switch, suggestion, Swing feel, and "~" in varying mode',
    (tester) async {
      final analysis = buildAnalysis(
        bpm: 120.0,
        tempoStability: 0.04, // suggests varying tempo
        swing: const SwingEstimate(ratio: 0.66, confidence: 0.85),
      );
      final cubit = await pumpAutoDetectSheet(tester, analysis: analysis);

      // Tempo row and chips
      expect(find.text('Tempo'), findsOneWidget);
      expect(find.widgetWithText(KvChip, '½×'), findsOneWidget);
      expect(find.widgetWithText(KvChip, 'Auto'), findsOneWidget);
      expect(find.widgetWithText(KvChip, '2×'), findsOneWidget);
      expect(find.widgetWithText(KvChip, 'More…'), findsOneWidget);

      // Tempo changes suggestion when switch is Steady
      expect(
        find.text('The tempo seems to drift. Try Tempo changes.'),
        findsOneWidget,
      );

      // Swing feel read-only message when confident
      expect(
        find.text('Swing feel detected — beats stay on the main pulse.'),
        findsOneWidget,
      );

      // Steady preview line has no "~"
      expect(find.textContaining('≈ 4 beats · 120 BPM'), findsOneWidget);

      // Switch to Tempo changes -> preview line uses "~120 BPM" and suggestion hides
      await tester.tap(find.text('Tempo changes'));
      await tester.pumpAndSettle();

      expect(
        (cubit.state as BeatEditorReady).previewTempoMode,
        TempoMode.varying,
      );
      expect(find.text('≈ 4 beats · ~120 BPM'), findsOneWidget);
      expect(
        find.text('The tempo seems to drift. Try Tempo changes.'),
        findsNothing,
      );

      // Tapping More… lists the other tempoCandidates ("Try 96 BPM")
      await tester.tap(find.text('More…'));
      await tester.pumpAndSettle();
      expect(find.text('Try 96 BPM'), findsOneWidget);
    },
  );

  testWidgets('½x and 2x chips are disabled outside 40–240 BPM range edges', (
    tester,
  ) async {
    // At 150 BPM: 2x = 300 BPM (> 240, disabled), ½x = 75 BPM (enabled).
    final highBpmAnalysis = buildAnalysis(
      bpm: 150.0,
      tempoStability: 0.005,
      swing: const SwingEstimate(ratio: 0.50, confidence: 0.1),
    );
    await pumpAutoDetectSheet(tester, analysis: highBpmAnalysis);

    final twoXChip = tester.widget<KvChip>(find.widgetWithText(KvChip, '2×'));
    final halfXChip = tester.widget<KvChip>(find.widgetWithText(KvChip, '½×'));
    expect(
      twoXChip.onPressed,
      isNull,
      reason: '2x at 150 BPM = 300 > 240 must be disabled',
    );
    expect(
      halfXChip.onPressed,
      isNotNull,
      reason: '½x at 150 BPM = 75 >= 40 must be enabled',
    );
  });

  testWidgets('½x chip is disabled when ½x < 40 BPM (e.g. 70 BPM)', (
    tester,
  ) async {
    final lowBpmAnalysis = buildAnalysis(
      bpm: 70.0,
      tempoStability: 0.005,
      swing: const SwingEstimate(ratio: 0.50, confidence: 0.1),
    );
    await pumpAutoDetectSheet(tester, analysis: lowBpmAnalysis);

    final halfXChip = tester.widget<KvChip>(find.widgetWithText(KvChip, '½×'));
    final twoXChip = tester.widget<KvChip>(find.widgetWithText(KvChip, '2×'));
    expect(
      halfXChip.onPressed,
      isNull,
      reason: '½x at 70 BPM = 35 < 40 must be disabled',
    );
    expect(
      twoXChip.onPressed,
      isNotNull,
      reason: '2x at 70 BPM = 140 <= 240 must be enabled',
    );
  });
}
