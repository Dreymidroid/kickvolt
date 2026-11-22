// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Section {

 int get startSample; int get endSample; String get name; int get colorArgb;
/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SectionCopyWith<Section> get copyWith => _$SectionCopyWithImpl<Section>(this as Section, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Section;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Section&&(identical(other.startSample, _this.startSample) || other.startSample == _this.startSample)&&(identical(other.endSample, _this.endSample) || other.endSample == _this.endSample)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.colorArgb, _this.colorArgb) || other.colorArgb == _this.colorArgb));
}


@override
int get hashCode {
  final _this = this as Section;
  return Object.hash(runtimeType,_this.startSample,_this.endSample,_this.name,_this.colorArgb);
}

@override
String toString() {
  final _this = this as Section;
  return 'Section(startSample: ${_this.startSample}, endSample: ${_this.endSample}, name: ${_this.name}, colorArgb: ${_this.colorArgb})';
}


}

/// @nodoc
abstract mixin class $SectionCopyWith<$Res>  {
  factory $SectionCopyWith(Section value, $Res Function(Section) _then) = _$SectionCopyWithImpl;
@useResult
$Res call({
 int startSample, int endSample, String name, int colorArgb
});




}
/// @nodoc
class _$SectionCopyWithImpl<$Res>
    implements $SectionCopyWith<$Res> {
  _$SectionCopyWithImpl(this._self, this._then);

  final Section _self;
  final $Res Function(Section) _then;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startSample = null,Object? endSample = null,Object? name = null,Object? colorArgb = null,}) {
  return _then(Section(
startSample: null == startSample ? _self.startSample : startSample // ignore: cast_nullable_to_non_nullable
as int,endSample: null == endSample ? _self.endSample : endSample // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colorArgb: null == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Section].
extension SectionPatterns on Section {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Section value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Section() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Section value)  $default,){
final _that = this;
switch (_that) {
case _Section():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Section value)?  $default,){
final _that = this;
switch (_that) {
case _Section() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startSample,  int endSample,  String name,  int colorArgb)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Section() when $default != null:
return $default(_that.startSample,_that.endSample,_that.name,_that.colorArgb);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startSample,  int endSample,  String name,  int colorArgb)  $default,) {final _that = this;
switch (_that) {
case _Section():
return $default(_that.startSample,_that.endSample,_that.name,_that.colorArgb);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startSample,  int endSample,  String name,  int colorArgb)?  $default,) {final _that = this;
switch (_that) {
case _Section() when $default != null:
return $default(_that.startSample,_that.endSample,_that.name,_that.colorArgb);case _:
  return null;

}
}

}

/// @nodoc


class _Section implements Section {
  const _Section({required this.startSample, required this.endSample, required this.name, required this.colorArgb});
  

@override final  int startSample;
@override final  int endSample;
@override final  String name;
@override final  int colorArgb;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SectionCopyWith<_Section> get copyWith => __$SectionCopyWithImpl<_Section>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Section&&(identical(other.startSample, startSample) || other.startSample == startSample)&&(identical(other.endSample, endSample) || other.endSample == endSample)&&(identical(other.name, name) || other.name == name)&&(identical(other.colorArgb, colorArgb) || other.colorArgb == colorArgb));
}


@override
int get hashCode {
    return Object.hash(runtimeType,startSample,endSample,name,colorArgb);
}

@override
String toString() {
    return 'Section(startSample: $startSample, endSample: $endSample, name: $name, colorArgb: $colorArgb)';
}


}

/// @nodoc
abstract mixin class _$SectionCopyWith<$Res> implements $SectionCopyWith<$Res> {
  factory _$SectionCopyWith(_Section value, $Res Function(_Section) _then) = __$SectionCopyWithImpl;
@override @useResult
$Res call({
 int startSample, int endSample, String name, int colorArgb
});




}
/// @nodoc
class __$SectionCopyWithImpl<$Res>
    implements _$SectionCopyWith<$Res> {
  __$SectionCopyWithImpl(this._self, this._then);

  final _Section _self;
  final $Res Function(_Section) _then;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startSample = null,Object? endSample = null,Object? name = null,Object? colorArgb = null,}) {
  return _then(_Section(
startSample: null == startSample ? _self.startSample : startSample // ignore: cast_nullable_to_non_nullable
as int,endSample: null == endSample ? _self.endSample : endSample // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colorArgb: null == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
