part of 'beat_editor_cubit.dart';

enum EditorTool { auto, tap, edit, sections, bulk }

/// Which modal/bottom sheet is currently open over the editor, if any.
enum EditorSheet { none, autoDetect, detectFailed }

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

    /// True while a pre-rendered click-preview WAV is being generated.
    @Default(false) bool updatingClicks,
    @Default(1.0) double speed,
    @Default(false) bool playing,

    /// The player couldn't open the song; the editor still works silently.
    @Default(false) bool playbackUnavailable,
    @Default(EditorTool.edit) EditorTool tool,

    /// Index into `project.beats` of the marker being edited, if any.
    int? selectedIndex,

    /// Undo/redo availability driven by the cubit's `CommandStack`.
    @Default(false) bool canUndo,
    @Default(false) bool canRedo,

    /// Beats tapped during the current play-to-pause run on the Tap tab,
    /// displayed live on the waveform and committed as one `AddBeats` command.
    @Default(<Beat>[]) List<Beat> tapRunBeats,

    /// Effective tap latency compensation in milliseconds (calibrated value if
    /// calibrated, otherwise iOS reported output latency rounded to ms, else 0).
    @Default(0) int latencyOffsetMs,

    /// Output route on which the stored latency offset was calibrated.
    @Default(OutputKind.unknown) OutputKind latencyCalibratedOn,

    /// Current audio output route reported by `OutputRouteService`.
    @Default(OutputKind.unknown) OutputKind outputKind,

    /// Bulk-tab selection range in sample frames (live UI state, not in stack).
    int? bulkRangeStart,
    int? bulkRangeEnd,

    /// Bulk-tab pending shift amount in ms (`[-500, 500]`), reset after Apply.
    @Default(0) int bulkShiftMs,

    /// Active sheet overlay (Auto-detect or No steady beat).
    @Default(EditorSheet.none) EditorSheet activeSheet,

    /// True while the background isolate is analyzing `song.wav` because no
    /// cached `analysis.bin` existed yet.
    @Default(false) bool analyzing,

    /// Progress (0..1) while [analyzing] is true.
    @Default(0.0) double analysisProgress,

    /// Draft sensitivity in the Auto-detect sheet (0..1).
    @Default(0.5) double previewSensitivity,

    /// Draft filter in the Auto-detect sheet.
    @Default(BeatFilter.every) BeatFilter previewFilter,

    /// Live preview beats shown on the waveform while Auto-detect sheet is open.
    /// Null when not previewing (painter uses `project.beats`).
    List<Beat>? previewBeats,

    /// Live preview BPM shown in the Auto-detect sheet.
    double? previewBpm,

    /// Live preview sections shown on the waveform while Auto-detect sheet is open.
    List<Section>? previewSections,

    /// Whether the current preview classification succeeded.
    @Default(true) bool previewSucceeded,

    /// Latest non-fatal save error, surfaced as a SnackBar without losing edits.
    String? saveError,

    /// One-shot info message (e.g. "No drops found in this song"), surfaced as a SnackBar.
    String? infoMessage,
  }) = BeatEditorReady;

  const factory BeatEditorState.error({required String error}) =
      BeatEditorError;
}
