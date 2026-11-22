// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'import_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImportState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ImportState()';
}


}

/// @nodoc
class $ImportStateCopyWith<$Res>  {
$ImportStateCopyWith(ImportState _, $Res Function(ImportState) __);
}


/// Adds pattern-matching-related methods to [ImportState].
extension ImportStatePatterns on ImportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ImportImporting value)?  importing,TResult Function( ImportDone value)?  done,TResult Function( ImportFailed value)?  failed,TResult Function( ImportCancelledState value)?  cancelled,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ImportImporting() when importing != null:
return importing(_that);case ImportDone() when done != null:
return done(_that);case ImportFailed() when failed != null:
return failed(_that);case ImportCancelledState() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ImportImporting value)  importing,required TResult Function( ImportDone value)  done,required TResult Function( ImportFailed value)  failed,required TResult Function( ImportCancelledState value)  cancelled,}){
final _that = this;
switch (_that) {
case ImportImporting():
return importing(_that);case ImportDone():
return done(_that);case ImportFailed():
return failed(_that);case ImportCancelledState():
return cancelled(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ImportImporting value)?  importing,TResult? Function( ImportDone value)?  done,TResult? Function( ImportFailed value)?  failed,TResult? Function( ImportCancelledState value)?  cancelled,}){
final _that = this;
switch (_that) {
case ImportImporting() when importing != null:
return importing(_that);case ImportDone() when done != null:
return done(_that);case ImportFailed() when failed != null:
return failed(_that);case ImportCancelledState() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( PickedSource source,  double progress)?  importing,TResult Function( ImportedSong song)?  done,TResult Function( ImportFailure failure)?  failed,TResult Function()?  cancelled,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ImportImporting() when importing != null:
return importing(_that.source,_that.progress);case ImportDone() when done != null:
return done(_that.song);case ImportFailed() when failed != null:
return failed(_that.failure);case ImportCancelledState() when cancelled != null:
return cancelled();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( PickedSource source,  double progress)  importing,required TResult Function( ImportedSong song)  done,required TResult Function( ImportFailure failure)  failed,required TResult Function()  cancelled,}) {final _that = this;
switch (_that) {
case ImportImporting():
return importing(_that.source,_that.progress);case ImportDone():
return done(_that.song);case ImportFailed():
return failed(_that.failure);case ImportCancelledState():
return cancelled();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( PickedSource source,  double progress)?  importing,TResult? Function( ImportedSong song)?  done,TResult? Function( ImportFailure failure)?  failed,TResult? Function()?  cancelled,}) {final _that = this;
switch (_that) {
case ImportImporting() when importing != null:
return importing(_that.source,_that.progress);case ImportDone() when done != null:
return done(_that.song);case ImportFailed() when failed != null:
return failed(_that.failure);case ImportCancelledState() when cancelled != null:
return cancelled();case _:
  return null;

}
}

}

/// @nodoc


class ImportImporting implements ImportState {
  const ImportImporting({required this.source, this.progress = 0.0});
  

 final  PickedSource source;
@JsonKey() final  double progress;

/// Create a copy of ImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportImportingCopyWith<ImportImporting> get copyWith => _$ImportImportingCopyWithImpl<ImportImporting>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportImporting&&(identical(other.source, source) || other.source == source)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source,progress);
}

@override
String toString() {
    return 'ImportState.importing(source: $source, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $ImportImportingCopyWith<$Res> implements $ImportStateCopyWith<$Res> {
  factory $ImportImportingCopyWith(ImportImporting value, $Res Function(ImportImporting) _then) = _$ImportImportingCopyWithImpl;
@useResult
$Res call({
 PickedSource source, double progress
});


$PickedSourceCopyWith<$Res> get source;

}
/// @nodoc
class _$ImportImportingCopyWithImpl<$Res>
    implements $ImportImportingCopyWith<$Res> {
  _$ImportImportingCopyWithImpl(this._self, this._then);

  final ImportImporting _self;
  final $Res Function(ImportImporting) _then;

/// Create a copy of ImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? progress = null,}) {
  return _then(ImportImporting(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PickedSource,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of ImportState
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


class ImportDone implements ImportState {
  const ImportDone(this.song);
  

 final  ImportedSong song;

/// Create a copy of ImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportDoneCopyWith<ImportDone> get copyWith => _$ImportDoneCopyWithImpl<ImportDone>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportDone&&(identical(other.song, song) || other.song == song));
}


@override
int get hashCode {
    return Object.hash(runtimeType,song);
}

@override
String toString() {
    return 'ImportState.done(song: $song)';
}


}

/// @nodoc
abstract mixin class $ImportDoneCopyWith<$Res> implements $ImportStateCopyWith<$Res> {
  factory $ImportDoneCopyWith(ImportDone value, $Res Function(ImportDone) _then) = _$ImportDoneCopyWithImpl;
@useResult
$Res call({
 ImportedSong song
});


$ImportedSongCopyWith<$Res> get song;

}
/// @nodoc
class _$ImportDoneCopyWithImpl<$Res>
    implements $ImportDoneCopyWith<$Res> {
  _$ImportDoneCopyWithImpl(this._self, this._then);

  final ImportDone _self;
  final $Res Function(ImportDone) _then;

/// Create a copy of ImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? song = null,}) {
  return _then(ImportDone(
null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as ImportedSong,
  ));
}

/// Create a copy of ImportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ImportedSongCopyWith<$Res> get song {
  
  return $ImportedSongCopyWith<$Res>(_self.song, (value) {
    return _then(_self.copyWith(song: value));
  });
}
}

/// @nodoc


class ImportFailed implements ImportState {
  const ImportFailed(this.failure);
  

 final  ImportFailure failure;

/// Create a copy of ImportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportFailedCopyWith<ImportFailed> get copyWith => _$ImportFailedCopyWithImpl<ImportFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportFailed&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure);
}

@override
String toString() {
    return 'ImportState.failed(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $ImportFailedCopyWith<$Res> implements $ImportStateCopyWith<$Res> {
  factory $ImportFailedCopyWith(ImportFailed value, $Res Function(ImportFailed) _then) = _$ImportFailedCopyWithImpl;
@useResult
$Res call({
 ImportFailure failure
});




}
/// @nodoc
class _$ImportFailedCopyWithImpl<$Res>
    implements $ImportFailedCopyWith<$Res> {
  _$ImportFailedCopyWithImpl(this._self, this._then);

  final ImportFailed _self;
  final $Res Function(ImportFailed) _then;

/// Create a copy of ImportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(ImportFailed(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ImportFailure,
  ));
}


}

/// @nodoc


class ImportCancelledState implements ImportState {
  const ImportCancelledState();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportCancelledState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ImportState.cancelled()';
}


}




// dart format on
