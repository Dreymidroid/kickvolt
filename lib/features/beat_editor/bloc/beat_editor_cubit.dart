import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/audio_math/click_synth.dart';
import '../../../core/audio_math/pcm_window_loader.dart';
import '../../../core/audio_math/peaks.dart';
import '../../../core/di/locator.dart';
import '../../../core/haptics/haptics.dart';
import '../../beat_detection/beat_detection.dart';
import '../../click_preview/click_preview.dart';
import '../../playback/playback.dart';
import '../../projects/projects.dart';
import '../../settings/settings.dart';
import '../domain/command_stack.dart';
import '../domain/edit_command.dart';
import '../domain/playhead_pass.dart';
import '../domain/section_ops.dart';

part 'beat_editor_cubit.freezed.dart';
part 'beat_editor_state.dart';

/// Pixels per second at 1x zoom. 4x (the default) = 51.2 px/s, which puts
/// beats 24 px apart at 128 BPM, as in the design.
const double kPxPerSecondAt1x = 12.8;

/// Horizontal spacing of waveform bars, in pixels. Also the column width
/// used to pick a peak level.
const double kWaveBarStep = 3;

/// No-op haptics fallback when [Haptics] is not registered in lightweight tests.
class _NoopHaptics implements Haptics {
  const _NoopHaptics();

  @override
  Future<void> heavyImpact() async {}

  @override
  Future<void> lightImpact() async {}

  @override
  Future<void> selectionClick() async {}

  @override
  Future<void> successNotification() async {}

  @override
  Future<void> warningNotification() async {}
}

class BeatEditorCubit extends Cubit<BeatEditorState> {
  BeatEditorCubit({
    ProjectRepository? repository,
    BeatDetectionRepository? detectionRepository,
    ClickPreviewRepository? clickPreviewRepository,
    SettingsRepository? settingsRepository,
    OutputRouteService? outputRouteService,
    Haptics? haptics,
    this._playback,
    this.saveDebounce = const Duration(milliseconds: 500),
    this.clickPreviewDebounce = const Duration(milliseconds: 300),
    DateTime Function()? clock,
    this._nowUs,
  }) : _repository = repository ?? locator<ProjectRepository>(),
       _detectionRepository =
           detectionRepository ??
           (locator.isRegistered<BeatDetectionRepository>()
               ? locator<BeatDetectionRepository>()
               : null),
       _clickPreview =
           clickPreviewRepository ??
           (locator.isRegistered<ClickPreviewRepository>()
               ? locator<ClickPreviewRepository>()
               : null),
       _settings =
           settingsRepository ??
           (locator.isRegistered<SettingsRepository>()
               ? locator<SettingsRepository>()
               : null),
       _outputRoute =
           outputRouteService ??
           (locator.isRegistered<OutputRouteService>()
               ? locator<OutputRouteService>()
               : null),
       _haptics =
           haptics ??
           (locator.isRegistered<Haptics>()
               ? locator<Haptics>()
               : const _NoopHaptics()),
       _clock = clock ?? DateTime.now,
       super(const BeatEditorState.loading());

  final ProjectRepository _repository;
  final BeatDetectionRepository? _detectionRepository;
  final ClickPreviewRepository? _clickPreview;
  final SettingsRepository? _settings;
  final OutputRouteService? _outputRoute;
  final Haptics _haptics;
  final Duration saveDebounce;
  final Duration clickPreviewDebounce;
  final DateTime Function() _clock;
  final int Function()? _nowUs;
  AudioPlayback? _playback;

  final CommandStack _commandStack = CommandStack();

  PlayheadController? _playhead;
  final _idlePlayhead = ValueNotifier<int>(0);
  final ValueNotifier<double> _zoom = ValueNotifier(4);
  PcmWindowLoader? _pcmWindow;
  double _viewportWidth = 0;
  bool _resumeAfterScrub = false;
  bool _closing = false;

  String? _projectId;
  String? _songPath;
  String? _activePreviewPath;
  Timer? _previewDebounceTimer;

  /// Visible beats for playback haptics, cached per [Project] instance.
  Project? _hapticsProject;
  List<int> _hapticsVisible = const [];
  ClickPreviewCancelToken? _previewCancelToken;

  StreamSubscription<OutputKind>? _routeSub;
  int _lastPlayheadSample = 0;

  BeatAnalysis? _cachedAnalysis;
  DetectionResult? _lastPreviewResult;
  AnalysisCancelToken? _analysisCancelToken;

  Timer? _saveTimer;
  Project? _pendingSaveProject;
  Future<void> _saveQueue = Future.value();

  /// Narrowest view: about 20 ms of audio across the screen.
  static const _minVisibleSeconds = 0.02;

  /// The playhead as a sample index. Updates every frame while playing;
  /// listen with `CustomPainter(repaint: ...)` or a `ValueListenableBuilder`.
  ValueListenable<int> get playhead => _playhead?.sample ?? _idlePlayhead;

  int get playheadSample => playhead.value;

  /// Exact extrapolated sample position at the moment of the call (used on
  /// pointer-down for tap-to-mark).
  int get playheadSampleNow => _playhead?.sampleNow() ?? playheadSample;

  /// Zoom factor over [kPxPerSecondAt1x]. Changes every frame while pinching.
  ValueListenable<double> get zoom => _zoom;

  /// Raw-sample reader for deep zoom, or null if unavailable.
  PcmWindowLoader? get pcmWindow => _pcmWindow;

  /// Widest view: the whole song across the screen.
  double get minZoom {
    final s = _ready;
    if (s == null || _viewportWidth <= 0 || s.project.sampleCount <= 0) {
      return 0.05;
    }
    final seconds = s.project.sampleCount / s.project.sampleRate;
    return math.min(_viewportWidth / (seconds * kPxPerSecondAt1x), maxZoom);
  }

  double get maxZoom {
    final width = _viewportWidth > 0 ? _viewportWidth : 390;
    return width / (_minVisibleSeconds * kPxPerSecondAt1x);
  }

  /// Pixels per sample at the current zoom.
  double get pxPerSample {
    final s = _ready;
    final rate = s == null ? 44100 : math.max(1, s.project.sampleRate);
    return _zoom.value * kPxPerSecondAt1x / rate;
  }

  int get _lastFrame {
    final s = _ready;
    return s == null ? 0 : math.max(0, s.project.sampleCount - 1);
  }

  BeatEditorReady? get _ready => switch (state) {
    final BeatEditorReady s => s,
    _ => null,
  };

  Future<void> load(String projectId, {int initialPlayheadSample = 0}) async {
    emit(const BeatEditorState.loading());
    _projectId = projectId;
    _commandStack.clear();
    unawaited(_clickPreview?.cleanUpProject(projectId));

    try {
      final project = await _repository.getProject(projectId);
      PeakPyramid peaks;
      try {
        peaks = await _repository.getPeaks(projectId);
      } catch (e) {
        debugPrint('Editor: no peaks for $projectId: $e');
        peaks = PeakPyramid.empty;
      }
      if (isClosed) return;

      final settings = _settings != null
          ? await _settings.load()
          : const AppSettings();
      final outputKind = _outputRoute != null
          ? await _outputRoute.currentOutputKind()
          : OutputKind.unknown;
      final reportedLatency = _outputRoute != null
          ? await _outputRoute.reportedOutputLatency()
          : null;
      if (isClosed) return;

      final effectiveLatencyMs = _resolveLatencyOffsetMs(
        settings: settings,
        reportedOutputLatency: reportedLatency,
      );

      final playback = _playback ??= locator<AudioPlayback>();
      final playhead = PlayheadController(
        playback: playback,
        sampleRate: math.max(1, project.sampleRate),
        sampleCount: project.sampleCount,
        nowUs: _nowUs,
        onPlayingChanged: _onPlayingChanged,
      );
      _playhead = playhead;
      final songPath = await _repository.songPath(projectId);
      _songPath = songPath;

      var unavailable = false;
      try {
        await playhead.open(songPath);
      } catch (e) {
        debugPrint('Editor: playback unavailable: $e');
        unavailable = true;
      }
      try {
        _pcmWindow = await _repository.openPcmWindow(projectId);
      } catch (_) {
        _pcmWindow = null; // deep zoom falls back to the finest peak level
      }
      if (isClosed) return;

      _routeSub = _outputRoute?.outputKindStream.listen((nextKind) {
        final cur = _ready;
        if (!isClosed && cur != null && cur.outputKind != nextKind) {
          emit(cur.copyWith(outputKind: nextKind));
        }
      });

      final showFailed = project.detection.status == DetectionStatus.failed;
      emit(
        BeatEditorState.ready(
          project: project,
          peaks: peaks,
          snap: project.bpm != null,
          playbackUnavailable: unavailable,
          latencyOffsetMs: effectiveLatencyMs,
          latencyCalibratedOn: settings.latencyCalibratedOn,
          outputKind: outputKind,
          activeSheet: showFailed ? EditorSheet.detectFailed : EditorSheet.none,
          previewSensitivity: project.detection.sensitivity,
          previewFilter: project.detection.filter,
        ),
      );
      _lastPlayheadSample = initialPlayheadSample;
      _zoom.addListener(_ensureRawWindow);
      playhead.sample.addListener(_onPlayheadChanged);
      if (initialPlayheadSample > 0) _moveTo(initialPlayheadSample);
    } on ProjectException catch (e) {
      if (!isClosed) emit(BeatEditorState.error(error: e.message));
    } catch (e) {
      if (!isClosed) emit(BeatEditorState.error(error: e.toString()));
    }
  }

  /// Resolves the effective latency offset (§6.3):
  /// - Once calibrated (`latencyCalibratedOn != null`), use the
  ///   calibrated value directly (do NOT add platform latency on top).
  /// - Before calibration, use iOS reported output latency rounded to ms if
  ///   available, else 0.
  int _resolveLatencyOffsetMs({
    required AppSettings settings,
    required Duration? reportedOutputLatency,
  }) {
    if (settings.latencyCalibratedOn != null) {
      return settings.latencyOffsetMs;
    }
    if (reportedOutputLatency != null) {
      return (reportedOutputLatency.inMicroseconds / 1000.0).round().clamp(
        kLatencyOffsetMinMs,
        kLatencyOffsetMaxMs,
      );
    }
    return settings.latencyOffsetMs;
  }

  /// Reloads settings and output route (e.g. after returning from calibration).
  Future<void> refreshSettings() async {
    final s = _ready;
    if (s == null || isClosed) return;
    final settings = _settings != null
        ? await _settings.load()
        : const AppSettings();
    final outputKind = _outputRoute != null
        ? await _outputRoute.currentOutputKind()
        : s.outputKind;
    final reported = _outputRoute != null
        ? await _outputRoute.reportedOutputLatency()
        : null;
    final latest = _ready;
    if (isClosed || latest == null) return;
    emit(
      latest.copyWith(
        latencyOffsetMs: _resolveLatencyOffsetMs(
          settings: settings,
          reportedOutputLatency: reported,
        ),
        latencyCalibratedOn: settings.latencyCalibratedOn,
        outputKind: outputKind,
      ),
    );
  }

  void _onPlayheadChanged() {
    _ensureRawWindow();
    final s = _ready;
    final curr = playheadSample;
    final prev = _lastPlayheadSample;
    _lastPlayheadSample = curr;
    if (s == null || isClosed) return;

    if (!s.playing) return;
    // Recompute the filtered beat list only when the project changes, not on
    // every display frame.
    if (!identical(_hapticsProject, s.project)) {
      _hapticsProject = s.project;
      _hapticsVisible = visibleBeatIndices(s.project);
    }
    final haptics = detectPassedBeatHaptics(
      project: s.project,
      previousSample: prev,
      currentSample: curr,
      playing: s.playing,
      clicksEnabled: s.clicks,
      visibleIndices: _hapticsVisible,
    );
    for (final h in haptics) {
      switch (h) {
        case BeatPassHaptic.light:
          unawaited(_haptics.lightImpact());
        case BeatPassHaptic.heavy:
          unawaited(_haptics.heavyImpact());
      }
    }
  }

  void _onPlayingChanged(bool playing) {
    final s = _ready;
    if (s == null || isClosed) return;
    if (!playing && s.tapRunBeats.isNotEmpty) {
      commitTapRun();
    }
    final latest = _ready;
    if (latest != null && !isClosed && latest.playing != playing) {
      emit(latest.copyWith(playing: playing));
    }
  }

  /// Moves the playhead (and the audio, if it can play).
  void _moveTo(int sample) {
    final p = _playhead;
    if (p == null) return;
    final s = _ready;
    if (s == null || s.playbackUnavailable) {
      p.scrub(sample);
    } else {
      unawaited(p.seek(sample));
    }
  }

  /// Width of the waveform view in logical pixels; sets the zoom limits.
  void setViewportWidth(double width) {
    if (width <= 0 || width == _viewportWidth) return;
    _viewportWidth = width;
    setZoom(_zoom.value);
    _ensureRawWindow();
  }

  /// Loads exact samples when zoomed in past the finest peak level.
  void _ensureRawWindow() {
    final w = _pcmWindow;
    if (w == null || _ready == null || _viewportWidth <= 0) return;
    final framesPerBar = kWaveBarStep / pxPerSample;
    if (framesPerBar >= peakLevelFrames.first) return;
    final half = (_viewportWidth / 2 / pxPerSample).ceil();
    w.ensure(playheadSample - half, playheadSample + half);
  }

  void seekTo(int sample) {
    if (_ready == null) return;
    _moveTo(sample.clamp(0, _lastFrame));
  }

  /// Seeks relative to the current playhead by [deltaMs] milliseconds,
  /// converted to sample frames.
  void seekBy(int deltaMs) {
    final s = _ready;
    if (s == null) return;
    seekTo(playheadSample + s.project.msToSamples(deltaMs));
  }

  void setZoom(double zoom) {
    _zoom.value = zoom.clamp(minZoom, maxZoom);
  }

  /// Finger down on the waveform: pause so the audio doesn't fight the drag.
  void scrubStart() {
    final s = _ready;
    if (s == null) return;
    _resumeAfterScrub = s.playing;
    if (s.playing) unawaited(_playhead?.pause());
  }

  /// Finger moving: only the visible playhead follows.
  void scrubTo(int sample) => _playhead?.scrub(sample.clamp(0, _lastFrame));

  /// Finger up: move the audio there and resume if it was playing.
  Future<void> scrubEnd() async {
    final p = _playhead;
    final s = _ready;
    if (p == null || s == null) return;
    final resume = _resumeAfterScrub;
    _resumeAfterScrub = false;
    if (!s.playbackUnavailable) await p.seek(playheadSample);
    if (resume && !isClosed) await p.play();
  }

  void setSpeed(double speed) {
    final s = _ready;
    if (s == null) return;
    emit(s.copyWith(speed: speed));
    if (!s.playbackUnavailable) unawaited(_playhead?.setSpeed(speed));
  }

  void toggleSnap() {
    final s = _ready;
    if (s == null || s.project.bpm == null) return;
    emit(s.copyWith(snap: !s.snap));
  }

  void toggleClicks() {
    final s = _ready;
    if (s == null) return;
    if (!s.clicks) {
      emit(s.copyWith(clicks: true));
      if (_clickPreview != null && !s.playbackUnavailable) {
        unawaited(_renderClickPreview());
      }
    } else {
      _previewDebounceTimer?.cancel();
      _previewDebounceTimer = null;
      unawaited(_previewCancelToken?.cancel());
      _previewCancelToken = null;
      emit(s.copyWith(clicks: false, updatingClicks: false));
      unawaited(_swapBackToSong());
    }
  }

  void _scheduleClickPreviewRender() {
    final s = _ready;
    if (s == null ||
        !s.clicks ||
        _clickPreview == null ||
        s.playbackUnavailable) {
      return;
    }
    _previewDebounceTimer?.cancel();
    unawaited(_previewCancelToken?.cancel());
    _previewCancelToken = null;
    _previewDebounceTimer = Timer(clickPreviewDebounce, () {
      if (!isClosed) unawaited(_renderClickPreview());
    });
  }

  Future<void> _renderClickPreview() async {
    final previewRepo = _clickPreview;
    final s = _ready;
    if (previewRepo == null || s == null || !s.clicks || isClosed) return;

    _previewDebounceTimer?.cancel();
    _previewDebounceTimer = null;
    await _previewCancelToken?.cancel();

    final token = ClickPreviewCancelToken();
    _previewCancelToken = token;

    final before = _ready;
    if (before == null || !before.clicks || isClosed) return;
    emit(before.copyWith(updatingClicks: true));

    try {
      final path = await previewRepo.render(
        before.project,
        style: ClickStyle.snap,
        cancel: token,
      );
      if (isClosed || token.isCancelled || _ready?.clicks != true) {
        unawaited(previewRepo.deleteFile(path));
        return;
      }

      final latest = _ready!;
      final oldPreview = _activePreviewPath;
      if (!latest.playbackUnavailable) {
        await _playhead?.swapSource(
          path,
          speed: latest.speed,
          wasPlaying: latest.playing,
        );
      }
      _activePreviewPath = path;
      if (oldPreview != null && oldPreview != path) {
        unawaited(previewRepo.deleteFile(oldPreview));
      }
      if (!isClosed && _ready != null) {
        emit(_ready!.copyWith(updatingClicks: false));
      }
    } on ClickPreviewCancelledException {
      if (!isClosed && _ready != null && _previewCancelToken == token) {
        emit(_ready!.copyWith(updatingClicks: false));
      }
    } catch (e) {
      debugPrint('Click preview render failed: $e');
      if (!isClosed && _ready != null) {
        emit(
          _ready!.copyWith(
            clicks: false,
            updatingClicks: false,
            infoMessage: 'Could not render click preview',
          ),
        );
        await _swapBackToSong();
      }
    } finally {
      if (_previewCancelToken == token) {
        _previewCancelToken = null;
      }
    }
  }

  Future<void> _swapBackToSong() async {
    final oldPreview = _activePreviewPath;
    _activePreviewPath = null;
    final songPath = _songPath;
    final s = _ready;
    if (oldPreview != null &&
        songPath != null &&
        s != null &&
        !s.playbackUnavailable) {
      try {
        await _playhead?.swapSource(
          songPath,
          speed: s.speed,
          wasPlaying: s.playing,
        );
      } catch (e) {
        debugPrint('Swap back to song failed: $e');
      }
      unawaited(_clickPreview?.deleteFile(oldPreview));
    }
  }

  void selectTool(EditorTool tool) {
    final s = _ready;
    if (s == null) return;
    if (s.tool == EditorTool.tap &&
        tool != EditorTool.tap &&
        s.tapRunBeats.isNotEmpty) {
      commitTapRun();
    }
    final cur = _ready;
    if (cur == null) return;

    if (tool == EditorTool.auto) {
      unawaited(openAutoDetectSheet());
      return;
    }

    int? rangeStart = cur.bulkRangeStart;
    int? rangeEnd = cur.bulkRangeEnd;
    if (tool == EditorTool.bulk && (rangeStart == null || rangeEnd == null)) {
      final (defStart, defEnd) = _defaultBulkRange();
      rangeStart = defStart;
      rangeEnd = defEnd;
    }

    // The marker inspector only exists on the Edit tab.
    emit(
      cur.copyWith(
        tool: tool,
        selectedIndex: tool == EditorTool.edit ? cur.selectedIndex : null,
        bulkRangeStart: rangeStart,
        bulkRangeEnd: rangeEnd,
      ),
    );
  }

  /// Default Bulk range: the middle half of the visible viewport (§7.4).
  (int, int) _defaultBulkRange() {
    final width = _viewportWidth > 0 ? _viewportWidth : 390.0;
    final halfVisible = (width / 2 / pxPerSample).round();
    final quarterVisible = math.max(1, halfVisible ~/ 2);
    final start = (playheadSample - quarterVisible).clamp(0, _lastFrame);
    final end = (playheadSample + quarterVisible).clamp(start, _lastFrame);
    return (start, end);
  }

  // ---------------------------------------------------------------------------
  // Auto-detect sheet & No-steady-beat sheet (§6.2)
  // ---------------------------------------------------------------------------

  Future<void> openAutoDetectSheet({double? initialSensitivity}) async {
    final s = _ready;
    if (s == null) return;

    final sens = (initialSensitivity ?? s.project.detection.sensitivity).clamp(
      0.0,
      1.0,
    );
    final filter = s.project.detection.filter;

    emit(
      s.copyWith(
        tool: EditorTool.auto,
        selectedIndex: null,
        activeSheet: EditorSheet.autoDetect,
        previewSensitivity: sens,
        previewFilter: filter,
        infoMessage: null,
      ),
    );

    final analysis = await _ensureAnalysis(s.project.id);
    if (isClosed || analysis == null) return;

    final cur = _ready;
    if (cur == null || cur.activeSheet != EditorSheet.autoDetect) return;
    _applyPreview(cur, analysis, cur.previewSensitivity, cur.previewFilter);
  }

  Future<BeatAnalysis?> _ensureAnalysis(String projectId) async {
    if (_cachedAnalysis != null) return _cachedAnalysis;
    final detector = _detectionRepository;
    if (detector == null) return null;

    final diskCached = await detector.getCachedAnalysis(projectId);
    if (diskCached != null) {
      _cachedAnalysis = diskCached;
      return diskCached;
    }

    final cur = _ready;
    if (cur == null || isClosed) return null;

    final token = AnalysisCancelToken();
    _analysisCancelToken = token;
    emit(cur.copyWith(analyzing: true, analysisProgress: 0.0));

    try {
      final result = await detector.analyze(
        projectId,
        cancelToken: token,
        onProgress: (p) {
          final latest = _ready;
          if (!isClosed && latest != null && latest.analyzing) {
            emit(latest.copyWith(analysisProgress: p.fraction));
          }
        },
      );
      _analysisCancelToken = null;
      _cachedAnalysis = result;
      final latest = _ready;
      if (!isClosed && latest != null) {
        emit(latest.copyWith(analyzing: false, analysisProgress: 1.0));
      }
      return result;
    } on AnalysisCancelledException {
      _analysisCancelToken = null;
      final latest = _ready;
      if (!isClosed && latest != null) {
        emit(
          latest.copyWith(
            analyzing: false,
            analysisProgress: 0.0,
            activeSheet: EditorSheet.none,
            tool: EditorTool.edit,
            previewBeats: null,
            previewBpm: null,
            previewSections: null,
          ),
        );
      }
      return null;
    } catch (e) {
      _analysisCancelToken = null;
      final latest = _ready;
      if (!isClosed && latest != null) {
        emit(
          latest.copyWith(
            analyzing: false,
            analysisProgress: 0.0,
            activeSheet: EditorSheet.none,
            tool: EditorTool.edit,
            infoMessage: 'Could not analyze audio: $e',
          ),
        );
      }
      return null;
    }
  }

  Future<void> cancelAnalysis() async {
    await _analysisCancelToken?.cancel();
  }

  void setPreviewSensitivity(double sensitivity) {
    final s = _ready;
    if (s == null || s.activeSheet != EditorSheet.autoDetect) return;
    final clamped = sensitivity.clamp(0.0, 1.0);
    final analysis = _cachedAnalysis;
    if (analysis == null) {
      emit(s.copyWith(previewSensitivity: clamped));
      return;
    }
    _applyPreview(s, analysis, clamped, s.previewFilter);
  }

  void setPreviewFilter(BeatFilter filter) {
    final s = _ready;
    if (s == null || s.activeSheet != EditorSheet.autoDetect) return;
    emit(s.copyWith(previewFilter: filter));
  }

  void _applyPreview(
    BeatEditorReady s,
    BeatAnalysis analysis,
    double sensitivity,
    BeatFilter filter,
  ) {
    final detector = _detectionRepository;
    final result = detector != null
        ? detector.classify(analysis, sensitivity)
        : classifyBeats(analysis, sensitivity: sensitivity);
    _lastPreviewResult = result;
    emit(
      s.copyWith(
        analyzing: false,
        previewSensitivity: sensitivity,
        previewFilter: filter,
        previewBeats: result.beats,
        previewBpm: result.bpm,
        previewSections: result.sections,
        previewSucceeded: result.succeeded,
      ),
    );
  }

  void closeSheet() {
    unawaited(_analysisCancelToken?.cancel());
    final s = _ready;
    if (s == null) return;
    emit(
      s.copyWith(
        activeSheet: EditorSheet.none,
        tool: s.tool == EditorTool.auto ? EditorTool.edit : s.tool,
        analyzing: false,
        previewBeats: null,
        previewBpm: null,
        previewSections: null,
        previewSucceeded: true,
        infoMessage: null,
      ),
    );
  }

  /// Commits the current Auto-detect preview via [ReplaceAll] on the command
  /// stack so undo restores beats, sections, bpm, beatPhaseSample and detection.
  void commitAutoDetect() {
    final s = _ready;
    if (s == null || s.activeSheet != EditorSheet.autoDetect) return;
    final analysis = _cachedAnalysis;
    if (analysis == null) return;

    final result =
        _lastPreviewResult ??
        (_detectionRepository != null
            ? _detectionRepository.classify(analysis, s.previewSensitivity)
            : classifyBeats(analysis, sensitivity: s.previewSensitivity));

    if (!result.succeeded) {
      final updatedProject = s.project.copyWith(
        detection: s.project.detection.copyWith(
          sensitivity: s.previewSensitivity,
          filter: s.previewFilter,
          status: DetectionStatus.failed,
        ),
      );
      emit(
        s.copyWith(
          project: updatedProject,
          activeSheet: EditorSheet.detectFailed,
          tool: EditorTool.edit,
          previewBeats: null,
          previewBpm: null,
          previewSections: null,
          previewSucceeded: false,
        ),
      );
      _scheduleSave(updatedProject);
      return;
    }

    final cmd = ReplaceAll(
      oldBeats: s.project.beats,
      newBeats: result.beats,
      oldSections: s.project.sections,
      newSections: result.sections,
      oldBpm: s.project.bpm,
      newBpm: result.bpm,
      oldBeatPhaseSample: s.project.beatPhaseSample,
      newBeatPhaseSample: result.beatPhaseSample,
      oldDetection: s.project.detection,
      newDetection: s.project.detection.copyWith(
        sensitivity: s.previewSensitivity,
        filter: s.previewFilter,
        status: DetectionStatus.succeeded,
      ),
    );
    _execute(
      cmd,
      transformState: (next) => next.copyWith(
        snap: next.project.bpm != null,
        activeSheet: EditorSheet.none,
        tool: EditorTool.edit,
        previewBeats: null,
        previewBpm: null,
        previewSections: null,
        previewSucceeded: true,
      ),
    );
    unawaited(_haptics.successNotification());
  }

  void tapBeatsFromFailedSheet() {
    final s = _ready;
    if (s == null) return;
    emit(
      s.copyWith(
        activeSheet: EditorSheet.none,
        tool: EditorTool.tap,
        selectedIndex: null,
        previewBeats: null,
        previewBpm: null,
        previewSections: null,
      ),
    );
  }

  Future<void> detectWithMoreSensitivity() async {
    final s = _ready;
    if (s == null) return;
    final nextSens = (s.project.detection.sensitivity + 0.25).clamp(0.0, 1.0);
    await openAutoDetectSheet(initialSensitivity: nextSens);
  }

  Future<void> markDropsOnly() async {
    final s = _ready;
    if (s == null) return;

    final analysis = await _ensureAnalysis(s.project.id);
    if (isClosed) return;
    final cur = _ready;
    if (cur == null) return;

    final List<Beat> drops;
    if (analysis == null) {
      drops = const <Beat>[];
    } else {
      final res = _detectionRepository != null
          ? _detectionRepository.classify(
              analysis,
              cur.project.detection.sensitivity,
            )
          : classifyBeats(
              analysis,
              sensitivity: cur.project.detection.sensitivity,
            );
      drops = res.succeeded
          ? res.beats.where((b) => b.type == BeatType.drop).toList()
          : res.fallbackDrops;
    }

    if (drops.isEmpty) {
      emit(
        cur.copyWith(
          activeSheet: EditorSheet.none,
          tool: EditorTool.edit,
          infoMessage: 'No drops were found in this song',
        ),
      );
      return;
    }

    final cmd = ReplaceAll(
      oldBeats: cur.project.beats,
      newBeats: drops,
      oldSections: cur.project.sections,
      newSections: cur.project.sections,
      oldBpm: cur.project.bpm,
      newBpm: cur.project.bpm,
      oldBeatPhaseSample: cur.project.beatPhaseSample,
      newBeatPhaseSample: cur.project.beatPhaseSample,
      oldDetection: cur.project.detection,
      newDetection: cur.project.detection.copyWith(
        filter: BeatFilter.drops,
        status: DetectionStatus.succeeded,
      ),
    );
    _execute(
      cmd,
      transformState: (next) => next.copyWith(
        activeSheet: EditorSheet.none,
        tool: EditorTool.edit,
        infoMessage: null,
      ),
    );
    unawaited(_haptics.successNotification());
  }

  /// Changes the project's view-only [BeatFilter] without deleting any beats.
  void setFilter(BeatFilter filter) {
    final s = _ready;
    if (s == null || s.project.detection.filter == filter) return;
    final updatedProject = s.project.copyWith(
      detection: s.project.detection.copyWith(filter: filter),
    );
    var nextSelected = s.selectedIndex;
    if (nextSelected != null) {
      final visible = visibleBeatIndices(updatedProject);
      if (!visible.contains(nextSelected)) {
        nextSelected = null;
      }
    }
    emit(s.copyWith(project: updatedProject, selectedIndex: nextSelected));
    _scheduleSave(updatedProject);
    _scheduleClickPreviewRender();
  }

  void clearInfoMessage() {
    final s = _ready;
    if (s != null && s.infoMessage != null) {
      emit(s.copyWith(infoMessage: null));
    }
  }

  // ---------------------------------------------------------------------------
  // Beat editing (Edit tab)
  // ---------------------------------------------------------------------------

  void selectBeat(int? index) {
    final s = _ready;
    if (s == null) return;
    final beats = s.project.beats;
    if (index == null || index < 0 || index >= beats.length) {
      if (s.selectedIndex != null) emit(s.copyWith(selectedIndex: null));
      return;
    }
    emit(s.copyWith(selectedIndex: index));
    _moveTo(beats[index].sample);
    unawaited(_haptics.selectionClick());
  }

  void nudgeSelected(int deltaMs) {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    final beats = s.project.beats;
    if (i < 0 || i >= beats.length) return;

    final deltaFrames = s.project.msToSamples(deltaMs);
    if (deltaFrames == 0) return;

    final lo = i > 0 ? beats[i - 1].sample + 1 : 0;
    final hi = i < beats.length - 1 ? beats[i + 1].sample - 1 : _lastFrame;
    if (lo > hi) return;
    final target = (beats[i].sample + deltaFrames).clamp(lo, hi);
    if (target == beats[i].sample) return;

    _execute(
      MoveBeat(index: i, fromSample: beats[i].sample, toSample: target),
      playheadSample: target,
    );
    unawaited(_haptics.selectionClick());
  }

  void setSelectedType(BeatType type) {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    if (i < 0 || i >= s.project.beats.length) return;
    if (s.project.beats[i].type == type) return;
    _execute(
      SetBeatType(index: i, oldType: s.project.beats[i].type, newType: type),
    );
    unawaited(_haptics.selectionClick());
  }

  void deleteSelected() {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    if (i < 0 || i >= s.project.beats.length) return;
    _execute(DeleteBeat(index: i, beat: s.project.beats[i]));
    unawaited(_haptics.warningNotification());
  }

  void togglePlay() {
    final s = _ready;
    final p = _playhead;
    if (s == null || p == null || s.playbackUnavailable) return;
    if (s.playing) {
      if (s.tapRunBeats.isNotEmpty) commitTapRun();
      unawaited(p.pause());
    } else {
      // Show the pause button at once; the player confirms shortly after.
      emit(s.copyWith(playing: true));
      unawaited(p.play());
    }
  }

  void addBeatAtPlayhead() => addBeatAtSample(playheadSample);

  /// Adds a beat at [sample] (used by "Add at playhead" and waveform long-press),
  /// snapping if Snap is on, refusing duplicates within 20 ms, and selecting it.
  void addBeatAtSample(int sample) {
    final s = _ready;
    if (s == null) return;
    var target = sample;
    final bpm = s.project.bpm;
    if (s.snap && bpm != null && bpm > 0) {
      target = snapSampleToGrid(
        sample: target,
        sampleRate: s.project.sampleRate,
        sampleCount: s.project.sampleCount,
        bpm: bpm,
        beatPhaseSample: s.project.beatPhaseSample,
      );
    }
    target = target.clamp(0, _lastFrame);
    final minGapFrames = s.project.msToSamples(20);
    if (s.project.beats.any((b) => (b.sample - target).abs() < minGapFrames)) {
      return;
    }
    _execute(
      AddBeats([Beat(sample: target)], selectSample: target),
      transformState: (next) => next.copyWith(tool: EditorTool.edit),
    );
    unawaited(_haptics.selectionClick());
  }

  // ---------------------------------------------------------------------------
  // Tap tab (§7.3)
  // ---------------------------------------------------------------------------

  /// Marks a beat at pointer-down (`sampleNow() - msToSamples(latencyOffsetMs)`).
  /// Accumulated into [BeatEditorReady.tapRunBeats] until pause/tab-leave/close.
  void tapBeat() {
    final s = _ready;
    if (s == null || s.tool != EditorTool.tap || !s.playing) return;

    final raw = playheadSampleNow;
    var target = raw - s.project.msToSamples(s.latencyOffsetMs);
    final bpm = s.project.bpm;
    if (s.snap && bpm != null && bpm > 0) {
      target = snapSampleToGrid(
        sample: target,
        sampleRate: s.project.sampleRate,
        sampleCount: s.project.sampleCount,
        bpm: bpm,
        beatPhaseSample: s.project.beatPhaseSample,
      );
    }
    target = target.clamp(0, _lastFrame);

    final minGapFrames = s.project.msToSamples(20);
    if (s.project.beats.any((b) => (b.sample - target).abs() < minGapFrames) ||
        s.tapRunBeats.any((b) => (b.sample - target).abs() < minGapFrames)) {
      return;
    }

    final nextRun = [...s.tapRunBeats, Beat(sample: target)]
      ..sort((a, b) => a.sample.compareTo(b.sample));
    emit(s.copyWith(tapRunBeats: nextRun));
    unawaited(_haptics.selectionClick());
  }

  /// Commits all beats tapped in the current play-to-pause run as ONE
  /// [AddBeats] command on the command stack.
  void commitTapRun() {
    final s = _ready;
    if (s == null || s.tapRunBeats.isEmpty) return;
    final run = s.tapRunBeats;
    _execute(
      AddBeats(run),
      transformState: (next) => next.copyWith(tapRunBeats: const []),
    );
  }

  // ---------------------------------------------------------------------------
  // Bulk tab (§7.4)
  // ---------------------------------------------------------------------------

  void setBulkRange(int startSample, int endSample, {bool applySnap = true}) {
    final s = _ready;
    if (s == null) return;
    var start = startSample;
    var end = endSample;
    final bpm = s.project.bpm;
    if (applySnap && s.snap && bpm != null && bpm > 0) {
      start = snapSampleToGrid(
        sample: start,
        sampleRate: s.project.sampleRate,
        sampleCount: s.project.sampleCount,
        bpm: bpm,
        beatPhaseSample: s.project.beatPhaseSample,
      );
      end = snapSampleToGrid(
        sample: end,
        sampleRate: s.project.sampleRate,
        sampleCount: s.project.sampleCount,
        bpm: bpm,
        beatPhaseSample: s.project.beatPhaseSample,
      );
    }
    start = start.clamp(0, _lastFrame);
    end = end.clamp(0, _lastFrame);
    if (start > end) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    if (s.bulkRangeStart == start && s.bulkRangeEnd == end) return;
    emit(s.copyWith(bulkRangeStart: start, bulkRangeEnd: end));
  }

  void clearBulkRange() {
    final s = _ready;
    final start = s?.bulkRangeStart;
    final end = s?.bulkRangeEnd;
    if (s == null || start == null || end == null) return;
    final hasAny = s.project.beats.any(
      (b) => b.sample >= start && b.sample <= end,
    );
    if (!hasAny) return;
    _execute(ClearRange(startSample: start, endSample: end));
    unawaited(_haptics.warningNotification());
  }

  void snapBulkRange() {
    final s = _ready;
    final start = s?.bulkRangeStart;
    final end = s?.bulkRangeEnd;
    if (s == null || start == null || end == null || s.project.bpm == null) {
      return;
    }
    final hasAny = s.project.beats.any(
      (b) => b.sample >= start && b.sample <= end,
    );
    if (!hasAny) return;
    _execute(SnapRange(startSample: start, endSample: end));
    unawaited(_haptics.selectionClick());
  }

  void setBulkShiftMs(int ms) {
    final s = _ready;
    if (s == null) return;
    final clamped = ms.clamp(-500, 500);
    if (s.bulkShiftMs == clamped) return;
    emit(s.copyWith(bulkShiftMs: clamped));
  }

  void adjustBulkShiftMs(int deltaMs) {
    final s = _ready;
    if (s == null) return;
    setBulkShiftMs(s.bulkShiftMs + deltaMs);
  }

  void applyBulkShift() {
    final s = _ready;
    if (s == null || s.bulkShiftMs == 0) return;
    final deltaFrames = s.project.msToSamples(s.bulkShiftMs);
    if (deltaFrames == 0) {
      emit(s.copyWith(bulkShiftMs: 0));
      return;
    }
    _execute(
      ShiftAll(deltaSamples: deltaFrames),
      transformState: (next) => next.copyWith(bulkShiftMs: 0),
    );
    unawaited(_haptics.selectionClick());
  }

  // ---------------------------------------------------------------------------
  // Sections tab (§7.5)
  // ---------------------------------------------------------------------------

  void splitSectionAtPlayhead() {
    final s = _ready;
    if (s == null) return;
    final next = splitSectionAt(
      sections: s.project.sections,
      beats: s.project.beats,
      playheadSample: playheadSample,
      sampleCount: s.project.sampleCount,
    );
    if (next == null) return;
    _execute(SetSections(oldSections: s.project.sections, newSections: next));
    unawaited(_haptics.selectionClick());
  }

  void renameSection(int index, String name) {
    final s = _ready;
    if (s == null) return;
    final next = renameSectionAt(s.project.sections, index, name);
    if (next == null) return;
    _execute(SetSections(oldSections: s.project.sections, newSections: next));
  }

  void recolourSection(int index, int colorArgb) {
    final s = _ready;
    if (s == null) return;
    final next = recolourSectionAt(s.project.sections, index, colorArgb);
    if (next == null) return;
    _execute(SetSections(oldSections: s.project.sections, newSections: next));
  }

  void deleteSection(int index) {
    final s = _ready;
    if (s == null) return;
    final next = deleteSectionAt(s.project.sections, index);
    if (next == null) return;
    _execute(SetSections(oldSections: s.project.sections, newSections: next));
    unawaited(_haptics.warningNotification());
  }

  // ---------------------------------------------------------------------------
  // Command execution, undo, redo (§4.2)
  // ---------------------------------------------------------------------------

  void undo() {
    final s = _ready;
    if (s == null || !_commandStack.canUndo) return;
    final res = _commandStack.undo(s.project);
    if (res == null) return;
    _emitCommandResult(s, res);
  }

  void redo() {
    final s = _ready;
    if (s == null || !_commandStack.canRedo) return;
    final res = _commandStack.redo(s.project);
    if (res == null) return;
    _emitCommandResult(s, res);
  }

  void _execute(
    EditCommand command, {
    int? playheadSample,
    BeatEditorReady Function(BeatEditorReady)? transformState,
  }) {
    final s = _ready;
    if (s == null) return;
    final res = _commandStack.execute(s.project, command, at: _clock());
    _emitCommandResult(
      s,
      res,
      playheadSample: playheadSample,
      transformState: transformState,
    );
  }

  void _emitCommandResult(
    BeatEditorReady s,
    CommandResult res, {
    int? playheadSample,
    BeatEditorReady Function(BeatEditorReady)? transformState,
  }) {
    var next = s.copyWith(
      project: res.project,
      snap: res.project.bpm == null ? false : s.snap,
      canUndo: _commandStack.canUndo,
      canRedo: _commandStack.canRedo,
      selectedIndex: res.selectedIndex,
      saveError: null,
    );
    if (transformState != null) {
      next = transformState(next);
    }
    emit(next);
    if (playheadSample != null) _moveTo(playheadSample);
    _scheduleSave(res.project);
    _scheduleClickPreviewRender();
  }

  // ---------------------------------------------------------------------------
  // Debounced serialized persistence
  // ---------------------------------------------------------------------------

  void _scheduleSave(Project project) {
    _pendingSaveProject = project;
    _saveTimer?.cancel();
    if (saveDebounce == Duration.zero) {
      _saveTimer = null;
      unawaited(_flushPendingSave());
      return;
    }
    _saveTimer = Timer(saveDebounce, _flushPendingSave);
  }

  Future<void> flushPendingSave() => _flushPendingSave();

  Future<void> _flushPendingSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final project = _pendingSaveProject;
    if (project == null) return _saveQueue;
    _pendingSaveProject = null;
    return _saveQueue = _saveQueue.then((_) => _save(project));
  }

  Future<void> _save(Project project) async {
    try {
      await _repository.saveProject(project);
    } on ProjectException catch (e) {
      final cur = _ready;
      if (!isClosed && cur != null) {
        emit(cur.copyWith(saveError: e.message));
      }
    } catch (e) {
      final cur = _ready;
      if (!isClosed && cur != null) {
        emit(cur.copyWith(saveError: e.toString()));
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    // Commit any active tap run before flushing saves (§7.3).
    if (_ready?.tapRunBeats.isNotEmpty == true) {
      commitTapRun();
    }
    _previewDebounceTimer?.cancel();
    _previewDebounceTimer = null;
    await _previewCancelToken?.cancel();
    await _analysisCancelToken?.cancel();
    await _routeSub?.cancel();
    // Waits for any running save as well as the pending one.
    await _flushPendingSave();
    _zoom.removeListener(_ensureRawWindow);
    _playhead?.sample.removeListener(_onPlayheadChanged);
    _pcmWindow?.dispose();
    final p = _playhead;
    if (p != null) {
      await p.dispose();
    } else {
      await _playback?.dispose();
    }
    // Delete preview files AFTER disposing playback so Windows releases handles.
    if (_projectId != null) {
      await _clickPreview?.cleanUpProject(_projectId!);
    }
    _zoom.dispose();
    _idlePlayhead.dispose();
    return super.close();
  }
}
