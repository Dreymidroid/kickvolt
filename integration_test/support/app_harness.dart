import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/app/app.dart';
import 'package:kickvolt/app/bootstrap.dart';
import 'package:kickvolt/core/core.dart';
import 'package:kickvolt/features/features.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Prints one machine-greppable result line (`E2E_RESULT | id | key=value`).
void report(String id, String line) {
  // ignore: avoid_print
  print('E2E_RESULT | $id | $line');
}

/// Pumps 100 ms frames until [condition] holds, failing after [timeout].
/// The only way flows wait: native jobs take real, variable time.
Future<void> pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 90),
  required String reason,
}) async {
  final sw = Stopwatch()..start();
  while (!await condition()) {
    if (sw.elapsed > timeout) {
      fail(
        'Timed out after ${timeout.inSeconds} s waiting for: $reason\n'
        'Texts on screen: ${visibleTexts()}',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  // State may have changed inside an event handler with no frame since:
  // build once so finders see the result.
  await tester.pump();
}

/// Every [Text] currently in the tree, for failure messages.
List<String> visibleTexts() => [
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data case final String s) s,
];

/// Taps [finder] once it exists and has stopped moving (sheets and dialogs
/// slide in; a tap mid-animation can land on the wrong spot).
Future<void> tapWhenStable(WidgetTester tester, Finder finder) async {
  await pumpUntilFound(tester, finder);
  Rect? last;
  await pumpUntil(
    tester,
    () {
      final r = tester.getRect(finder.first);
      final stable = r == last;
      last = r;
      return stable;
    },
    timeout: const Duration(seconds: 10),
    reason: '${finder.describeMatch(Plurality.one)} to stop moving',
  );
  await tester.tap(finder.first);
  await tester.pump();
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 90),
}) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  timeout: timeout,
  reason: finder.describeMatch(Plurality.one),
);

/// Matches a widget whose [Semantics] label is exactly [label] (icon
/// buttons, switches and nudge buttons label themselves this way).
Finder bySemanticsLabel(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
  description: 'Semantics("$label")',
);

/// One running copy of the app under test, with the scripted services.
class E2EApp {
  final picker = FixtureSourcePicker();
  final share = RecordingShareService();
  final haptics = RecordingHaptics();
  late SaveRecordingAudioNative audio;
  late ProjectPaths paths;
  late Directory scratch;

  /// (Re)starts the app the way `main()` does, through [bootstrap].
  ///
  /// [wipe]: start from a clean documents directory and preferences
  /// (each flow does). `wipe: false` simulates a second launch: services
  /// are rebuilt and settings re-read from disk.
  Future<void> launch(
    WidgetTester tester, {
    bool wipe = true,
    bool onboardingDone = true,
    bool coachMarksDone = true,
  }) async {
    // Unmount the previous app so its cubits close.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await locator.reset();

    final docs = (await getApplicationDocumentsDirectory()).path;
    paths = ProjectPaths(docs);
    scratch = Directory(p.join((await getTemporaryDirectory()).path, 'e2e'));
    if (wipe) {
      final projects = Directory(paths.projectsDir);
      if (await projects.exists()) await projects.delete(recursive: true);
      if (await scratch.exists()) await scratch.delete(recursive: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool(
        SettingsRepositoryImpl.ONBOARDING_DONE,
        onboardingDone,
      );
      await prefs.setBool(
        SettingsRepositoryImpl.COACH_MARKS_DONE,
        coachMarksDone,
      );
    }
    await scratch.create(recursive: true);

    await bootstrap(
      overrides: (l) {
        l.registerLazySingleton<AudioNative>(
          () => SaveRecordingAudioNative(AudioNativeClient()),
        );
        l.registerLazySingleton<SourcePicker>(() => picker);
        l.registerLazySingleton<ShareService>(() => share);
        l.registerLazySingleton<Haptics>(() => haptics);
      },
    );
    audio = locator<AudioNative>() as SaveRecordingAudioNative;
    await tester.pumpWidget(KickVoltApp(key: UniqueKey()));
    await tester.pump();
  }

  /// Writes [bytes] into the scratch directory (outside the app's projects).
  Future<String> writeScratch(String name, List<int> bytes) async {
    final f = File(p.join(scratch.path, name));
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  String scratchPath(String name) => p.join(scratch.path, name);

  /// Home › Import a song › Files, with the fixture picker returning [path].
  Future<void> startImport(WidgetTester tester, String path) async {
    picker.next = PickedSource(
      kind: ImportSourceKind.file,
      location: path,
      displayName: p.basename(path),
    );
    await pumpUntilFound(tester, find.text('Import a song'));
    await tester.tap(find.text('Import a song').first);
    await pumpUntilFound(tester, find.text('Files'));
    await tapWhenStable(tester, find.text('Files'));
    await tester.pump();
  }

  /// [startImport], then waits for the editor to be ready.
  Future<BeatEditorReady> importToEditor(
    WidgetTester tester,
    String path, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    await startImport(tester, path);
    return waitForEditor(tester, timeout: timeout);
  }

  Future<BeatEditorReady> waitForEditor(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    await pumpUntil(
      tester,
      () =>
          find.byType(EditorTopBar).evaluate().isNotEmpty &&
          editorCubit(tester).state is BeatEditorReady,
      timeout: timeout,
      reason: 'beat editor ready',
    );
    return editorCubit(tester).state as BeatEditorReady;
  }

  BeatEditorCubit editorCubit(WidgetTester tester) =>
      tester.element(find.byType(EditorTopBar)).read<BeatEditorCubit>();

  ExportCubit exportCubit(WidgetTester tester) {
    final f = find.byType(ExportSuccessView).evaluate().isNotEmpty
        ? find.byType(ExportSuccessView)
        : find.byType(ExportOptionsView);
    return tester.element(f).read<ExportCubit>();
  }

  /// The export cubit's state while the Exporting view is up, else null.
  ExportExporting? exportingState(WidgetTester tester) {
    final f = find.byType(ExportingView);
    if (f.evaluate().isEmpty) return null;
    final s = tester.element(f).read<ExportCubit>().state;
    return s is ExportExporting ? s : null;
  }

  /// Editor › Back to projects, then waits for Home.
  Future<void> backToHome(WidgetTester tester) async {
    await tester.tap(bySemanticsLabel('Back to projects'));
    await pumpUntil(
      tester,
      () =>
          find.byType(EditorTopBar).evaluate().isEmpty &&
          find.text('KickVolt').evaluate().isNotEmpty,
      reason: 'editor closed, Home visible',
    );
  }

  /// Project folders (not index.json) currently on disk.
  Future<List<String>> projectDirs() async {
    final dir = Directory(paths.projectsDir);
    if (!await dir.exists()) return const [];
    return [
      await for (final e in dir.list())
        if (e is Directory) p.basename(e.path),
    ];
  }

  Future<Map<String, dynamic>> readProjectJson(String id) async =>
      jsonDecode(await File(paths.projectJson(id)).readAsString())
          as Map<String, dynamic>;

  static List<int> beatSamplesOf(Map<String, dynamic> json) => [
    for (final b in json['beats'] as List) (b as Map)['sample'] as int,
  ];
}

/// Nearest-neighbour match of [detected] to [truth]: per truth beat, the
/// signed offset (detected − truth) of the closest detection.
List<int> signedOffsets(List<int> detected, List<int> truth) => [
  for (final t in truth)
    detected.reduce((a, b) => (a - t).abs() <= (b - t).abs() ? a : b) - t,
];

bool bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
