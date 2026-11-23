import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/audio_math/overview.dart';
import '../../../core/di/locator.dart';
import '../../projects/projects.dart';

part 'beat_editor_cubit.freezed.dart';
part 'beat_editor_state.dart';

class BeatEditorCubit extends Cubit<BeatEditorState> {
  BeatEditorCubit({
    ProjectRepository? repository,
    this.saveDebounce = const Duration(milliseconds: 500),
  }) : _repository = repository ?? locator<ProjectRepository>(),
       super(const BeatEditorState.loading());

  final ProjectRepository _repository;
  final Duration saveDebounce;

  Timer? _ticker;
  DateTime? _lastTick;
  DateTime? _lastNudgeAt;
  int? _lastNudgeIndex;

  Timer? _saveTimer;
  Project? _pendingSaveProject;
  Future<void> _saveQueue = Future.value();

  static const minZoom = 1.0;
  static const maxZoom = 16.0;
  static const _historyLimit = 50;

  BeatEditorReady? get _ready => switch (state) {
    final BeatEditorReady s => s,
    _ => null,
  };

  Future<void> load(String projectId, {int initialPlayheadSample = 0}) async {
    emit(const BeatEditorState.loading());
    try {
      final project = await _repository.getProject(projectId);
      Overview ov;
      try {
        ov = await _repository.getOverview(projectId);
      } catch (_) {
        ov = Overview.empty;
      }
      if (isClosed) return;
      emit(
        BeatEditorState.ready(
          project: project,
          overview: ov.bins,
          binFrames: ov.binFrames,
          playheadSample: initialPlayheadSample.clamp(0, project.sampleCount),
          snap: project.bpm != null,
        ),
      );
    } on ProjectException catch (e) {
      if (!isClosed) emit(BeatEditorState.error(error: e.message));
    } catch (e) {
      if (!isClosed) emit(BeatEditorState.error(error: e.toString()));
    }
  }

  void seekTo(int sample) {
    final s = _ready;
    if (s == null) return;
    emit(s.copyWith(playheadSample: sample.clamp(0, s.project.sampleCount)));
  }

  /// Seeks relative to the current playhead by [deltaMs] milliseconds,
  /// converted to sample frames.
  void seekBy(int deltaMs) {
    final s = _ready;
    if (s == null) return;
    seekTo(s.playheadSample + s.project.msToSamples(deltaMs));
  }

  void setZoom(double zoom) {
    final s = _ready;
    if (s == null) return;
    emit(s.copyWith(zoom: zoom.clamp(minZoom, maxZoom)));
  }

  void setSpeed(double speed) {
    final s = _ready;
    if (s != null) emit(s.copyWith(speed: speed));
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
    // The marker inspector only exists on the Edit tab.
    emit(
      s.copyWith(
        tool: tool,
        selectedIndex: tool == EditorTool.edit ? s.selectedIndex : null,
      ),
    );
  }

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
    emit(s.copyWith(selectedIndex: index, playheadSample: beats[index].sample));
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
    final hi = i < beats.length - 1
        ? beats[i + 1].sample - 1
        : s.project.sampleCount;
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

  /// Advances the playhead on a timer in sample frames. Real audio playback
  /// arrives in M3.
  void togglePlay() {
    final s = _ready;
    if (s == null) return;
    if (s.playing) {
      _stopTicker();
      emit(s.copyWith(playing: false));
      return;
    }
    _lastTick = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    emit(s.copyWith(playing: true));
  }

  void _tick() {
    final s = _ready;
    if (s == null || !s.playing) return _stopTicker();
    final now = DateTime.now();
    final elapsedSec = now.difference(_lastTick!).inMicroseconds / 1e6;
    _lastTick = now;
    final deltaFrames = (elapsedSec * s.speed * s.project.sampleRate).round();
    final next = s.playheadSample + deltaFrames;
    if (next >= s.project.sampleCount) {
      _stopTicker();
      emit(s.copyWith(playheadSample: s.project.sampleCount, playing: false));
      return;
    }
    emit(s.copyWith(playheadSample: next));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void addBeatAtPlayhead() {
    final s = _ready;
    if (s == null) return;
    var sample = s.playheadSample;
    final bpm = s.project.bpm;
    if (s.snap && bpm != null && bpm > 0) {
      final phase = s.project.beatPhaseSample ?? 0;
      final grid = s.project.sampleRate * 60 / bpm;
      sample = (phase + ((sample - phase) / grid).round() * grid).round().clamp(
        0,
        s.project.sampleCount,
      );
    }
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
        playheadSample: playheadSample ?? s.playheadSample,
        saveError: null,
      ),
    );
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
    _stopTicker();
    // Waits for any running save as well as the pending one.
    await _flushPendingSave();
    return super.close();
  }
}
