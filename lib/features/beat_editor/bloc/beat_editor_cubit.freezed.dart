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
mixin _$BeatEditorState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( Project project,  Uint8List overview,  int binFrames,  int playheadSample,  double zoom,  bool snap,  bool clicks,  double speed,  bool playing,  EditorTool tool,  int? selectedIndex,  List<List<Beat>> undoStack,  List<List<Beat>> redoStack,  String? saveError)?  ready,TResult Function( String error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading();case BeatEditorReady() when ready != null:
return ready(_that.project,_that.overview,_that.binFrames,_that.playheadSample,_that.zoom,_that.snap,_that.clicks,_that.speed,_that.playing,_that.tool,_that.selectedIndex,_that.undoStack,_that.redoStack,_that.saveError);case BeatEditorError() when error != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( Project project,  Uint8List overview,  int binFrames,  int playheadSample,  double zoom,  bool snap,  bool clicks,  double speed,  bool playing,  EditorTool tool,  int? selectedIndex,  List<List<Beat>> undoStack,  List<List<Beat>> redoStack,  String? saveError)  ready,required TResult Function( String error)  error,}) {final _that = this;
switch (_that) {
case BeatEditorLoading():
return loading();case BeatEditorReady():
return ready(_that.project,_that.overview,_that.binFrames,_that.playheadSample,_that.zoom,_that.snap,_that.clicks,_that.speed,_that.playing,_that.tool,_that.selectedIndex,_that.undoStack,_that.redoStack,_that.saveError);case BeatEditorError():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( Project project,  Uint8List overview,  int binFrames,  int playheadSample,  double zoom,  bool snap,  bool clicks,  double speed,  bool playing,  EditorTool tool,  int? selectedIndex,  List<List<Beat>> undoStack,  List<List<Beat>> redoStack,  String? saveError)?  ready,TResult? Function( String error)?  error,}) {final _that = this;
switch (_that) {
case BeatEditorLoading() when loading != null:
return loading();case BeatEditorReady() when ready != null:
return ready(_that.project,_that.overview,_that.binFrames,_that.playheadSample,_that.zoom,_that.snap,_that.clicks,_that.speed,_that.playing,_that.tool,_that.selectedIndex,_that.undoStack,_that.redoStack,_that.saveError);case BeatEditorError() when error != null:
return error(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class BeatEditorLoading extends BeatEditorState {
  const BeatEditorLoading(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BeatEditorState.loading()';
}


}




/// @nodoc


class BeatEditorReady extends BeatEditorState {
  const BeatEditorReady({required this.project, required this.overview, required this.binFrames, this.playheadSample = 0, this.zoom = 4.0, this.snap = true, this.clicks = false, this.speed = 1.0, this.playing = false, this.tool = EditorTool.edit, this.selectedIndex,  List<List<Beat>> undoStack = const <List<Beat>>[],  List<List<Beat>> redoStack = const <List<Beat>>[], this.saveError}): _undoStack = undoStack,_redoStack = redoStack,super._();
  

 final  Project project;
 final  Uint8List overview;
 final  int binFrames;
@JsonKey() final  int playheadSample;
/// 1× fits ~30 s on screen; the design's default is 4×.
@JsonKey() final  double zoom;
@JsonKey() final  bool snap;
@JsonKey() final  bool clicks;
@JsonKey() final  double speed;
@JsonKey() final  bool playing;
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
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorReady&&(identical(other.project, project) || other.project == project)&&const DeepCollectionEquality().equals(other.overview, overview)&&(identical(other.binFrames, binFrames) || other.binFrames == binFrames)&&(identical(other.playheadSample, playheadSample) || other.playheadSample == playheadSample)&&(identical(other.zoom, zoom) || other.zoom == zoom)&&(identical(other.snap, snap) || other.snap == snap)&&(identical(other.clicks, clicks) || other.clicks == clicks)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&const DeepCollectionEquality().equals(other.undoStack, _undoStack)&&const DeepCollectionEquality().equals(other.redoStack, _redoStack)&&(identical(other.saveError, saveError) || other.saveError == saveError));
}


@override
int get hashCode {
    return Object.hash(runtimeType,project,const DeepCollectionEquality().hash(overview),binFrames,playheadSample,zoom,snap,clicks,speed,playing,tool,selectedIndex,const DeepCollectionEquality().hash(_undoStack),const DeepCollectionEquality().hash(_redoStack),saveError);
}

@override
String toString() {
    return 'BeatEditorState.ready(project: $project, overview: $overview, binFrames: $binFrames, playheadSample: $playheadSample, zoom: $zoom, snap: $snap, clicks: $clicks, speed: $speed, playing: $playing, tool: $tool, selectedIndex: $selectedIndex, undoStack: $undoStack, redoStack: $redoStack, saveError: $saveError)';
}


}

/// @nodoc
abstract mixin class $BeatEditorReadyCopyWith<$Res> implements $BeatEditorStateCopyWith<$Res> {
  factory $BeatEditorReadyCopyWith(BeatEditorReady value, $Res Function(BeatEditorReady) _then) = _$BeatEditorReadyCopyWithImpl;
@useResult
$Res call({
 Project project, Uint8List overview, int binFrames, int playheadSample, double zoom, bool snap, bool clicks, double speed, bool playing, EditorTool tool, int? selectedIndex, List<List<Beat>> undoStack, List<List<Beat>> redoStack, String? saveError
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
@pragma('vm:prefer-inline') $Res call({Object? project = null,Object? overview = null,Object? binFrames = null,Object? playheadSample = null,Object? zoom = null,Object? snap = null,Object? clicks = null,Object? speed = null,Object? playing = null,Object? tool = null,Object? selectedIndex = freezed,Object? undoStack = null,Object? redoStack = null,Object? saveError = freezed,}) {
  return _then(BeatEditorReady(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as Project,overview: null == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as Uint8List,binFrames: null == binFrames ? _self.binFrames : binFrames // ignore: cast_nullable_to_non_nullable
as int,playheadSample: null == playheadSample ? _self.playheadSample : playheadSample // ignore: cast_nullable_to_non_nullable
as int,zoom: null == zoom ? _self.zoom : zoom // ignore: cast_nullable_to_non_nullable
as double,snap: null == snap ? _self.snap : snap // ignore: cast_nullable_to_non_nullable
as bool,clicks: null == clicks ? _self.clicks : clicks // ignore: cast_nullable_to_non_nullable
as bool,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
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


class BeatEditorError extends BeatEditorState {
  const BeatEditorError({required this.error}): super._();
  

 final  String error;

/// Create a copy of BeatEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeatEditorErrorCopyWith<BeatEditorError> get copyWith => _$BeatEditorErrorCopyWithImpl<BeatEditorError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatEditorError&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString() {
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
