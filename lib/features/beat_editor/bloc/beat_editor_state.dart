part of 'beat_editor_cubit.dart';

enum EditorTool { auto, tap, edit, sections, bulk }

@freezed
sealed class BeatEditorState with _$BeatEditorState {
  const BeatEditorState._();

  const factory BeatEditorState.loading() = BeatEditorLoading;

  const factory BeatEditorState.ready({
    required Project project,
    required Uint8List overview,
    required int binFrames,
    @Default(0) int playheadSample,

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

    /// Latest non-fatal save error, surfaced as a SnackBar without losing edits.
    String? saveError,
  }) = BeatEditorReady;

  const factory BeatEditorState.error({required String error}) =
      BeatEditorError;
}
