// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectSummary {

 String get id; String get title; int get beatCount; double? get bpm; int get sampleRate; int get sampleCount; DateTime get updatedAt; List<int> get thumbnail;
/// Create a copy of ProjectSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSummaryCopyWith<ProjectSummary> get copyWith => _$ProjectSummaryCopyWithImpl<ProjectSummary>(this as ProjectSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProjectSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.beatCount, _this.beatCount) || other.beatCount == _this.beatCount)&&(identical(other.bpm, _this.bpm) || other.bpm == _this.bpm)&&(identical(other.sampleRate, _this.sampleRate) || other.sampleRate == _this.sampleRate)&&(identical(other.sampleCount, _this.sampleCount) || other.sampleCount == _this.sampleCount)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&const DeepCollectionEquality().equals(other.thumbnail, _this.thumbnail));
}


@override
int get hashCode {
  final _this = this as ProjectSummary;
  return Object.hash(runtimeType,_this.id,_this.title,_this.beatCount,_this.bpm,_this.sampleRate,_this.sampleCount,_this.updatedAt,const DeepCollectionEquality().hash(_this.thumbnail));
}

@override
String toString() {
  final _this = this as ProjectSummary;
  return 'ProjectSummary(id: ${_this.id}, title: ${_this.title}, beatCount: ${_this.beatCount}, bpm: ${_this.bpm}, sampleRate: ${_this.sampleRate}, sampleCount: ${_this.sampleCount}, updatedAt: ${_this.updatedAt}, thumbnail: ${_this.thumbnail})';
}


}

/// @nodoc
abstract mixin class $ProjectSummaryCopyWith<$Res>  {
  factory $ProjectSummaryCopyWith(ProjectSummary value, $Res Function(ProjectSummary) _then) = _$ProjectSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String title, int beatCount, double? bpm, int sampleRate, int sampleCount, DateTime updatedAt, List<int> thumbnail
});




}
/// @nodoc
class _$ProjectSummaryCopyWithImpl<$Res>
    implements $ProjectSummaryCopyWith<$Res> {
  _$ProjectSummaryCopyWithImpl(this._self, this._then);

  final ProjectSummary _self;
  final $Res Function(ProjectSummary) _then;

/// Create a copy of ProjectSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? beatCount = null,Object? bpm = freezed,Object? sampleRate = null,Object? sampleCount = null,Object? updatedAt = null,Object? thumbnail = null,}) {
  return _then(ProjectSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,beatCount: null == beatCount ? _self.beatCount : beatCount // ignore: cast_nullable_to_non_nullable
as int,bpm: freezed == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double?,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,thumbnail: null == thumbnail ? _self.thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectSummary].
extension ProjectSummaryPatterns on ProjectSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSummary value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  int beatCount,  double? bpm,  int sampleRate,  int sampleCount,  DateTime updatedAt,  List<int> thumbnail)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSummary() when $default != null:
return $default(_that.id,_that.title,_that.beatCount,_that.bpm,_that.sampleRate,_that.sampleCount,_that.updatedAt,_that.thumbnail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  int beatCount,  double? bpm,  int sampleRate,  int sampleCount,  DateTime updatedAt,  List<int> thumbnail)  $default,) {final _that = this;
switch (_that) {
case _ProjectSummary():
return $default(_that.id,_that.title,_that.beatCount,_that.bpm,_that.sampleRate,_that.sampleCount,_that.updatedAt,_that.thumbnail);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  int beatCount,  double? bpm,  int sampleRate,  int sampleCount,  DateTime updatedAt,  List<int> thumbnail)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSummary() when $default != null:
return $default(_that.id,_that.title,_that.beatCount,_that.bpm,_that.sampleRate,_that.sampleCount,_that.updatedAt,_that.thumbnail);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectSummary extends ProjectSummary {
  const _ProjectSummary({required this.id, required this.title, required this.beatCount, this.bpm, required this.sampleRate, required this.sampleCount, required this.updatedAt,  List<int> thumbnail = const <int>[]}): _thumbnail = thumbnail,super._();
  

@override final  String id;
@override final  String title;
@override final  int beatCount;
@override final  double? bpm;
@override final  int sampleRate;
@override final  int sampleCount;
@override final  DateTime updatedAt;
 final  List<int> _thumbnail;
@override@JsonKey() List<int> get thumbnail {
  if (_thumbnail is EqualUnmodifiableListView) return _thumbnail;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_thumbnail);
}


/// Create a copy of ProjectSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSummaryCopyWith<_ProjectSummary> get copyWith => __$ProjectSummaryCopyWithImpl<_ProjectSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.beatCount, beatCount) || other.beatCount == beatCount)&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.thumbnail, _thumbnail));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,beatCount,bpm,sampleRate,sampleCount,updatedAt,const DeepCollectionEquality().hash(_thumbnail));
}

@override
String toString() {
    return 'ProjectSummary(id: $id, title: $title, beatCount: $beatCount, bpm: $bpm, sampleRate: $sampleRate, sampleCount: $sampleCount, updatedAt: $updatedAt, thumbnail: $thumbnail)';
}


}

/// @nodoc
abstract mixin class _$ProjectSummaryCopyWith<$Res> implements $ProjectSummaryCopyWith<$Res> {
  factory _$ProjectSummaryCopyWith(_ProjectSummary value, $Res Function(_ProjectSummary) _then) = __$ProjectSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, int beatCount, double? bpm, int sampleRate, int sampleCount, DateTime updatedAt, List<int> thumbnail
});




}
/// @nodoc
class __$ProjectSummaryCopyWithImpl<$Res>
    implements _$ProjectSummaryCopyWith<$Res> {
  __$ProjectSummaryCopyWithImpl(this._self, this._then);

  final _ProjectSummary _self;
  final $Res Function(_ProjectSummary) _then;

/// Create a copy of ProjectSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? beatCount = null,Object? bpm = freezed,Object? sampleRate = null,Object? sampleCount = null,Object? updatedAt = null,Object? thumbnail = null,}) {
  return _then(_ProjectSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,beatCount: null == beatCount ? _self.beatCount : beatCount // ignore: cast_nullable_to_non_nullable
as int,bpm: freezed == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double?,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,thumbnail: null == thumbnail ? _self._thumbnail : thumbnail // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on
