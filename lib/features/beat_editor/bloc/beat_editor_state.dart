part of 'beat_editor_cubit.dart';

enum EditorTool { auto, tap, edit, sections, bulk }

/// Editor state. The playhead and zoom change every frame while playing or
/// pinching, so they live on the cubit as `ValueListenable`s
/// ([BeatEditorCubit.playhead], [BeatEditorCubit.zoom]) that painters
/// listen to directly, not here.
@freezed
sealed class BeatEditorState with _$BeatEditorState {
  const BeatEditorState._();

  const factory BeatEditorState.loading() = BeatEditorLoading;

  const factory BeatEditorState.ready({
    required Project project,

    /// Multi-level waveform peaks of `song.wav`.
    required PeakPyramid peaks,
    @Default(true) bool snap,
    @Default(false) bool clicks,
    @Default(1.0) double speed,
    @Default(false) bool playing,

    /// The player couldn't open the song; the editor still works silently.
    @Default(false) bool playbackUnavailable,
    @Default(EditorTool.edit) EditorTool tool,

    /// Index into `project.beats` of the marker being edited, if any.
    int? selectedIndex,
    @Default(<List<Beat>>[]) List<List<Beat>> undoStack,
    @Default(<List<Beat>>[]) List<List<Beat>> redoStack,

    /// Latest non-fatal save error, surfaced as a SnackBar without losing edits.
    String? saveError,
  }) = BeatEditorReady;

  const factory BeatEditorState.error({required String error}) =
      BeatEditorError;
}
