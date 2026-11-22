// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'picked_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PickedSource {

 ImportSourceKind get kind;/// A local file path, a `content://` URI (Android) or an
/// `ipod-library://` URL (iOS music library).
 String get location;/// What to show the user, e.g. `Midnight Run.m4a`.
 String get displayName;/// Known up front for library tracks; otherwise null until decoded.
 int? get durationMs;
/// Create a copy of PickedSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PickedSourceCopyWith<PickedSource> get copyWith => _$PickedSourceCopyWithImpl<PickedSource>(this as PickedSource, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PickedSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PickedSource&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.location, _this.location) || other.location == _this.location)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs));
}


@override
int get hashCode {
  final _this = this as PickedSource;
  return Object.hash(runtimeType,_this.kind,_this.location,_this.displayName,_this.durationMs);
}

@override
String toString() {
  final _this = this as PickedSource;
  return 'PickedSource(kind: ${_this.kind}, location: ${_this.location}, displayName: ${_this.displayName}, durationMs: ${_this.durationMs})';
}


}

/// @nodoc
abstract mixin class $PickedSourceCopyWith<$Res>  {
  factory $PickedSourceCopyWith(PickedSource value, $Res Function(PickedSource) _then) = _$PickedSourceCopyWithImpl;
@useResult
$Res call({
 ImportSourceKind kind, String location, String displayName, int? durationMs
});




}
/// @nodoc
class _$PickedSourceCopyWithImpl<$Res>
    implements $PickedSourceCopyWith<$Res> {
  _$PickedSourceCopyWithImpl(this._self, this._then);

  final PickedSource _self;
  final $Res Function(PickedSource) _then;

/// Create a copy of PickedSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? location = null,Object? displayName = null,Object? durationMs = freezed,}) {
  return _then(PickedSource(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ImportSourceKind,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PickedSource].
extension PickedSourcePatterns on PickedSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PickedSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PickedSource() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PickedSource value)  $default,){
final _that = this;
switch (_that) {
case _PickedSource():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PickedSource value)?  $default,){
final _that = this;
switch (_that) {
case _PickedSource() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ImportSourceKind kind,  String location,  String displayName,  int? durationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PickedSource() when $default != null:
return $default(_that.kind,_that.location,_that.displayName,_that.durationMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ImportSourceKind kind,  String location,  String displayName,  int? durationMs)  $default,) {final _that = this;
switch (_that) {
case _PickedSource():
return $default(_that.kind,_that.location,_that.displayName,_that.durationMs);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ImportSourceKind kind,  String location,  String displayName,  int? durationMs)?  $default,) {final _that = this;
switch (_that) {
case _PickedSource() when $default != null:
return $default(_that.kind,_that.location,_that.displayName,_that.durationMs);case _:
  return null;

}
}

}

/// @nodoc


class _PickedSource extends PickedSource {
  const _PickedSource({required this.kind, required this.location, required this.displayName, this.durationMs}): super._();
  

@override final  ImportSourceKind kind;
/// A local file path, a `content://` URI (Android) or an
/// `ipod-library://` URL (iOS music library).
@override final  String location;
/// What to show the user, e.g. `Midnight Run.m4a`.
@override final  String displayName;
/// Known up front for library tracks; otherwise null until decoded.
@override final  int? durationMs;

/// Create a copy of PickedSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PickedSourceCopyWith<_PickedSource> get copyWith => __$PickedSourceCopyWithImpl<_PickedSource>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PickedSource&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.location, location) || other.location == location)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,location,displayName,durationMs);
}

@override
String toString() {
    return 'PickedSource(kind: $kind, location: $location, displayName: $displayName, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class _$PickedSourceCopyWith<$Res> implements $PickedSourceCopyWith<$Res> {
  factory _$PickedSourceCopyWith(_PickedSource value, $Res Function(_PickedSource) _then) = __$PickedSourceCopyWithImpl;
@override @useResult
$Res call({
 ImportSourceKind kind, String location, String displayName, int? durationMs
});




}
/// @nodoc
class __$PickedSourceCopyWithImpl<$Res>
    implements _$PickedSourceCopyWith<$Res> {
  __$PickedSourceCopyWithImpl(this._self, this._then);

  final _PickedSource _self;
  final $Res Function(_PickedSource) _then;

/// Create a copy of PickedSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? location = null,Object? displayName = null,Object? durationMs = freezed,}) {
  return _then(_PickedSource(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ImportSourceKind,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
