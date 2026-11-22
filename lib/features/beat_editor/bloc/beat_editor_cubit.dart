import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/di/locator.dart';
import '../data/repositories/beat_project_repository.dart';
import '../domain/entities/beat.dart';
import '../domain/entities/beat_project.dart';

part 'beat_editor_cubit.freezed.dart';
part 'beat_editor_state.dart';

class BeatEditorCubit extends Cubit<BeatEditorState> {
  BeatEditorCubit({BeatProjectRepository? repository})
    : _repository = repository ?? locator<BeatProjectRepository>(),
      super(const BeatEditorState.loading());

  final BeatProjectRepository _repository;
  Timer? _ticker;
  DateTime? _lastTick;
  DateTime? _lastNudgeAt;
  int? _lastNudgeIndex;

  static const minZoom = 1.0;
  static const maxZoom = 16.0;
  static const _historyLimit = 50;

  BeatEditorReady? get _ready => switch (state) {
    final BeatEditorReady s => s,
    _ => null,
  };

  Future<void> load(String projectId, {int initialPlayheadMs = 0}) async {
    emit(const BeatEditorState.loading());
    try {
      final project = await _repository.getProject(projectId);
      emit(
        BeatEditorState.ready(project: project, playheadMs: initialPlayheadMs),
      );
    } catch (e) {
      emit(BeatEditorState.error(error: e.toString()));
    }
  }

  void seekTo(int ms) {
    final s = _ready;
    if (s == null) return;
    emit(s.copyWith(playheadMs: ms.clamp(0, s.project.durationMs)));
  }

  void seekBy(int deltaMs) {
    final s = _ready;
    if (s != null) seekTo(s.playheadMs + deltaMs);
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
    if (s != null) emit(s.copyWith(snap: !s.snap));
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
    emit(s.copyWith(selectedIndex: index, playheadMs: beats[index].timeMs));
    HapticFeedback.selectionClick();
  }

  /// Moves the selected marker by [deltaMs], staying between its neighbours.
  /// Taps within a second of each other share one undo step.
  void nudgeSelected(int deltaMs) {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    final beats = s.project.beats;
    final lo = i > 0 ? beats[i - 1].timeMs + 1 : 0;
    final hi = i < beats.length - 1
        ? beats[i + 1].timeMs - 1
        : s.project.durationMs;
    if (lo > hi) return;
    final t = (beats[i].timeMs + deltaMs).clamp(lo, hi);
    if (t == beats[i].timeMs) return;

    final now = DateTime.now();
    final coalesce =
        _lastNudgeIndex == i &&
        _lastNudgeAt != null &&
        now.difference(_lastNudgeAt!) < const Duration(seconds: 1);
    _lastNudgeIndex = i;
    _lastNudgeAt = now;

    final next = [...beats]..[i] = beats[i].copyWith(timeMs: t);
    _commit(
      s,
      next,
      selected: i,
      playheadMs: t,
      coalesce: coalesce,
      isNudge: true,
    );
    HapticFeedback.selectionClick();
  }

  void setSelectedType(BeatType type) {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null || s.project.beats[i].type == type) return;
    final next = [...s.project.beats]
      ..[i] = s.project.beats[i].copyWith(type: type);
    _commit(s, next, selected: i);
    HapticFeedback.selectionClick();
  }

  void deleteSelected() {
    final s = _ready;
    final i = s?.selectedIndex;
    if (s == null || i == null) return;
    final next = [...s.project.beats]..removeAt(i);
    _commit(s, next, selected: null);
    HapticFeedback.heavyImpact();
  }

  /// Advances the playhead on a timer. Audio is not wired up yet.
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
    final elapsed = now.difference(_lastTick!).inMicroseconds / 1000;
    _lastTick = now;
    final next = s.playheadMs + (elapsed * s.speed).round();
    if (next >= s.project.durationMs) {
      _stopTicker();
      emit(s.copyWith(playheadMs: s.project.durationMs, playing: false));
      return;
    }
    emit(s.copyWith(playheadMs: next));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void addBeatAtPlayhead() {
    final s = _ready;
    if (s == null) return;
    var t = s.playheadMs;
    if (s.snap) {
      final grid = 60000 / s.project.bpm;
      t = ((t / grid).round() * grid).round();
    }
    final beats = s.project.beats;
    if (beats.any((b) => (b.timeMs - t).abs() < 20)) return;
    final next = [...beats, Beat(timeMs: t)]
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    // Select the new marker so it can be fine-tuned straight away.
    _commit(s, next, selected: next.indexWhere((b) => b.timeMs == t));
    HapticFeedback.selectionClick();
  }

  void undo() {
    final s = _ready;
    if (s == null || s.undoStack.isEmpty) return;
    _lastNudgeAt = null;
    emit(
      s.copyWith(
        project: s.project.copyWith(beats: s.undoStack.last),
        undoStack: s.undoStack.sublist(0, s.undoStack.length - 1),
        redoStack: [...s.redoStack, s.project.beats],
        selectedIndex: null,
      ),
    );
  }

  void redo() {
    final s = _ready;
    if (s == null || s.redoStack.isEmpty) return;
    _lastNudgeAt = null;
    emit(
      s.copyWith(
        project: s.project.copyWith(beats: s.redoStack.last),
        redoStack: s.redoStack.sublist(0, s.redoStack.length - 1),
        undoStack: [...s.undoStack, s.project.beats],
        selectedIndex: null,
      ),
    );
  }

  void _commit(
    BeatEditorReady s,
    List<Beat> beats, {
    required int? selected,
    int? playheadMs,
    bool coalesce = false,
    bool isNudge = false,
  }) {
    // Any other edit ends the current run of nudges.
    if (!isNudge) _lastNudgeAt = null;
    final undo = coalesce && s.undoStack.isNotEmpty
        ? s.undoStack
        : [...s.undoStack, s.project.beats];
    emit(
      s.copyWith(
        project: s.project.copyWith(beats: beats),
        undoStack: undo.length > _historyLimit
            ? undo.sublist(undo.length - _historyLimit)
            : undo,
        redoStack: const [],
        selectedIndex: selected,
        playheadMs: playheadMs ?? s.playheadMs,
      ),
    );
  }

  @override
  Future<void> close() {
    _stopTicker();
    return super.close();
  }
}
