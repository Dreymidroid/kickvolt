// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'beat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Beat {

 int get timeMs; BeatType get type;
/// Create a copy of Beat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeatCopyWith<Beat> get copyWith => _$BeatCopyWithImpl<Beat>(this as Beat, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Beat;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Beat&&(identical(other.timeMs, _this.timeMs) || other.timeMs == _this.timeMs)&&(identical(other.type, _this.type) || other.type == _this.type));
}


@override
int get hashCode {
  final _this = this as Beat;
  return Object.hash(runtimeType,_this.timeMs,_this.type);
}

@override
String toString() {
  final _this = this as Beat;
  return 'Beat(timeMs: ${_this.timeMs}, type: ${_this.type})';
}


}

/// @nodoc
abstract mixin class $BeatCopyWith<$Res>  {
  factory $BeatCopyWith(Beat value, $Res Function(Beat) _then) = _$BeatCopyWithImpl;
@useResult
$Res call({
 int timeMs, BeatType type
});




}
/// @nodoc
class _$BeatCopyWithImpl<$Res>
    implements $BeatCopyWith<$Res> {
  _$BeatCopyWithImpl(this._self, this._then);

  final Beat _self;
  final $Res Function(Beat) _then;

/// Create a copy of Beat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timeMs = null,Object? type = null,}) {
  return _then(Beat(
timeMs: null == timeMs ? _self.timeMs : timeMs // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BeatType,
  ));
}

}


/// Adds pattern-matching-related methods to [Beat].
extension BeatPatterns on Beat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Beat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Beat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Beat value)  $default,){
final _that = this;
switch (_that) {
case _Beat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Beat value)?  $default,){
final _that = this;
switch (_that) {
case _Beat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timeMs,  BeatType type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Beat() when $default != null:
return $default(_that.timeMs,_that.type);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timeMs,  BeatType type)  $default,) {final _that = this;
switch (_that) {
case _Beat():
return $default(_that.timeMs,_that.type);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timeMs,  BeatType type)?  $default,) {final _that = this;
switch (_that) {
case _Beat() when $default != null:
return $default(_that.timeMs,_that.type);case _:
  return null;

}
}

}

/// @nodoc


class _Beat implements Beat {
  const _Beat({required this.timeMs, this.type = BeatType.beat});
  

@override final  int timeMs;
@override@JsonKey() final  BeatType type;

/// Create a copy of Beat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BeatCopyWith<_Beat> get copyWith => __$BeatCopyWithImpl<_Beat>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Beat&&(identical(other.timeMs, timeMs) || other.timeMs == timeMs)&&(identical(other.type, type) || other.type == type));
}


@override
int get hashCode {
    return Object.hash(runtimeType,timeMs,type);
}

@override
String toString() {
    return 'Beat(timeMs: $timeMs, type: $type)';
}


}

/// @nodoc
abstract mixin class _$BeatCopyWith<$Res> implements $BeatCopyWith<$Res> {
  factory _$BeatCopyWith(_Beat value, $Res Function(_Beat) _then) = __$BeatCopyWithImpl;
@override @useResult
$Res call({
 int timeMs, BeatType type
});




}
/// @nodoc
class __$BeatCopyWithImpl<$Res>
    implements _$BeatCopyWith<$Res> {
  __$BeatCopyWithImpl(this._self, this._then);

  final _Beat _self;
  final $Res Function(_Beat) _then;

/// Create a copy of Beat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timeMs = null,Object? type = null,}) {
  return _then(_Beat(
timeMs: null == timeMs ? _self.timeMs : timeMs // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BeatType,
  ));
}


}

// dart format on
