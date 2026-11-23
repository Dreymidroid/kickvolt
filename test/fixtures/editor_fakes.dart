import 'dart:async';

import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/core/haptics/haptics.dart';
import 'package:kickvolt/features/click_preview/click_preview.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:kickvolt/features/settings/settings.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([AppSettings initial = const AppSettings()])
    : _current = initial;

  AppSettings _current;

  @override
  AppSettings get current => _current;

  @override
  Future<AppSettings> load() async => _current;

  @override
  Future<AppSettings> save(AppSettings settings) async {
    _current = settings;
    return _current;
  }
}

class FakeOutputRouteService implements OutputRouteService {
  FakeOutputRouteService({this.kind = OutputKind.builtIn, this.latency});

  OutputKind kind;
  Duration? latency;
  final _controller = StreamController<OutputKind>.broadcast(sync: true);

  void emitKind(OutputKind next) {
    kind = next;
    _controller.add(next);
  }

  @override
  Future<OutputKind> currentOutputKind() async => kind;

  @override
  Stream<OutputKind> get outputKindStream => _controller.stream;

  @override
  Future<Duration?> reportedOutputLatency() async => latency;

  Future<void> dispose() => _controller.close();
}

class RecordingHaptics implements Haptics {
  RecordingHaptics({this._settings});

  final SettingsRepository? _settings;
  final events = <String>[];

  bool get _enabled => _settings?.current.hapticsEnabled ?? true;

  @override
  Future<void> selectionClick() async {
    if (_enabled) events.add('selectionClick');
  }

  @override
  Future<void> lightImpact() async {
    if (_enabled) events.add('lightImpact');
  }

  @override
  Future<void> heavyImpact() async {
    if (_enabled) events.add('heavyImpact');
  }

  @override
  Future<void> successNotification() async {
    if (_enabled) events.add('successNotification');
  }

  @override
  Future<void> warningNotification() async {
    if (_enabled) events.add('warningNotification');
  }
}

class FakeClickPreviewRequest {
  FakeClickPreviewRequest({
    required this.project,
    required this.style,
    required this.cancel,
    required this.outputPath,
  });

  final Project project;
  final ClickStyle style;
  final ClickPreviewCancelToken cancel;
  final String outputPath;
  final Completer<String> completer = Completer<String>();
}

class FakeClickPreviewRepository implements ClickPreviewRepository {
  int _seq = 0;
  bool autoComplete = true;
  Object? nextError;
  final requests = <FakeClickPreviewRequest>[];
  final deletedFiles = <String>[];
  final cleanedUpProjects = <String>[];

  @override
  Future<String> render(
    Project project, {
    required ClickStyle style,
    required ClickPreviewCancelToken cancel,
  }) async {
    final path = '/fake/projects/${project.id}/preview-${++_seq}.wav';
    final req = FakeClickPreviewRequest(
      project: project,
      style: style,
      cancel: cancel,
      outputPath: path,
    );
    requests.add(req);

    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }

    if (autoComplete) {
      if (cancel.isCancelled) throw const ClickPreviewCancelledException();
      return path;
    }

    final result = await req.completer.future;
    if (cancel.isCancelled) throw const ClickPreviewCancelledException();
    return result;
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedFiles.add(path);
  }

  @override
  Future<void> cleanUpProject(String projectId) async {
    cleanedUpProjects.add(projectId);
  }
}
