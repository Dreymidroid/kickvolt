import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/audio_math/pcm_window_loader.dart';
import '../../../core/audio_math/peaks.dart';
import '../../../core/di/locator.dart';
import '../../beat_detection/beat_detection.dart';
import '../../playback/playback.dart';
import '../../projects/projects.dart';

part 'beat_editor_cubit.freezed.dart';
part 'beat_editor_state.dart';

/// Pixels per second at 1x zoom. 4x (the default) = 51.2 px/s, which puts
/// beats 24 px apart at 128 BPM, as in the design.
const double kPxPerSecondAt1x = 12.8;

/// Horizontal spacing of waveform bars, in pixels. Also the column width
/// used to pick a peak level.
const double kWaveBarStep = 3;

class BeatEditorCubit extends Cubit<BeatEditorState> {
  BeatEditorCubit({
    ProjectRepository? repository,
    BeatDetectionRepository? detectionRepository,
    this._playback,
    this.saveDebounce = const Duration(milliseconds: 500),
  }) : _repository = repository ?? locator<ProjectRepository>(),
       _detectionRepository =
           detectionRepository ??
           (locator.isRegistered<BeatDetectionRepository>()
               ? locator<BeatDetectionRepository>()
               : null),
       super(const BeatEditorState.loading());

  final ProjectRepository _repository;
  final BeatDetectionRepository? _detectionRepository;
  final Duration saveDebounce;
  AudioPlayback? _playback;

  PlayheadController? _playhead;
  final _idlePlayhead = ValueNotifier<int>(0);
  final ValueNotifier<double> _zoom = ValueNotifier(4);
  PcmWindowLoader? _pcmWindow;
  double _viewportWidth = 0;
  bool _resumeAfterScrub = false;
  bool _closing = false;

  BeatAnalysis? _cachedAnalysis;
  DetectionResult? _lastPreviewResult;
  AnalysisCancelToken? _analysisCancelToken;

  DateTime? _lastNudgeAt;
  int? _lastNudgeIndex;

  Timer? _saveTimer;
  Project? _pendingSaveProject;
  Future<void> _saveQueue = Future.value();

  static const _historyLimit = 50;

  /// Narrowest view: about 20 ms of audio across the screen.
  static const _minVisibleSeconds = 0.02;

  /// The playhead as a sample index. Updates every frame while playing;
  /// listen with `CustomPainter(repaint: ...)` or a `ValueListenableBuilder`.
  ValueListenable<int> get playhead => _playhead?.sample ?? _idlePlayhead;

  int get playheadSample => playhead.value;

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

      final playback = _playback ??= locator<AudioPlayback>();
      final playhead = PlayheadController(
        playback: playback,
        sampleRate: math.max(1, project.sampleRate),
        sampleCount: project.sampleCount,
        onPlayingChanged: _onPlayingChanged,
      );
      _playhead = playhead;
      var unavailable = false;
      try {
        await playhead.open(await _repository.songPath(projectId));
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

      final showFailed = project.detection.status == DetectionStatus.failed;
      emit(
        BeatEditorState.ready(
          project: project,
          peaks: peaks,
          snap: project.bpm != null,
          playbackUnavailable: unavailable,
          activeSheet: showFailed ? EditorSheet.detectFailed : EditorSheet.none,
          previewSensitivity: project.detection.sensitivity,
          previewFilter: project.detection.filter,
        ),
      );
      _zoom.addListener(_ensureRawWindow);
      playhead.sample.addListener(_ensureRawWindow);
      if (initialPlayheadSample > 0) _moveTo(initialPlayheadSample);
    } on ProjectException catch (e) {
      if (!isClosed) emit(BeatEditorState.error(error: e.message));
    } catch (e) {
      if (!isClosed) emit(BeatEditorState.error(error: e.toString()));
    }
  }

  void _onPlayingChanged(bool playing) {
    final s = _ready;
    if (s != null && !isClosed && s.playing != playing) {
      emit(s.copyWith(playing: playing));
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
    if (s != null) emit(s.copyWith(clicks: !s.clicks));
  }

  void selectTool(EditorTool tool) {
    final s = _ready;
    if (s == null) return;
    if (tool == EditorTool.auto) {
      unawaited(openAutoDetectSheet());
      return;
    }
    // The marker inspector only exists on the Edit tab.
    emit(
      s.copyWith(
        tool: tool,
        selectedIndex: tool == EditorTool.edit ? s.selectedIndex : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Auto-detect sheet & No-steady-beat sheet (§6.2)
  // ---------------------------------------------------------------------------

  /// Opens the Auto-detect sheet. Uses the cached [BeatAnalysis] if available;
  /// otherwise runs the background isolate with progress and cancel support.
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

  /// Cancels an in-flight analysis inside the Auto-detect sheet.
  Future<void> cancelAnalysis() async {
    await _analysisCancelToken?.cancel();
  }

  /// Updates the sensitivity slider while the Auto-detect sheet is open.
  /// Re-classifies synchronously from the cached analysis (no isolate, no save).
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

  /// Updates the filter chip while the Auto-detect sheet is open (preview only).
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

  /// Closes the Auto-detect or Failed sheet without committing any changes,
  /// restoring the project's existing beats and returning to the Edit tab.
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

  /// Commits the current Auto-detect preview to the project through the normal
  /// undoable commit path (§6.2). If classification failed, opens the
  /// "No steady beat" sheet instead.
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

    _lastNudgeAt = null;
    final undo = [...s.undoStack, s.project.beats];
    final updatedProject = s.project.copyWith(
      beats: result.beats,
      bpm: result.bpm,
      beatPhaseSample: result.beatPhaseSample,
      sections: result.sections,
      detection: s.project.detection.copyWith(
        sensitivity: s.previewSensitivity,
        filter: s.previewFilter,
        status: DetectionStatus.succeeded,
      ),
    );
    emit(
      s.copyWith(
        project: updatedProject,
        snap: updatedProject.bpm != null,
        undoStack: undo.length > _historyLimit
            ? undo.sublist(undo.length - _historyLimit)
            : undo,
        redoStack: const [],
        selectedIndex: null,
        activeSheet: EditorSheet.none,
        tool: EditorTool.edit,
        previewBeats: null,
        previewBpm: null,
        previewSections: null,
        previewSucceeded: true,
        saveError: null,
      ),
    );
    HapticFeedback.mediumImpact();
    _scheduleSave(updatedProject);
  }

  /// Action from "No steady beat" sheet: switch to the Tap tool.
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

  /// Action from "No steady beat" sheet: re-classify with sensitivity +0.25
  /// (capped at 1.0) and open the Auto-detect sheet on the result (§6.2).
  Future<void> detectWithMoreSensitivity() async {
    final s = _ready;
    if (s == null) return;
    final nextSens = (s.project.detection.sensitivity + 0.25).clamp(0.0, 1.0);
    await openAutoDetectSheet(initialSensitivity: nextSens);
  }

  /// Action from "No steady beat" sheet: commit only the drop beats found from
  /// energy alone, or show a SnackBar if none were found (§4.6, §6.2).
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

    _lastNudgeAt = null;
    final undo = [...cur.undoStack, cur.project.beats];
    final updatedProject = cur.project.copyWith(
      beats: drops,
      detection: cur.project.detection.copyWith(
        filter: BeatFilter.drops,
        status: DetectionStatus.succeeded,
      ),
    );
    emit(
      cur.copyWith(
        project: updatedProject,
        undoStack: undo.length > _historyLimit
            ? undo.sublist(undo.length - _historyLimit)
            : undo,
        redoStack: const [],
        selectedIndex: null,
        activeSheet: EditorSheet.none,
        tool: EditorTool.edit,
        saveError: null,
        infoMessage: null,
      ),
    );
    HapticFeedback.mediumImpact();
    _scheduleSave(updatedProject);
  }

  /// Changes the project's view-only [BeatFilter] without deleting any beats.
  void setFilter(BeatFilter filter) {
    final s = _ready;
    if (s == null || s.project.detection.filter == filter) return;
    final updatedProject = s.project.copyWith(
      detection: s.project.detection.copyWith(filter: filter),
    );
    // Clear selection if the currently selected beat is hidden by the new filter.
    var nextSelected = s.selectedIndex;
    if (nextSelected != null) {
      final visible = visibleBeatIndices(updatedProject);
      if (!visible.contains(nextSelected)) {
        nextSelected = null;
      }
    }
    emit(s.copyWith(project: updatedProject, selectedIndex: nextSelected));
    _scheduleSave(updatedProject);
  }

  void clearInfoMessage() {
    final s = _ready;
    if (s != null && s.infoMessage != null) {
      emit(s.copyWith(infoMessage: null));
    }
  }

  // ---------------------------------------------------------------------------
  // Beat editing
  // ---------------------------------------------------------------------------

  /// Selects a marker and centres the playhead on it, or clears the
  /// selection when [index] is null.
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
    HapticFeedback.selectionClick();
  }

  /// Moves the selected marker by [deltaMs] (converted to sample frames),
  /// staying between its neighbours. Taps within a second of each other
  /// share one undo step.
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

    final now = DateTime.now();
    final coalesce =
        _lastNudgeIndex == i &&
        _lastNudgeAt != null &&
        now.difference(_lastNudgeAt!) < const Duration(seconds: 1);
    _lastNudgeIndex = i;
    _lastNudgeAt = now;

    final next = [...beats]..[i] = beats[i].copyWith(sample: target);
    _commit(
      s,
      next,
      selected: i,
      playheadSample: target,
      coalesce: coalesce,
      isNudge: true,
    );
    HapticFeedback.selectionClick();
  }

  void setSelectedType(BeatType type) {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    if (i < 0 || i >= s.project.beats.length) return;
    if (s.project.beats[i].type == type) return;
    final next = [...s.project.beats]
      ..[i] = s.project.beats[i].copyWith(type: type);
    _commit(s, next, selected: i);
    HapticFeedback.selectionClick();
  }

  void deleteSelected() {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    if (i < 0 || i >= s.project.beats.length) return;
    final next = [...s.project.beats]..removeAt(i);
    _commit(s, next, selected: null);
    HapticFeedback.heavyImpact();
  }

  void togglePlay() {
    final s = _ready;
    final p = _playhead;
    if (s == null || p == null || s.playbackUnavailable) return;
    if (s.playing) {
      unawaited(p.pause());
    } else {
      // Show the pause button at once; the player confirms shortly after.
      emit(s.copyWith(playing: true));
      unawaited(p.play());
    }
  }

  void addBeatAtPlayhead() {
    final s = _ready;
    if (s == null) return;
    var sample = playheadSample;
    final bpm = s.project.bpm;
    if (s.snap && bpm != null && bpm > 0) {
      final phase = s.project.beatPhaseSample ?? 0;
      final grid = s.project.sampleRate * 60 / bpm;
      sample = (phase + ((sample - phase) / grid).round() * grid).round();
    }
    sample = sample.clamp(0, _lastFrame);
    final minGapFrames = s.project.msToSamples(20);
    final beats = s.project.beats;
    if (beats.any((b) => (b.sample - sample).abs() < minGapFrames)) return;
    final next = [...beats, Beat(sample: sample)]
      ..sort((a, b) => a.sample.compareTo(b.sample));
    // Select the new marker so it can be fine-tuned straight away.
    _commit(s, next, selected: next.indexWhere((b) => b.sample == sample));
    HapticFeedback.selectionClick();
  }

  void undo() {
    final s = _ready;
    if (s == null || s.undoStack.isEmpty) return;
    _lastNudgeAt = null;
    final updatedProject = s.project.copyWith(beats: s.undoStack.last);
    emit(
      s.copyWith(
        project: updatedProject,
        undoStack: s.undoStack.sublist(0, s.undoStack.length - 1),
        redoStack: [...s.redoStack, s.project.beats],
        selectedIndex: null,
        saveError: null,
      ),
    );
    _scheduleSave(updatedProject);
  }

  void redo() {
    final s = _ready;
    if (s == null || s.redoStack.isEmpty) return;
    _lastNudgeAt = null;
    final updatedProject = s.project.copyWith(beats: s.redoStack.last);
    emit(
      s.copyWith(
        project: updatedProject,
        redoStack: s.redoStack.sublist(0, s.redoStack.length - 1),
        undoStack: [...s.undoStack, s.project.beats],
        selectedIndex: null,
        saveError: null,
      ),
    );
    _scheduleSave(updatedProject);
  }

  void _commit(
    BeatEditorReady s,
    List<Beat> beats, {
    required int? selected,
    int? playheadSample,
    bool coalesce = false,
    bool isNudge = false,
  }) {
    // Any other edit ends the current run of nudges.
    if (!isNudge) _lastNudgeAt = null;
    final undo = coalesce && s.undoStack.isNotEmpty
        ? s.undoStack
        : [...s.undoStack, s.project.beats];
    final updatedProject = s.project.copyWith(beats: beats);
    emit(
      s.copyWith(
        project: updatedProject,
        undoStack: undo.length > _historyLimit
            ? undo.sublist(undo.length - _historyLimit)
            : undo,
        redoStack: const [],
        selectedIndex: selected,
        saveError: null,
      ),
    );
    if (playheadSample != null) _moveTo(playheadSample);
    _scheduleSave(updatedProject);
  }

  void _scheduleSave(Project project) {
    _pendingSaveProject = project;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDebounce, _flushPendingSave);
  }

  /// Queues the pending snapshot behind any save already running, so saves
  /// never overlap and always land in edit order. Returns the queue's tail.
  Future<void> _flushPendingSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final project = _pendingSaveProject;
    if (project == null) return _saveQueue;
    _pendingSaveProject = null;
    return _saveQueue = _saveQueue.then((_) => _save(project));
  }

  /// Never throws, so one failed save doesn't stall the queue.
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
    await _analysisCancelToken?.cancel();
    // Waits for any running save as well as the pending one.
    await _flushPendingSave();
    _zoom.removeListener(_ensureRawWindow);
    _playhead?.sample.removeListener(_ensureRawWindow);
    _pcmWindow?.dispose();
    final p = _playhead;
    if (p != null) {
      await p.dispose();
    } else {
      await _playback?.dispose();
    }
    _zoom.dispose();
    _idlePlayhead.dispose();
    return super.close();
  }
}
