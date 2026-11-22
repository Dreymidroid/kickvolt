// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_picker_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourcePickerState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SourcePickerState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SourcePickerState()';
}


}

/// @nodoc
class $SourcePickerStateCopyWith<$Res>  {
$SourcePickerStateCopyWith(SourcePickerState _, $Res Function(SourcePickerState) __);
}


/// Adds pattern-matching-related methods to [SourcePickerState].
extension SourcePickerStatePatterns on SourcePickerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SourcePickerIdle value)?  idle,TResult Function( SourcePickerBusy value)?  busy,TResult Function( SourcePickerPicked value)?  picked,TResult Function( SourcePickerLibrary value)?  library,TResult Function( SourcePickerFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SourcePickerIdle() when idle != null:
return idle(_that);case SourcePickerBusy() when busy != null:
return busy(_that);case SourcePickerPicked() when picked != null:
return picked(_that);case SourcePickerLibrary() when library != null:
return library(_that);case SourcePickerFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SourcePickerIdle value)  idle,required TResult Function( SourcePickerBusy value)  busy,required TResult Function( SourcePickerPicked value)  picked,required TResult Function( SourcePickerLibrary value)  library,required TResult Function( SourcePickerFailed value)  failed,}){
final _that = this;
switch (_that) {
case SourcePickerIdle():
return idle(_that);case SourcePickerBusy():
return busy(_that);case SourcePickerPicked():
return picked(_that);case SourcePickerLibrary():
return library(_that);case SourcePickerFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SourcePickerIdle value)?  idle,TResult? Function( SourcePickerBusy value)?  busy,TResult? Function( SourcePickerPicked value)?  picked,TResult? Function( SourcePickerLibrary value)?  library,TResult? Function( SourcePickerFailed value)?  failed,}){
final _that = this;
switch (_that) {
case SourcePickerIdle() when idle != null:
return idle(_that);case SourcePickerBusy() when busy != null:
return busy(_that);case SourcePickerPicked() when picked != null:
return picked(_that);case SourcePickerLibrary() when library != null:
return library(_that);case SourcePickerFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  busy,TResult Function( PickedSource source)?  picked,TResult Function( List<LibraryTrack> tracks)?  library,TResult Function( ImportFailure failure)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SourcePickerIdle() when idle != null:
return idle();case SourcePickerBusy() when busy != null:
return busy();case SourcePickerPicked() when picked != null:
return picked(_that.source);case SourcePickerLibrary() when library != null:
return library(_that.tracks);case SourcePickerFailed() when failed != null:
return failed(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  busy,required TResult Function( PickedSource source)  picked,required TResult Function( List<LibraryTrack> tracks)  library,required TResult Function( ImportFailure failure)  failed,}) {final _that = this;
switch (_that) {
case SourcePickerIdle():
return idle();case SourcePickerBusy():
return busy();case SourcePickerPicked():
return picked(_that.source);case SourcePickerLibrary():
return library(_that.tracks);case SourcePickerFailed():
return failed(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  busy,TResult? Function( PickedSource source)?  picked,TResult? Function( List<LibraryTrack> tracks)?  library,TResult? Function( ImportFailure failure)?  failed,}) {final _that = this;
switch (_that) {
case SourcePickerIdle() when idle != null:
return idle();case SourcePickerBusy() when busy != null:
return busy();case SourcePickerPicked() when picked != null:
return picked(_that.source);case SourcePickerLibrary() when library != null:
return library(_that.tracks);case SourcePickerFailed() when failed != null:
return failed(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class SourcePickerIdle implements SourcePickerState {
  const SourcePickerIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SourcePickerIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SourcePickerState.idle()';
}


}




/// @nodoc


class SourcePickerBusy implements SourcePickerState {
  const SourcePickerBusy();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SourcePickerBusy);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SourcePickerState.busy()';
}


}




/// @nodoc


class SourcePickerPicked implements SourcePickerState {
  const SourcePickerPicked(this.source);
  

 final  PickedSource source;

/// Create a copy of SourcePickerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourcePickerPickedCopyWith<SourcePickerPicked> get copyWith => _$SourcePickerPickedCopyWithImpl<SourcePickerPicked>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SourcePickerPicked&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source);
}

@override
String toString() {
    return 'SourcePickerState.picked(source: $source)';
}


}

/// @nodoc
abstract mixin class $SourcePickerPickedCopyWith<$Res> implements $SourcePickerStateCopyWith<$Res> {
  factory $SourcePickerPickedCopyWith(SourcePickerPicked value, $Res Function(SourcePickerPicked) _then) = _$SourcePickerPickedCopyWithImpl;
@useResult
$Res call({
 PickedSource source
});


$PickedSourceCopyWith<$Res> get source;

}
/// @nodoc
class _$SourcePickerPickedCopyWithImpl<$Res>
    implements $SourcePickerPickedCopyWith<$Res> {
  _$SourcePickerPickedCopyWithImpl(this._self, this._then);

  final SourcePickerPicked _self;
  final $Res Function(SourcePickerPicked) _then;

/// Create a copy of SourcePickerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(SourcePickerPicked(
null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PickedSource,
  ));
}

/// Create a copy of SourcePickerState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PickedSourceCopyWith<$Res> get source {
  
  return $PickedSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}

/// @nodoc


class SourcePickerLibrary implements SourcePickerState {
  const SourcePickerLibrary( List<LibraryTrack> tracks): _tracks = tracks;
  

 final  List<LibraryTrack> _tracks;
 List<LibraryTrack> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}


/// Create a copy of SourcePickerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourcePickerLibraryCopyWith<SourcePickerLibrary> get copyWith => _$SourcePickerLibraryCopyWithImpl<SourcePickerLibrary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SourcePickerLibrary&&const DeepCollectionEquality().equals(other.tracks, _tracks));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_tracks));
}

@override
String toString() {
    return 'SourcePickerState.library(tracks: $tracks)';
}


}

/// @nodoc
abstract mixin class $SourcePickerLibraryCopyWith<$Res> implements $SourcePickerStateCopyWith<$Res> {
  factory $SourcePickerLibraryCopyWith(SourcePickerLibrary value, $Res Function(SourcePickerLibrary) _then) = _$SourcePickerLibraryCopyWithImpl;
@useResult
$Res call({
 List<LibraryTrack> tracks
});




}
/// @nodoc
class _$SourcePickerLibraryCopyWithImpl<$Res>
    implements $SourcePickerLibraryCopyWith<$Res> {
  _$SourcePickerLibraryCopyWithImpl(this._self, this._then);

  final SourcePickerLibrary _self;
  final $Res Function(SourcePickerLibrary) _then;

/// Create a copy of SourcePickerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tracks = null,}) {
  return _then(SourcePickerLibrary(
null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<LibraryTrack>,
  ));
}


}

/// @nodoc


class SourcePickerFailed implements SourcePickerState {
  const SourcePickerFailed(this.failure);
  

 final  ImportFailure failure;

/// Create a copy of SourcePickerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourcePickerFailedCopyWith<SourcePickerFailed> get copyWith => _$SourcePickerFailedCopyWithImpl<SourcePickerFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SourcePickerFailed&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'SourcePickerState.failed(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $SourcePickerFailedCopyWith<$Res> implements $SourcePickerStateCopyWith<$Res> {
  factory $SourcePickerFailedCopyWith(SourcePickerFailed value, $Res Function(SourcePickerFailed) _then) = _$SourcePickerFailedCopyWithImpl;
@useResult
$Res call({
 ImportFailure failure
});




}
/// @nodoc
class _$SourcePickerFailedCopyWithImpl<$Res>
    implements $SourcePickerFailedCopyWith<$Res> {
  _$SourcePickerFailedCopyWithImpl(this._self, this._then);

  final SourcePickerFailed _self;
  final $Res Function(SourcePickerFailed) _then;

/// Create a copy of SourcePickerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(SourcePickerFailed(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ImportFailure,
  ));
}


}

// dart format on
