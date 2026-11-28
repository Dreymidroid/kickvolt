import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kickvolt/app/app.dart';
import 'package:kickvolt/app/app_router.dart';
import 'package:kickvolt/core/audio_native/audio_native_client.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:kickvolt/features/settings/settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/editor_fakes.dart';
import '../../../fixtures/export_fakes.dart';

class _MockImportRepository extends Mock implements ImportRepository {}

class _MockProjectRepository extends Mock implements ProjectRepository {}

class _MockDetectionRepository extends Mock
    implements BeatDetectionRepository {}

class _MockSourcePicker extends Mock implements SourcePicker {}

class _FakeCancelToken extends Fake implements ImportCancelToken {}

class _FakePickedSource extends Fake implements PickedSource {}

/// Regression for the on-device integration test I3 (2026-11-27): importing
/// a text file renamed `.mp3` left the Analyzing screen stuck at 100 %.
/// The failure is emitted while the screen's PopScope still says
/// `canPop: false`, so the listener's pop was refused and no error showed.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePickedSource());
    registerFallbackValue(_FakeCancelToken());
  });

  const source = PickedSource(
    kind: ImportSourceKind.file,
    location: '/tmp/not_a_song.mp3',
    displayName: 'not_a_song.mp3',
  );

  late AppRouter router;
  late _MockImportRepository imports;
  late _MockProjectRepository projects;

  setUp(() async {
    final loc = GetIt.instance;
    await loc.reset();
    final settings = FakeSettingsRepository();
    await settings.save(const AppSettings(onboardingDone: true));
    projects = _MockProjectRepository();
    imports = _MockImportRepository();
    when(projects.listProjects).thenAnswer((_) async => const []);
    loc.registerSingleton<SettingsRepository>(settings);
    loc.registerSingleton<ProjectRepository>(projects);
    loc.registerSingleton<SourcePicker>(_MockSourcePicker());
    loc.registerSingleton<AudioNative>(FakeCubitAudioNative());
    router = AppRouter(settingsRepository: settings);
  });

  tearDown(() => GetIt.instance.reset());

  Future<Object?> runImport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(KickVoltApp(router: router));
    await tester.pumpAndSettle();

    final cubit = ImportCubit(
      source: source,
      repository: imports,
      projectRepository: projects,
      detectionRepository: _MockDetectionRepository(),
    );
    Object? result = #notPopped;
    router
        .push<Object?>(AnalyzingRoute(source: source, cubit: cubit))
        .then((r) => result = r);
    await tester.pumpAndSettle();
    expect(find.byType(AnalyzingView), findsOneWidget);

    await cubit.start();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a failed import pops Analyzing with the failure', (
    tester,
  ) async {
    const failure = ImportFailure(
      ImportFailureKind.unsupported,
      fileName: 'not_a_song.mp3',
    );
    when(
      () => imports.importSong(
        any(),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(failure);

    final result = await runImport(tester);

    expect(find.byType(AnalyzingView), findsNothing);
    expect(result, same(failure));
  });

  testWidgets('a cancelled import pops Analyzing', (tester) async {
    when(
      () => imports.importSong(
        any(),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(const ImportCancelled());

    final result = await runImport(tester);

    expect(find.byType(AnalyzingView), findsNothing);
    expect(result, isNull);
  });
}
