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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( Project project,  PeakPyramid peaks,  bool snap,  bool clicks,  double speed,  bool playing,  bool playbackUnavailable,  EditorTool tool,  int? selectedIndex,  List<List<Beat>> undoStack,  List<List<Beat>> redoStack,  String? saveError)?  ready,TResult Function( String error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading();case BeatEditorReady() when ready != null:
return ready(_that.project,_that.peaks,_that.snap,_that.clicks,_that.speed,_that.playing,_that.playbackUnavailable,_that.tool,_that.selectedIndex,_that.undoStack,_that.redoStack,_that.saveError);case BeatEditorError() when error != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( Project project,  PeakPyramid peaks,  bool snap,  bool clicks,  double speed,  bool playing,  bool playbackUnavailable,  EditorTool tool,  int? selectedIndex,  List<List<Beat>> undoStack,  List<List<Beat>> redoStack,  String? saveError)  ready,required TResult Function( String error)  error,}) {final _that = this;
switch (_that) {
case BeatEditorLoading():
return loading();case BeatEditorReady():
return ready(_that.project,_that.peaks,_that.snap,_that.clicks,_that.speed,_that.playing,_that.playbackUnavailable,_that.tool,_that.selectedIndex,_that.undoStack,_that.redoStack,_that.saveError);case BeatEditorError():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( Project project,  PeakPyramid peaks,  bool snap,  bool clicks,  double speed,  bool playing,  bool playbackUnavailable,  EditorTool tool,  int? selectedIndex,  List<List<Beat>> undoStack,  List<List<Beat>> redoStack,  String? saveError)?  ready,TResult? Function( String error)?  error,}) {final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading();case BeatEditorReady() when ready != null:
return ready(_that.project,_that.peaks,_that.snap,_that.clicks,_that.speed,_that.playing,_that.playbackUnavailable,_that.tool,_that.selectedIndex,_that.undoStack,_that.redoStack,_that.saveError);case BeatEditorError() when error != null:
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
  const BeatEditorReady({required this.project, required this.peaks, this.snap = true, this.clicks = false, this.speed = 1.0, this.playing = false, this.playbackUnavailable = false, this.tool = EditorTool.edit, this.selectedIndex,  List<List<Beat>> undoStack = const <List<Beat>>[],  List<List<Beat>> redoStack = const <List<Beat>>[], this.saveError}): _undoStack = undoStack,_redoStack = redoStack,super._();
  

 final  Project project;
/// Multi-level waveform peaks of `song.wav`.
 final  PeakPyramid peaks;
@JsonKey() final  bool snap;
@JsonKey() final  bool clicks;
@JsonKey() final  double speed;
@JsonKey() final  bool playing;
/// The player couldn't open the song; the editor still works silently.
@JsonKey() final  bool playbackUnavailable;
@JsonKey() final  EditorTool tool;
/// Index into `project.beats` of the marker being edited, if any.
 final  int? selectedIndex;
 final  List<List<Beat>> _undoStack;
@JsonKey() List<List<Beat>> get undoStack {
  if (_undoStack is EqualUnmodifiableListView) return _undoStack;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_undoStack);
}

 final  List<List<Beat>> _redoStack;
@JsonKey() List<List<Beat>> get redoStack {
  if (_redoStack is EqualUnmodifiableListView) return _redoStack;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_redoStack);
}

/// Latest non-fatal save error, surfaced as a SnackBar without losing edits.
 final  String? saveError;

/// Create a copy of BeatEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeatEditorReadyCopyWith<BeatEditorReady> get copyWith => _$BeatEditorReadyCopyWithImpl<BeatEditorReady>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'BeatEditorState.ready'))
    ..add(DiagnosticsProperty('project', project))..add(DiagnosticsProperty('peaks', peaks))..add(DiagnosticsProperty('snap', snap))..add(DiagnosticsProperty('clicks', clicks))..add(DiagnosticsProperty('speed', speed))..add(DiagnosticsProperty('playing', playing))..add(DiagnosticsProperty('playbackUnavailable', playbackUnavailable))..add(DiagnosticsProperty('tool', tool))..add(DiagnosticsProperty('selectedIndex', selectedIndex))..add(DiagnosticsProperty('undoStack', undoStack))..add(DiagnosticsProperty('redoStack', redoStack))..add(DiagnosticsProperty('saveError', saveError));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorReady&&(identical(other.project, project) || other.project == project)&&(identical(other.peaks, peaks) || other.peaks == peaks)&&(identical(other.snap, snap) || other.snap == snap)&&(identical(other.clicks, clicks) || other.clicks == clicks)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.playbackUnavailable, playbackUnavailable) || other.playbackUnavailable == playbackUnavailable)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&const DeepCollectionEquality().equals(other.undoStack, _undoStack)&&const DeepCollectionEquality().equals(other.redoStack, _redoStack)&&(identical(other.saveError, saveError) || other.saveError == saveError));
}


@override
int get hashCode {
    return Object.hash(runtimeType,project,peaks,snap,clicks,speed,playing,playbackUnavailable,tool,selectedIndex,const DeepCollectionEquality().hash(_undoStack),const DeepCollectionEquality().hash(_redoStack),saveError);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'BeatEditorState.ready(project: $project, peaks: $peaks, snap: $snap, clicks: $clicks, speed: $speed, playing: $playing, playbackUnavailable: $playbackUnavailable, tool: $tool, selectedIndex: $selectedIndex, undoStack: $undoStack, redoStack: $redoStack, saveError: $saveError)';
}


}

/// @nodoc
abstract mixin class $BeatEditorReadyCopyWith<$Res> implements $BeatEditorStateCopyWith<$Res> {
  factory $BeatEditorReadyCopyWith(BeatEditorReady value, $Res Function(BeatEditorReady) _then) = _$BeatEditorReadyCopyWithImpl;
@useResult
$Res call({
 Project project, PeakPyramid peaks, bool snap, bool clicks, double speed, bool playing, bool playbackUnavailable, EditorTool tool, int? selectedIndex, List<List<Beat>> undoStack, List<List<Beat>> redoStack, String? saveError
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
@pragma('vm:prefer-inline') $Res call({Object? project = null,Object? peaks = null,Object? snap = null,Object? clicks = null,Object? speed = null,Object? playing = null,Object? playbackUnavailable = null,Object? tool = null,Object? selectedIndex = freezed,Object? undoStack = null,Object? redoStack = null,Object? saveError = freezed,}) {
  return _then(BeatEditorReady(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as Project,peaks: null == peaks ? _self.peaks : peaks // ignore: cast_nullable_to_non_nullable
as PeakPyramid,snap: null == snap ? _self.snap : snap // ignore: cast_nullable_to_non_nullable
as bool,clicks: null == clicks ? _self.clicks : clicks // ignore: cast_nullable_to_non_nullable
as bool,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,playbackUnavailable: null == playbackUnavailable ? _self.playbackUnavailable : playbackUnavailable // ignore: cast_nullable_to_non_nullable
as bool,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as EditorTool,selectedIndex: freezed == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int?,undoStack: null == undoStack ? _self._undoStack : undoStack // ignore: cast_nullable_to_non_nullable
as List<List<Beat>>,redoStack: null == redoStack ? _self._redoStack : redoStack // ignore: cast_nullable_to_non_nullable
as List<List<Beat>>,saveError: freezed == saveError ? _self.saveError : saveError // ignore: cast_nullable_to_non_nullable
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
