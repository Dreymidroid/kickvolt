// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detection_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DetectionSettings {

 double get sensitivity; BeatFilter get filter; DetectionStatus get status;
/// Create a copy of DetectionSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionSettingsCopyWith<DetectionSettings> get copyWith => _$DetectionSettingsCopyWithImpl<DetectionSettings>(this as DetectionSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DetectionSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionSettings&&(identical(other.sensitivity, _this.sensitivity) || other.sensitivity == _this.sensitivity)&&(identical(other.filter, _this.filter) || other.filter == _this.filter)&&(identical(other.status, _this.status) || other.status == _this.status));
}


@override
int get hashCode {
  final _this = this as DetectionSettings;
  return Object.hash(runtimeType,_this.sensitivity,_this.filter,_this.status);
}

@override
String toString() {
  final _this = this as DetectionSettings;
  return 'DetectionSettings(sensitivity: ${_this.sensitivity}, filter: ${_this.filter}, status: ${_this.status})';
}


}

/// @nodoc
abstract mixin class $DetectionSettingsCopyWith<$Res>  {
  factory $DetectionSettingsCopyWith(DetectionSettings value, $Res Function(DetectionSettings) _then) = _$DetectionSettingsCopyWithImpl;
@useResult
$Res call({
 double sensitivity, BeatFilter filter, DetectionStatus status
});




}
/// @nodoc
class _$DetectionSettingsCopyWithImpl<$Res>
    implements $DetectionSettingsCopyWith<$Res> {
  _$DetectionSettingsCopyWithImpl(this._self, this._then);

  final DetectionSettings _self;
  final $Res Function(DetectionSettings) _then;

/// Create a copy of DetectionSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sensitivity = null,Object? filter = null,Object? status = null,}) {
  return _then(DetectionSettings(
sensitivity: null == sensitivity ? _self.sensitivity : sensitivity // ignore: cast_nullable_to_non_nullable
as double,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as BeatFilter,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DetectionStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [DetectionSettings].
extension DetectionSettingsPatterns on DetectionSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetectionSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetectionSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetectionSettings value)  $default,){
final _that = this;
switch (_that) {
case _DetectionSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetectionSettings value)?  $default,){
final _that = this;
switch (_that) {
case _DetectionSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double sensitivity,  BeatFilter filter,  DetectionStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetectionSettings() when $default != null:
return $default(_that.sensitivity,_that.filter,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double sensitivity,  BeatFilter filter,  DetectionStatus status)  $default,) {final _that = this;
switch (_that) {
case _DetectionSettings():
return $default(_that.sensitivity,_that.filter,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double sensitivity,  BeatFilter filter,  DetectionStatus status)?  $default,) {final _that = this;
switch (_that) {
case _DetectionSettings() when $default != null:
return $default(_that.sensitivity,_that.filter,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _DetectionSettings implements DetectionSettings {
  const _DetectionSettings({this.sensitivity = 0.5, this.filter = BeatFilter.every, this.status = DetectionStatus.notRun});
  

@override@JsonKey() final  double sensitivity;
@override@JsonKey() final  BeatFilter filter;
@override@JsonKey() final  DetectionStatus status;

/// Create a copy of DetectionSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetectionSettingsCopyWith<_DetectionSettings> get copyWith => __$DetectionSettingsCopyWithImpl<_DetectionSettings>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetectionSettings&&(identical(other.sensitivity, sensitivity) || other.sensitivity == sensitivity)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sensitivity,filter,status);
}

@override
String toString() {
    return 'DetectionSettings(sensitivity: $sensitivity, filter: $filter, status: $status)';
}


}

/// @nodoc
abstract mixin class _$DetectionSettingsCopyWith<$Res> implements $DetectionSettingsCopyWith<$Res> {
  factory _$DetectionSettingsCopyWith(_DetectionSettings value, $Res Function(_DetectionSettings) _then) = __$DetectionSettingsCopyWithImpl;
@override @useResult
$Res call({
 double sensitivity, BeatFilter filter, DetectionStatus status
});




}
/// @nodoc
class __$DetectionSettingsCopyWithImpl<$Res>
    implements _$DetectionSettingsCopyWith<$Res> {
  __$DetectionSettingsCopyWithImpl(this._self, this._then);

  final _DetectionSettings _self;
  final $Res Function(_DetectionSettings) _then;

/// Create a copy of DetectionSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sensitivity = null,Object? filter = null,Object? status = null,}) {
  return _then(_DetectionSettings(
sensitivity: null == sensitivity ? _self.sensitivity : sensitivity // ignore: cast_nullable_to_non_nullable
as double,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as BeatFilter,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DetectionStatus,
  ));
}


}

// dart format on
