// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Project {

 String get id; String get title; ProjectSource get source; int get sampleRate; int get channels;/// Sample frames in `song.wav` — the master timebase.
 int get sampleCount; List<Beat> get beats; List<Section> get sections; double? get bpm; int? get beatPhaseSample; DetectionSettings get detection; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Project;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.sampleRate, _this.sampleRate) || other.sampleRate == _this.sampleRate)&&(identical(other.channels, _this.channels) || other.channels == _this.channels)&&(identical(other.sampleCount, _this.sampleCount) || other.sampleCount == _this.sampleCount)&&const DeepCollectionEquality().equals(other.beats, _this.beats)&&const DeepCollectionEquality().equals(other.sections, _this.sections)&&(identical(other.bpm, _this.bpm) || other.bpm == _this.bpm)&&(identical(other.beatPhaseSample, _this.beatPhaseSample) || other.beatPhaseSample == _this.beatPhaseSample)&&(identical(other.detection, _this.detection) || other.detection == _this.detection)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as Project;
  return Object.hash(runtimeType,_this.id,_this.title,_this.source,_this.sampleRate,_this.channels,_this.sampleCount,const DeepCollectionEquality().hash(_this.beats),const DeepCollectionEquality().hash(_this.sections),_this.bpm,_this.beatPhaseSample,_this.detection,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Project;
  return 'Project(id: ${_this.id}, title: ${_this.title}, source: ${_this.source}, sampleRate: ${_this.sampleRate}, channels: ${_this.channels}, sampleCount: ${_this.sampleCount}, beats: ${_this.beats}, sections: ${_this.sections}, bpm: ${_this.bpm}, beatPhaseSample: ${_this.beatPhaseSample}, detection: ${_this.detection}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String title, ProjectSource source, int sampleRate, int channels, int sampleCount, List<Beat> beats, List<Section> sections, double? bpm, int? beatPhaseSample, DetectionSettings detection, DateTime createdAt, DateTime updatedAt
});


$ProjectSourceCopyWith<$Res> get source;$DetectionSettingsCopyWith<$Res> get detection;

}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? source = null,Object? sampleRate = null,Object? channels = null,Object? sampleCount = null,Object? beats = null,Object? sections = null,Object? bpm = freezed,Object? beatPhaseSample = freezed,Object? detection = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ProjectSource,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,beats: null == beats ? _self.beats : beats // ignore: cast_nullable_to_non_nullable
as List<Beat>,sections: null == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as List<Section>,bpm: freezed == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double?,beatPhaseSample: freezed == beatPhaseSample ? _self.beatPhaseSample : beatPhaseSample // ignore: cast_nullable_to_non_nullable
as int?,detection: null == detection ? _self.detection : detection // ignore: cast_nullable_to_non_nullable
as DetectionSettings,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSourceCopyWith<$Res> get source {
  
  return $ProjectSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetectionSettingsCopyWith<$Res> get detection {
  
  return $DetectionSettingsCopyWith<$Res>(_self.detection, (value) {
    return _then(_self.copyWith(detection: value));
  });
}
}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  ProjectSource source,  int sampleRate,  int channels,  int sampleCount,  List<Beat> beats,  List<Section> sections,  double? bpm,  int? beatPhaseSample,  DetectionSettings detection,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.title,_that.source,_that.sampleRate,_that.channels,_that.sampleCount,_that.beats,_that.sections,_that.bpm,_that.beatPhaseSample,_that.detection,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  ProjectSource source,  int sampleRate,  int channels,  int sampleCount,  List<Beat> beats,  List<Section> sections,  double? bpm,  int? beatPhaseSample,  DetectionSettings detection,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.title,_that.source,_that.sampleRate,_that.channels,_that.sampleCount,_that.beats,_that.sections,_that.bpm,_that.beatPhaseSample,_that.detection,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  ProjectSource source,  int sampleRate,  int channels,  int sampleCount,  List<Beat> beats,  List<Section> sections,  double? bpm,  int? beatPhaseSample,  DetectionSettings detection,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.title,_that.source,_that.sampleRate,_that.channels,_that.sampleCount,_that.beats,_that.sections,_that.bpm,_that.beatPhaseSample,_that.detection,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Project extends Project {
  const _Project({required this.id, required this.title, required this.source, required this.sampleRate, required this.channels, required this.sampleCount,  List<Beat> beats = const <Beat>[],  List<Section> sections = const <Section>[], this.bpm, this.beatPhaseSample, this.detection = const DetectionSettings(), required this.createdAt, required this.updatedAt}): _beats = beats,_sections = sections,super._();
  

@override final  String id;
@override final  String title;
@override final  ProjectSource source;
@override final  int sampleRate;
@override final  int channels;
/// Sample frames in `song.wav` — the master timebase.
@override final  int sampleCount;
 final  List<Beat> _beats;
@override@JsonKey() List<Beat> get beats {
  if (_beats is EqualUnmodifiableListView) return _beats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_beats);
}

 final  List<Section> _sections;
@override@JsonKey() List<Section> get sections {
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sections);
}

@override final  double? bpm;
@override final  int? beatPhaseSample;
@override@JsonKey() final  DetectionSettings detection;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.source, source) || other.source == source)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount)&&const DeepCollectionEquality().equals(other.beats, _beats)&&const DeepCollectionEquality().equals(other.sections, _sections)&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.beatPhaseSample, beatPhaseSample) || other.beatPhaseSample == beatPhaseSample)&&(identical(other.detection, detection) || other.detection == detection)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,source,sampleRate,channels,sampleCount,const DeepCollectionEquality().hash(_beats),const DeepCollectionEquality().hash(_sections),bpm,beatPhaseSample,detection,createdAt,updatedAt);
}

@override
String toString() {
    return 'Project(id: $id, title: $title, source: $source, sampleRate: $sampleRate, channels: $channels, sampleCount: $sampleCount, beats: $beats, sections: $sections, bpm: $bpm, beatPhaseSample: $beatPhaseSample, detection: $detection, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, ProjectSource source, int sampleRate, int channels, int sampleCount, List<Beat> beats, List<Section> sections, double? bpm, int? beatPhaseSample, DetectionSettings detection, DateTime createdAt, DateTime updatedAt
});


@override $ProjectSourceCopyWith<$Res> get source;@override $DetectionSettingsCopyWith<$Res> get detection;

}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? source = null,Object? sampleRate = null,Object? channels = null,Object? sampleCount = null,Object? beats = null,Object? sections = null,Object? bpm = freezed,Object? beatPhaseSample = freezed,Object? detection = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ProjectSource,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,beats: null == beats ? _self._beats : beats // ignore: cast_nullable_to_non_nullable
as List<Beat>,sections: null == sections ? _self._sections : sections // ignore: cast_nullable_to_non_nullable
as List<Section>,bpm: freezed == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double?,beatPhaseSample: freezed == beatPhaseSample ? _self.beatPhaseSample : beatPhaseSample // ignore: cast_nullable_to_non_nullable
as int?,detection: null == detection ? _self.detection : detection // ignore: cast_nullable_to_non_nullable
as DetectionSettings,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSourceCopyWith<$Res> get source {
  
  return $ProjectSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetectionSettingsCopyWith<$Res> get detection {
  
  return $DetectionSettingsCopyWith<$Res>(_self.detection, (value) {
    return _then(_self.copyWith(detection: value));
  });
}
}

// dart format on
