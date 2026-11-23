// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'beat_editor_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BeatEditorState implements DiagnosticableTreeMixin {




@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'BeatEditorState'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'BeatEditorState()';
}


}

/// @nodoc
class $BeatEditorStateCopyWith<$Res>  {
$BeatEditorStateCopyWith(BeatEditorState _, $Res Function(BeatEditorState) __);
}


/// Adds pattern-matching-related methods to [BeatEditorState].
extension BeatEditorStatePatterns on BeatEditorState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BeatEditorLoading value)?  loading,TResult Function( BeatEditorReady value)?  ready,TResult Function( BeatEditorError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading(_that);case BeatEditorReady() when ready != null:
return ready(_that);case BeatEditorError() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BeatEditorLoading value)  loading,required TResult Function( BeatEditorReady value)  ready,required TResult Function( BeatEditorError value)  error,}){
final _that = this;
switch (_that) {
case BeatEditorLoading():
return loading(_that);case BeatEditorReady():
return ready(_that);case BeatEditorError():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BeatEditorLoading value)?  loading,TResult? Function( BeatEditorReady value)?  ready,TResult? Function( BeatEditorError value)?  error,}){
final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading(_that);case BeatEditorReady() when ready != null:
return ready(_that);case BeatEditorError() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( Project project,  PeakPyramid peaks,  bool snap,  bool clicks,  bool updatingClicks,  double speed,  bool playing,  bool playbackUnavailable,  EditorTool tool,  int? selectedIndex,  bool canUndo,  bool canRedo,  List<Beat> tapRunBeats,  int latencyOffsetMs,  OutputKind latencyCalibratedOn,  OutputKind outputKind,  int? bulkRangeStart,  int? bulkRangeEnd,  int bulkShiftMs,  EditorSheet activeSheet,  bool analyzing,  double analysisProgress,  double previewSensitivity,  BeatFilter previewFilter,  List<Beat>? previewBeats,  double? previewBpm,  List<Section>? previewSections,  bool previewSucceeded,  String? saveError,  String? infoMessage)?  ready,TResult Function( String error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading();case BeatEditorReady() when ready != null:
return ready(_that.project,_that.peaks,_that.snap,_that.clicks,_that.updatingClicks,_that.speed,_that.playing,_that.playbackUnavailable,_that.tool,_that.selectedIndex,_that.canUndo,_that.canRedo,_that.tapRunBeats,_that.latencyOffsetMs,_that.latencyCalibratedOn,_that.outputKind,_that.bulkRangeStart,_that.bulkRangeEnd,_that.bulkShiftMs,_that.activeSheet,_that.analyzing,_that.analysisProgress,_that.previewSensitivity,_that.previewFilter,_that.previewBeats,_that.previewBpm,_that.previewSections,_that.previewSucceeded,_that.saveError,_that.infoMessage);case BeatEditorError() when error != null:
return error(_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( Project project,  PeakPyramid peaks,  bool snap,  bool clicks,  bool updatingClicks,  double speed,  bool playing,  bool playbackUnavailable,  EditorTool tool,  int? selectedIndex,  bool canUndo,  bool canRedo,  List<Beat> tapRunBeats,  int latencyOffsetMs,  OutputKind latencyCalibratedOn,  OutputKind outputKind,  int? bulkRangeStart,  int? bulkRangeEnd,  int bulkShiftMs,  EditorSheet activeSheet,  bool analyzing,  double analysisProgress,  double previewSensitivity,  BeatFilter previewFilter,  List<Beat>? previewBeats,  double? previewBpm,  List<Section>? previewSections,  bool previewSucceeded,  String? saveError,  String? infoMessage)  ready,required TResult Function( String error)  error,}) {final _that = this;
switch (_that) {
case BeatEditorLoading():
return loading();case BeatEditorReady():
return ready(_that.project,_that.peaks,_that.snap,_that.clicks,_that.updatingClicks,_that.speed,_that.playing,_that.playbackUnavailable,_that.tool,_that.selectedIndex,_that.canUndo,_that.canRedo,_that.tapRunBeats,_that.latencyOffsetMs,_that.latencyCalibratedOn,_that.outputKind,_that.bulkRangeStart,_that.bulkRangeEnd,_that.bulkShiftMs,_that.activeSheet,_that.analyzing,_that.analysisProgress,_that.previewSensitivity,_that.previewFilter,_that.previewBeats,_that.previewBpm,_that.previewSections,_that.previewSucceeded,_that.saveError,_that.infoMessage);case BeatEditorError():
return error(_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( Project project,  PeakPyramid peaks,  bool snap,  bool clicks,  bool updatingClicks,  double speed,  bool playing,  bool playbackUnavailable,  EditorTool tool,  int? selectedIndex,  bool canUndo,  bool canRedo,  List<Beat> tapRunBeats,  int latencyOffsetMs,  OutputKind latencyCalibratedOn,  OutputKind outputKind,  int? bulkRangeStart,  int? bulkRangeEnd,  int bulkShiftMs,  EditorSheet activeSheet,  bool analyzing,  double analysisProgress,  double previewSensitivity,  BeatFilter previewFilter,  List<Beat>? previewBeats,  double? previewBpm,  List<Section>? previewSections,  bool previewSucceeded,  String? saveError,  String? infoMessage)?  ready,TResult? Function( String error)?  error,}) {final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading();case BeatEditorReady() when ready != null:
return ready(_that.project,_that.peaks,_that.snap,_that.clicks,_that.updatingClicks,_that.speed,_that.playing,_that.playbackUnavailable,_that.tool,_that.selectedIndex,_that.canUndo,_that.canRedo,_that.tapRunBeats,_that.latencyOffsetMs,_that.latencyCalibratedOn,_that.outputKind,_that.bulkRangeStart,_that.bulkRangeEnd,_that.bulkShiftMs,_that.activeSheet,_that.analyzing,_that.analysisProgress,_that.previewSensitivity,_that.previewFilter,_that.previewBeats,_that.previewBpm,_that.previewSections,_that.previewSucceeded,_that.saveError,_that.infoMessage);case BeatEditorError() when error != null:
return error(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class BeatEditorLoading extends BeatEditorState with DiagnosticableTreeMixin {
  const BeatEditorLoading(): super._();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'BeatEditorState.loading'))
    ;
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'BeatEditorState.loading()';
}


}




/// @nodoc


class BeatEditorReady extends BeatEditorState with DiagnosticableTreeMixin {
  const BeatEditorReady({required this.project, required this.peaks, this.snap = true, this.clicks = false, this.updatingClicks = false, this.speed = 1.0, this.playing = false, this.playbackUnavailable = false, this.tool = EditorTool.edit, this.selectedIndex, this.canUndo = false, this.canRedo = false,  List<Beat> tapRunBeats = const <Beat>[], this.latencyOffsetMs = 0, this.latencyCalibratedOn = OutputKind.unknown, this.outputKind = OutputKind.unknown, this.bulkRangeStart, this.bulkRangeEnd, this.bulkShiftMs = 0, this.activeSheet = EditorSheet.none, this.analyzing = false, this.analysisProgress = 0.0, this.previewSensitivity = 0.5, this.previewFilter = BeatFilter.every,  List<Beat>? previewBeats, this.previewBpm,  List<Section>? previewSections, this.previewSucceeded = true, this.saveError, this.infoMessage}): _tapRunBeats = tapRunBeats,_previewBeats = previewBeats,_previewSections = previewSections,super._();
  

 final  Project project;
/// Multi-level waveform peaks of `song.wav`.
 final  PeakPyramid peaks;
@JsonKey() final  bool snap;
@JsonKey() final  bool clicks;
/// True while a pre-rendered click-preview WAV is being generated.
@JsonKey() final  bool updatingClicks;
@JsonKey() final  double speed;
@JsonKey() final  bool playing;
/// The player couldn't open the song; the editor still works silently.
@JsonKey() final  bool playbackUnavailable;
@JsonKey() final  EditorTool tool;
/// Index into `project.beats` of the marker being edited, if any.
 final  int? selectedIndex;
/// Undo/redo availability driven by the cubit's `CommandStack`.
@JsonKey() final  bool canUndo;
@JsonKey() final  bool canRedo;
/// Beats tapped during the current play-to-pause run on the Tap tab,
/// displayed live on the waveform and committed as one `AddBeats` command.
 final  List<Beat> _tapRunBeats;
/// Beats tapped during the current play-to-pause run on the Tap tab,
/// displayed live on the waveform and committed as one `AddBeats` command.
@JsonKey() List<Beat> get tapRunBeats {
  if (_tapRunBeats is EqualUnmodifiableListView) return _tapRunBeats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tapRunBeats);
}

/// Effective tap latency compensation in milliseconds (calibrated value if
/// calibrated, otherwise iOS reported output latency rounded to ms, else 0).
@JsonKey() final  int latencyOffsetMs;
/// Output route on which the stored latency offset was calibrated.
@JsonKey() final  OutputKind latencyCalibratedOn;
/// Current audio output route reported by `OutputRouteService`.
@JsonKey() final  OutputKind outputKind;
/// Bulk-tab selection range in sample frames (live UI state, not in stack).
 final  int? bulkRangeStart;
 final  int? bulkRangeEnd;
/// Bulk-tab pending shift amount in ms (`[-500, 500]`), reset after Apply.
@JsonKey() final  int bulkShiftMs;
/// Active sheet overlay (Auto-detect or No steady beat).
@JsonKey() final  EditorSheet activeSheet;
/// True while the background isolate is analyzing `song.wav` because no
/// cached `analysis.bin` existed yet.
@JsonKey() final  bool analyzing;
/// Progress (0..1) while [analyzing] is true.
@JsonKey() final  double analysisProgress;
/// Draft sensitivity in the Auto-detect sheet (0..1).
@JsonKey() final  double previewSensitivity;
/// Draft filter in the Auto-detect sheet.
@JsonKey() final  BeatFilter previewFilter;
/// Live preview beats shown on the waveform while Auto-detect sheet is open.
/// Null when not previewing (painter uses `project.beats`).
 final  List<Beat>? _previewBeats;
/// Live preview beats shown on the waveform while Auto-detect sheet is open.
/// Null when not previewing (painter uses `project.beats`).
 List<Beat>? get previewBeats {
  final value = _previewBeats;
  if (value == null) return null;
  if (_previewBeats is EqualUnmodifiableListView) return _previewBeats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Live preview BPM shown in the Auto-detect sheet.
 final  double? previewBpm;
/// Live preview sections shown on the waveform while Auto-detect sheet is open.
 final  List<Section>? _previewSections;
/// Live preview sections shown on the waveform while Auto-detect sheet is open.
 List<Section>? get previewSections {
  final value = _previewSections;
  if (value == null) return null;
  if (_previewSections is EqualUnmodifiableListView) return _previewSections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Whether the current preview classification succeeded.
@JsonKey() final  bool previewSucceeded;
/// Latest non-fatal save error, surfaced as a SnackBar without losing edits.
 final  String? saveError;
/// One-shot info message (e.g. "No drops found in this song"), surfaced as a SnackBar.
 final  String? infoMessage;

/// Create a copy of BeatEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeatEditorReadyCopyWith<BeatEditorReady> get copyWith => _$BeatEditorReadyCopyWithImpl<BeatEditorReady>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'BeatEditorState.ready'))
    ..add(DiagnosticsProperty('project', project))..add(DiagnosticsProperty('peaks', peaks))..add(DiagnosticsProperty('snap', snap))..add(DiagnosticsProperty('clicks', clicks))..add(DiagnosticsProperty('updatingClicks', updatingClicks))..add(DiagnosticsProperty('speed', speed))..add(DiagnosticsProperty('playing', playing))..add(DiagnosticsProperty('playbackUnavailable', playbackUnavailable))..add(DiagnosticsProperty('tool', tool))..add(DiagnosticsProperty('selectedIndex', selectedIndex))..add(DiagnosticsProperty('canUndo', canUndo))..add(DiagnosticsProperty('canRedo', canRedo))..add(DiagnosticsProperty('tapRunBeats', tapRunBeats))..add(DiagnosticsProperty('latencyOffsetMs', latencyOffsetMs))..add(DiagnosticsProperty('latencyCalibratedOn', latencyCalibratedOn))..add(DiagnosticsProperty('outputKind', outputKind))..add(DiagnosticsProperty('bulkRangeStart', bulkRangeStart))..add(DiagnosticsProperty('bulkRangeEnd', bulkRangeEnd))..add(DiagnosticsProperty('bulkShiftMs', bulkShiftMs))..add(DiagnosticsProperty('activeSheet', activeSheet))..add(DiagnosticsProperty('analyzing', analyzing))..add(DiagnosticsProperty('analysisProgress', analysisProgress))..add(DiagnosticsProperty('previewSensitivity', previewSensitivity))..add(DiagnosticsProperty('previewFilter', previewFilter))..add(DiagnosticsProperty('previewBeats', previewBeats))..add(DiagnosticsProperty('previewBpm', previewBpm))..add(DiagnosticsProperty('previewSections', previewSections))..add(DiagnosticsProperty('previewSucceeded', previewSucceeded))..add(DiagnosticsProperty('saveError', saveError))..add(DiagnosticsProperty('infoMessage', infoMessage));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorReady&&(identical(other.project, project) || other.project == project)&&(identical(other.peaks, peaks) || other.peaks == peaks)&&(identical(other.snap, snap) || other.snap == snap)&&(identical(other.clicks, clicks) || other.clicks == clicks)&&(identical(other.updatingClicks, updatingClicks) || other.updatingClicks == updatingClicks)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.playbackUnavailable, playbackUnavailable) || other.playbackUnavailable == playbackUnavailable)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.canUndo, canUndo) || other.canUndo == canUndo)&&(identical(other.canRedo, canRedo) || other.canRedo == canRedo)&&const DeepCollectionEquality().equals(other.tapRunBeats, _tapRunBeats)&&(identical(other.latencyOffsetMs, latencyOffsetMs) || other.latencyOffsetMs == latencyOffsetMs)&&(identical(other.latencyCalibratedOn, latencyCalibratedOn) || other.latencyCalibratedOn == latencyCalibratedOn)&&(identical(other.outputKind, outputKind) || other.outputKind == outputKind)&&(identical(other.bulkRangeStart, bulkRangeStart) || other.bulkRangeStart == bulkRangeStart)&&(identical(other.bulkRangeEnd, bulkRangeEnd) || other.bulkRangeEnd == bulkRangeEnd)&&(identical(other.bulkShiftMs, bulkShiftMs) || other.bulkShiftMs == bulkShiftMs)&&(identical(other.activeSheet, activeSheet) || other.activeSheet == activeSheet)&&(identical(other.analyzing, analyzing) || other.analyzing == analyzing)&&(identical(other.analysisProgress, analysisProgress) || other.analysisProgress == analysisProgress)&&(identical(other.previewSensitivity, previewSensitivity) || other.previewSensitivity == previewSensitivity)&&(identical(other.previewFilter, previewFilter) || other.previewFilter == previewFilter)&&const DeepCollectionEquality().equals(other.previewBeats, _previewBeats)&&(identical(other.previewBpm, previewBpm) || other.previewBpm == previewBpm)&&const DeepCollectionEquality().equals(other.previewSections, _previewSections)&&(identical(other.previewSucceeded, previewSucceeded) || other.previewSucceeded == previewSucceeded)&&(identical(other.saveError, saveError) || other.saveError == saveError)&&(identical(other.infoMessage, infoMessage) || other.infoMessage == infoMessage));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,project,peaks,snap,clicks,updatingClicks,speed,playing,playbackUnavailable,tool,selectedIndex,canUndo,canRedo,const DeepCollectionEquality().hash(_tapRunBeats),latencyOffsetMs,latencyCalibratedOn,outputKind,bulkRangeStart,bulkRangeEnd,bulkShiftMs,activeSheet,analyzing,analysisProgress,previewSensitivity,previewFilter,const DeepCollectionEquality().hash(_previewBeats),previewBpm,const DeepCollectionEquality().hash(_previewSections),previewSucceeded,saveError,infoMessage]);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'BeatEditorState.ready(project: $project, peaks: $peaks, snap: $snap, clicks: $clicks, updatingClicks: $updatingClicks, speed: $speed, playing: $playing, playbackUnavailable: $playbackUnavailable, tool: $tool, selectedIndex: $selectedIndex, canUndo: $canUndo, canRedo: $canRedo, tapRunBeats: $tapRunBeats, latencyOffsetMs: $latencyOffsetMs, latencyCalibratedOn: $latencyCalibratedOn, outputKind: $outputKind, bulkRangeStart: $bulkRangeStart, bulkRangeEnd: $bulkRangeEnd, bulkShiftMs: $bulkShiftMs, activeSheet: $activeSheet, analyzing: $analyzing, analysisProgress: $analysisProgress, previewSensitivity: $previewSensitivity, previewFilter: $previewFilter, previewBeats: $previewBeats, previewBpm: $previewBpm, previewSections: $previewSections, previewSucceeded: $previewSucceeded, saveError: $saveError, infoMessage: $infoMessage)';
}


}

/// @nodoc
abstract mixin class $BeatEditorReadyCopyWith<$Res> implements $BeatEditorStateCopyWith<$Res> {
  factory $BeatEditorReadyCopyWith(BeatEditorReady value, $Res Function(BeatEditorReady) _then) = _$BeatEditorReadyCopyWithImpl;
@useResult
$Res call({
 Project project, PeakPyramid peaks, bool snap, bool clicks, bool updatingClicks, double speed, bool playing, bool playbackUnavailable, EditorTool tool, int? selectedIndex, bool canUndo, bool canRedo, List<Beat> tapRunBeats, int latencyOffsetMs, OutputKind latencyCalibratedOn, OutputKind outputKind, int? bulkRangeStart, int? bulkRangeEnd, int bulkShiftMs, EditorSheet activeSheet, bool analyzing, double analysisProgress, double previewSensitivity, BeatFilter previewFilter, List<Beat>? previewBeats, double? previewBpm, List<Section>? previewSections, bool previewSucceeded, String? saveError, String? infoMessage
});


$ProjectCopyWith<$Res> get project;

}
/// @nodoc
class _$BeatEditorReadyCopyWithImpl<$Res>
    implements $BeatEditorReadyCopyWith<$Res> {
  _$BeatEditorReadyCopyWithImpl(this._self, this._then);

  final BeatEditorReady _self;
  final $Res Function(BeatEditorReady) _then;

/// Create a copy of BeatEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? project = null,Object? peaks = null,Object? snap = null,Object? clicks = null,Object? updatingClicks = null,Object? speed = null,Object? playing = null,Object? playbackUnavailable = null,Object? tool = null,Object? selectedIndex = freezed,Object? canUndo = null,Object? canRedo = null,Object? tapRunBeats = null,Object? latencyOffsetMs = null,Object? latencyCalibratedOn = null,Object? outputKind = null,Object? bulkRangeStart = freezed,Object? bulkRangeEnd = freezed,Object? bulkShiftMs = null,Object? activeSheet = null,Object? analyzing = null,Object? analysisProgress = null,Object? previewSensitivity = null,Object? previewFilter = null,Object? previewBeats = freezed,Object? previewBpm = freezed,Object? previewSections = freezed,Object? previewSucceeded = null,Object? saveError = freezed,Object? infoMessage = freezed,}) {
  return _then(BeatEditorReady(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as Project,peaks: null == peaks ? _self.peaks : peaks // ignore: cast_nullable_to_non_nullable
as PeakPyramid,snap: null == snap ? _self.snap : snap // ignore: cast_nullable_to_non_nullable
as bool,clicks: null == clicks ? _self.clicks : clicks // ignore: cast_nullable_to_non_nullable
as bool,updatingClicks: null == updatingClicks ? _self.updatingClicks : updatingClicks // ignore: cast_nullable_to_non_nullable
as bool,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,playbackUnavailable: null == playbackUnavailable ? _self.playbackUnavailable : playbackUnavailable // ignore: cast_nullable_to_non_nullable
as bool,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as EditorTool,selectedIndex: freezed == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int?,canUndo: null == canUndo ? _self.canUndo : canUndo // ignore: cast_nullable_to_non_nullable
as bool,canRedo: null == canRedo ? _self.canRedo : canRedo // ignore: cast_nullable_to_non_nullable
as bool,tapRunBeats: null == tapRunBeats ? _self._tapRunBeats : tapRunBeats // ignore: cast_nullable_to_non_nullable
as List<Beat>,latencyOffsetMs: null == latencyOffsetMs ? _self.latencyOffsetMs : latencyOffsetMs // ignore: cast_nullable_to_non_nullable
as int,latencyCalibratedOn: null == latencyCalibratedOn ? _self.latencyCalibratedOn : latencyCalibratedOn // ignore: cast_nullable_to_non_nullable
as OutputKind,outputKind: null == outputKind ? _self.outputKind : outputKind // ignore: cast_nullable_to_non_nullable
as OutputKind,bulkRangeStart: freezed == bulkRangeStart ? _self.bulkRangeStart : bulkRangeStart // ignore: cast_nullable_to_non_nullable
as int?,bulkRangeEnd: freezed == bulkRangeEnd ? _self.bulkRangeEnd : bulkRangeEnd // ignore: cast_nullable_to_non_nullable
as int?,bulkShiftMs: null == bulkShiftMs ? _self.bulkShiftMs : bulkShiftMs // ignore: cast_nullable_to_non_nullable
as int,activeSheet: null == activeSheet ? _self.activeSheet : activeSheet // ignore: cast_nullable_to_non_nullable
as EditorSheet,analyzing: null == analyzing ? _self.analyzing : analyzing // ignore: cast_nullable_to_non_nullable
as bool,analysisProgress: null == analysisProgress ? _self.analysisProgress : analysisProgress // ignore: cast_nullable_to_non_nullable
as double,previewSensitivity: null == previewSensitivity ? _self.previewSensitivity : previewSensitivity // ignore: cast_nullable_to_non_nullable
as double,previewFilter: null == previewFilter ? _self.previewFilter : previewFilter // ignore: cast_nullable_to_non_nullable
as BeatFilter,previewBeats: freezed == previewBeats ? _self._previewBeats : previewBeats // ignore: cast_nullable_to_non_nullable
as List<Beat>?,previewBpm: freezed == previewBpm ? _self.previewBpm : previewBpm // ignore: cast_nullable_to_non_nullable
as double?,previewSections: freezed == previewSections ? _self._previewSections : previewSections // ignore: cast_nullable_to_non_nullable
as List<Section>?,previewSucceeded: null == previewSucceeded ? _self.previewSucceeded : previewSucceeded // ignore: cast_nullable_to_non_nullable
as bool,saveError: freezed == saveError ? _self.saveError : saveError // ignore: cast_nullable_to_non_nullable
as String?,infoMessage: freezed == infoMessage ? _self.infoMessage : infoMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of BeatEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectCopyWith<$Res> get project {
  
  return $ProjectCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}

/// @nodoc


class BeatEditorError extends BeatEditorState with DiagnosticableTreeMixin {
  const BeatEditorError({required this.error}): super._();
  

 final  String error;

/// Create a copy of BeatEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeatEditorErrorCopyWith<BeatEditorError> get copyWith => _$BeatEditorErrorCopyWithImpl<BeatEditorError>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'BeatEditorState.error'))
    ..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorError&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'BeatEditorState.error(error: $error)';
}


}

/// @nodoc
abstract mixin class $BeatEditorErrorCopyWith<$Res> implements $BeatEditorStateCopyWith<$Res> {
  factory $BeatEditorErrorCopyWith(BeatEditorError value, $Res Function(BeatEditorError) _then) = _$BeatEditorErrorCopyWithImpl;
@useResult
$Res call({
 String error
});




}
/// @nodoc
class _$BeatEditorErrorCopyWithImpl<$Res>
    implements $BeatEditorErrorCopyWith<$Res> {
  _$BeatEditorErrorCopyWithImpl(this._self, this._then);

  final BeatEditorError _self;
  final $Res Function(BeatEditorError) _then;

/// Create a copy of BeatEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(BeatEditorError(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
