part of 'beat_editor_cubit.dart';

enum EditorTool { auto, tap, edit, sections, bulk }

@freezed
sealed class BeatEditorState with _$BeatEditorState {
  const factory BeatEditorState.loading() = BeatEditorLoading;

  const factory BeatEditorState.ready({
    required BeatProject project,
    @Default(0) int playheadMs,

    /// 1× fits ~30 s on screen; the design's default is 4×.
    @Default(4.0) double zoom,
    @Default(true) bool snap,
    @Default(false) bool clicks,
    @Default(1.0) double speed,
    @Default(false) bool playing,
    @Default(EditorTool.edit) EditorTool tool,

    /// Index into `project.beats` of the marker being edited, if any.
    int? selectedIndex,
    @Default(<List<Beat>>[]) List<List<Beat>> undoStack,
    @Default(<List<Beat>>[]) List<List<Beat>> redoStack,
  }) = BeatEditorReady;

  const factory BeatEditorState.error({required String error}) =
      BeatEditorError;
}
