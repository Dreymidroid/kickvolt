// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProjectModel {

 int get schemaVersion; String get id; String get title; ProjectSourceModel get source; int get sampleRate; int get channels; int get sampleCount; List<BeatModel> get beats; List<SectionModel> get sections; double? get bpm; int? get beatPhaseSample; DetectionSettingsModel get detection; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectModelCopyWith<ProjectModel> get copyWith => _$ProjectModelCopyWithImpl<ProjectModel>(this as ProjectModel, _$identity);

  /// Serializes this ProjectModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProjectModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectModel&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.sampleRate, _this.sampleRate) || other.sampleRate == _this.sampleRate)&&(identical(other.channels, _this.channels) || other.channels == _this.channels)&&(identical(other.sampleCount, _this.sampleCount) || other.sampleCount == _this.sampleCount)&&const DeepCollectionEquality().equals(other.beats, _this.beats)&&const DeepCollectionEquality().equals(other.sections, _this.sections)&&(identical(other.bpm, _this.bpm) || other.bpm == _this.bpm)&&(identical(other.beatPhaseSample, _this.beatPhaseSample) || other.beatPhaseSample == _this.beatPhaseSample)&&(identical(other.detection, _this.detection) || other.detection == _this.detection)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProjectModel;
  return Object.hash(runtimeType,_this.schemaVersion,_this.id,_this.title,_this.source,_this.sampleRate,_this.channels,_this.sampleCount,const DeepCollectionEquality().hash(_this.beats),const DeepCollectionEquality().hash(_this.sections),_this.bpm,_this.beatPhaseSample,_this.detection,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as ProjectModel;
  return 'ProjectModel(schemaVersion: ${_this.schemaVersion}, id: ${_this.id}, title: ${_this.title}, source: ${_this.source}, sampleRate: ${_this.sampleRate}, channels: ${_this.channels}, sampleCount: ${_this.sampleCount}, beats: ${_this.beats}, sections: ${_this.sections}, bpm: ${_this.bpm}, beatPhaseSample: ${_this.beatPhaseSample}, detection: ${_this.detection}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ProjectModelCopyWith<$Res>  {
  factory $ProjectModelCopyWith(ProjectModel value, $Res Function(ProjectModel) _then) = _$ProjectModelCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String id, String title, ProjectSourceModel source, int sampleRate, int channels, int sampleCount, List<BeatModel> beats, List<SectionModel> sections, double? bpm, int? beatPhaseSample, DetectionSettingsModel detection, DateTime createdAt, DateTime updatedAt
});


$ProjectSourceModelCopyWith<$Res> get source;$DetectionSettingsModelCopyWith<$Res> get detection;

}
/// @nodoc
class _$ProjectModelCopyWithImpl<$Res>
    implements $ProjectModelCopyWith<$Res> {
  _$ProjectModelCopyWithImpl(this._self, this._then);

  final ProjectModel _self;
  final $Res Function(ProjectModel) _then;

/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? id = null,Object? title = null,Object? source = null,Object? sampleRate = null,Object? channels = null,Object? sampleCount = null,Object? beats = null,Object? sections = null,Object? bpm = freezed,Object? beatPhaseSample = freezed,Object? detection = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(ProjectModel(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ProjectSourceModel,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,beats: null == beats ? _self.beats : beats // ignore: cast_nullable_to_non_nullable
as List<BeatModel>,sections: null == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as List<SectionModel>,bpm: freezed == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double?,beatPhaseSample: freezed == beatPhaseSample ? _self.beatPhaseSample : beatPhaseSample // ignore: cast_nullable_to_non_nullable
as int?,detection: null == detection ? _self.detection : detection // ignore: cast_nullable_to_non_nullable
as DetectionSettingsModel,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSourceModelCopyWith<$Res> get source {
  
  return $ProjectSourceModelCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetectionSettingsModelCopyWith<$Res> get detection {
  
  return $DetectionSettingsModelCopyWith<$Res>(_self.detection, (value) {
    return _then(_self.copyWith(detection: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProjectModel].
extension ProjectModelPatterns on ProjectModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectModel value)  $default,){
final _that = this;
switch (_that) {
case _ProjectModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String id,  String title,  ProjectSourceModel source,  int sampleRate,  int channels,  int sampleCount,  List<BeatModel> beats,  List<SectionModel> sections,  double? bpm,  int? beatPhaseSample,  DetectionSettingsModel detection,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectModel() when $default != null:
return $default(_that.schemaVersion,_that.id,_that.title,_that.source,_that.sampleRate,_that.channels,_that.sampleCount,_that.beats,_that.sections,_that.bpm,_that.beatPhaseSample,_that.detection,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String id,  String title,  ProjectSourceModel source,  int sampleRate,  int channels,  int sampleCount,  List<BeatModel> beats,  List<SectionModel> sections,  double? bpm,  int? beatPhaseSample,  DetectionSettingsModel detection,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ProjectModel():
return $default(_that.schemaVersion,_that.id,_that.title,_that.source,_that.sampleRate,_that.channels,_that.sampleCount,_that.beats,_that.sections,_that.bpm,_that.beatPhaseSample,_that.detection,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String id,  String title,  ProjectSourceModel source,  int sampleRate,  int channels,  int sampleCount,  List<BeatModel> beats,  List<SectionModel> sections,  double? bpm,  int? beatPhaseSample,  DetectionSettingsModel detection,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ProjectModel() when $default != null:
return $default(_that.schemaVersion,_that.id,_that.title,_that.source,_that.sampleRate,_that.channels,_that.sampleCount,_that.beats,_that.sections,_that.bpm,_that.beatPhaseSample,_that.detection,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _ProjectModel implements ProjectModel {
  const _ProjectModel({this.schemaVersion = currentProjectSchemaVersion, required this.id, required this.title, required this.source, required this.sampleRate, required this.channels, required this.sampleCount,  List<BeatModel> beats = const <BeatModel>[],  List<SectionModel> sections = const <SectionModel>[], this.bpm, this.beatPhaseSample, this.detection = const DetectionSettingsModel(), required this.createdAt, required this.updatedAt}): _beats = beats,_sections = sections;
  factory _ProjectModel.fromJson(Map<String, dynamic> json) => _$ProjectModelFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override final  String id;
@override final  String title;
@override final  ProjectSourceModel source;
@override final  int sampleRate;
@override final  int channels;
@override final  int sampleCount;
 final  List<BeatModel> _beats;
@override@JsonKey() List<BeatModel> get beats {
  if (_beats is EqualUnmodifiableListView) return _beats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_beats);
}

 final  List<SectionModel> _sections;
@override@JsonKey() List<SectionModel> get sections {
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sections);
}

@override final  double? bpm;
@override final  int? beatPhaseSample;
@override@JsonKey() final  DetectionSettingsModel detection;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectModelCopyWith<_ProjectModel> get copyWith => __$ProjectModelCopyWithImpl<_ProjectModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectModel&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.source, source) || other.source == source)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount)&&const DeepCollectionEquality().equals(other.beats, _beats)&&const DeepCollectionEquality().equals(other.sections, _sections)&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.beatPhaseSample, beatPhaseSample) || other.beatPhaseSample == beatPhaseSample)&&(identical(other.detection, detection) || other.detection == detection)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,id,title,source,sampleRate,channels,sampleCount,const DeepCollectionEquality().hash(_beats),const DeepCollectionEquality().hash(_sections),bpm,beatPhaseSample,detection,createdAt,updatedAt);
}

@override
String toString() {
    return 'ProjectModel(schemaVersion: $schemaVersion, id: $id, title: $title, source: $source, sampleRate: $sampleRate, channels: $channels, sampleCount: $sampleCount, beats: $beats, sections: $sections, bpm: $bpm, beatPhaseSample: $beatPhaseSample, detection: $detection, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ProjectModelCopyWith<$Res> implements $ProjectModelCopyWith<$Res> {
  factory _$ProjectModelCopyWith(_ProjectModel value, $Res Function(_ProjectModel) _then) = __$ProjectModelCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String id, String title, ProjectSourceModel source, int sampleRate, int channels, int sampleCount, List<BeatModel> beats, List<SectionModel> sections, double? bpm, int? beatPhaseSample, DetectionSettingsModel detection, DateTime createdAt, DateTime updatedAt
});


@override $ProjectSourceModelCopyWith<$Res> get source;@override $DetectionSettingsModelCopyWith<$Res> get detection;

}
/// @nodoc
class __$ProjectModelCopyWithImpl<$Res>
    implements _$ProjectModelCopyWith<$Res> {
  __$ProjectModelCopyWithImpl(this._self, this._then);

  final _ProjectModel _self;
  final $Res Function(_ProjectModel) _then;

/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? id = null,Object? title = null,Object? source = null,Object? sampleRate = null,Object? channels = null,Object? sampleCount = null,Object? beats = null,Object? sections = null,Object? bpm = freezed,Object? beatPhaseSample = freezed,Object? detection = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ProjectModel(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ProjectSourceModel,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,beats: null == beats ? _self._beats : beats // ignore: cast_nullable_to_non_nullable
as List<BeatModel>,sections: null == sections ? _self._sections : sections // ignore: cast_nullable_to_non_nullable
as List<SectionModel>,bpm: freezed == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as double?,beatPhaseSample: freezed == beatPhaseSample ? _self.beatPhaseSample : beatPhaseSample // ignore: cast_nullable_to_non_nullable
as int?,detection: null == detection ? _self.detection : detection // ignore: cast_nullable_to_non_nullable
as DetectionSettingsModel,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSourceModelCopyWith<$Res> get source {
  
  return $ProjectSourceModelCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}/// Create a copy of ProjectModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DetectionSettingsModelCopyWith<$Res> get detection {
  
  return $DetectionSettingsModelCopyWith<$Res>(_self.detection, (value) {
    return _then(_self.copyWith(detection: value));
  });
}
}


/// @nodoc
mixin _$ProjectSourceModel {

 ImportSourceKind get kind; String get originalName; String? get copiedFileName;
/// Create a copy of ProjectSourceModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSourceModelCopyWith<ProjectSourceModel> get copyWith => _$ProjectSourceModelCopyWithImpl<ProjectSourceModel>(this as ProjectSourceModel, _$identity);

  /// Serializes this ProjectSourceModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProjectSourceModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSourceModel&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.originalName, _this.originalName) || other.originalName == _this.originalName)&&(identical(other.copiedFileName, _this.copiedFileName) || other.copiedFileName == _this.copiedFileName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProjectSourceModel;
  return Object.hash(runtimeType,_this.kind,_this.originalName,_this.copiedFileName);
}

@override
String toString() {
  final _this = this as ProjectSourceModel;
  return 'ProjectSourceModel(kind: ${_this.kind}, originalName: ${_this.originalName}, copiedFileName: ${_this.copiedFileName})';
}


}

/// @nodoc
abstract mixin class $ProjectSourceModelCopyWith<$Res>  {
  factory $ProjectSourceModelCopyWith(ProjectSourceModel value, $Res Function(ProjectSourceModel) _then) = _$ProjectSourceModelCopyWithImpl;
@useResult
$Res call({
 ImportSourceKind kind, String originalName, String? copiedFileName
});




}
/// @nodoc
class _$ProjectSourceModelCopyWithImpl<$Res>
    implements $ProjectSourceModelCopyWith<$Res> {
  _$ProjectSourceModelCopyWithImpl(this._self, this._then);

  final ProjectSourceModel _self;
  final $Res Function(ProjectSourceModel) _then;

/// Create a copy of ProjectSourceModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? originalName = null,Object? copiedFileName = freezed,}) {
  return _then(ProjectSourceModel(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ImportSourceKind,originalName: null == originalName ? _self.originalName : originalName // ignore: cast_nullable_to_non_nullable
as String,copiedFileName: freezed == copiedFileName ? _self.copiedFileName : copiedFileName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectSourceModel].
extension ProjectSourceModelPatterns on ProjectSourceModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSourceModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSourceModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSourceModel value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSourceModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSourceModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSourceModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ImportSourceKind kind,  String originalName,  String? copiedFileName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSourceModel() when $default != null:
return $default(_that.kind,_that.originalName,_that.copiedFileName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ImportSourceKind kind,  String originalName,  String? copiedFileName)  $default,) {final _that = this;
switch (_that) {
case _ProjectSourceModel():
return $default(_that.kind,_that.originalName,_that.copiedFileName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ImportSourceKind kind,  String originalName,  String? copiedFileName)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSourceModel() when $default != null:
return $default(_that.kind,_that.originalName,_that.copiedFileName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectSourceModel implements ProjectSourceModel {
  const _ProjectSourceModel({required this.kind, required this.originalName, this.copiedFileName});
  factory _ProjectSourceModel.fromJson(Map<String, dynamic> json) => _$ProjectSourceModelFromJson(json);

@override final  ImportSourceKind kind;
@override final  String originalName;
@override final  String? copiedFileName;

/// Create a copy of ProjectSourceModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSourceModelCopyWith<_ProjectSourceModel> get copyWith => __$ProjectSourceModelCopyWithImpl<_ProjectSourceModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectSourceModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSourceModel&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.originalName, originalName) || other.originalName == originalName)&&(identical(other.copiedFileName, copiedFileName) || other.copiedFileName == copiedFileName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,originalName,copiedFileName);
}

@override
String toString() {
    return 'ProjectSourceModel(kind: $kind, originalName: $originalName, copiedFileName: $copiedFileName)';
}


}

/// @nodoc
abstract mixin class _$ProjectSourceModelCopyWith<$Res> implements $ProjectSourceModelCopyWith<$Res> {
  factory _$ProjectSourceModelCopyWith(_ProjectSourceModel value, $Res Function(_ProjectSourceModel) _then) = __$ProjectSourceModelCopyWithImpl;
@override @useResult
$Res call({
 ImportSourceKind kind, String originalName, String? copiedFileName
});




}
/// @nodoc
class __$ProjectSourceModelCopyWithImpl<$Res>
    implements _$ProjectSourceModelCopyWith<$Res> {
  __$ProjectSourceModelCopyWithImpl(this._self, this._then);

  final _ProjectSourceModel _self;
  final $Res Function(_ProjectSourceModel) _then;

/// Create a copy of ProjectSourceModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? originalName = null,Object? copiedFileName = freezed,}) {
  return _then(_ProjectSourceModel(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ImportSourceKind,originalName: null == originalName ? _self.originalName : originalName // ignore: cast_nullable_to_non_nullable
as String,copiedFileName: freezed == copiedFileName ? _self.copiedFileName : copiedFileName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$BeatModel {

 int get sample; BeatType get type;
/// Create a copy of BeatModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeatModelCopyWith<BeatModel> get copyWith => _$BeatModelCopyWithImpl<BeatModel>(this as BeatModel, _$identity);

  /// Serializes this BeatModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BeatModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatModel&&(identical(other.sample, _this.sample) || other.sample == _this.sample)&&(identical(other.type, _this.type) || other.type == _this.type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BeatModel;
  return Object.hash(runtimeType,_this.sample,_this.type);
}

@override
String toString() {
  final _this = this as BeatModel;
  return 'BeatModel(sample: ${_this.sample}, type: ${_this.type})';
}


}

/// @nodoc
abstract mixin class $BeatModelCopyWith<$Res>  {
  factory $BeatModelCopyWith(BeatModel value, $Res Function(BeatModel) _then) = _$BeatModelCopyWithImpl;
@useResult
$Res call({
 int sample, BeatType type
});




}
/// @nodoc
class _$BeatModelCopyWithImpl<$Res>
    implements $BeatModelCopyWith<$Res> {
  _$BeatModelCopyWithImpl(this._self, this._then);

  final BeatModel _self;
  final $Res Function(BeatModel) _then;

/// Create a copy of BeatModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sample = null,Object? type = null,}) {
  return _then(BeatModel(
sample: null == sample ? _self.sample : sample // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BeatType,
  ));
}

}


/// Adds pattern-matching-related methods to [BeatModel].
extension BeatModelPatterns on BeatModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BeatModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BeatModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BeatModel value)  $default,){
final _that = this;
switch (_that) {
case _BeatModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BeatModel value)?  $default,){
final _that = this;
switch (_that) {
case _BeatModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sample,  BeatType type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BeatModel() when $default != null:
return $default(_that.sample,_that.type);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sample,  BeatType type)  $default,) {final _that = this;
switch (_that) {
case _BeatModel():
return $default(_that.sample,_that.type);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sample,  BeatType type)?  $default,) {final _that = this;
switch (_that) {
case _BeatModel() when $default != null:
return $default(_that.sample,_that.type);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BeatModel implements BeatModel {
  const _BeatModel({required this.sample, this.type = BeatType.beat});
  factory _BeatModel.fromJson(Map<String, dynamic> json) => _$BeatModelFromJson(json);

@override final  int sample;
@override@JsonKey() final  BeatType type;

/// Create a copy of BeatModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BeatModelCopyWith<_BeatModel> get copyWith => __$BeatModelCopyWithImpl<_BeatModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BeatModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BeatModel&&(identical(other.sample, sample) || other.sample == sample)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sample,type);
}

@override
String toString() {
    return 'BeatModel(sample: $sample, type: $type)';
}


}

/// @nodoc
abstract mixin class _$BeatModelCopyWith<$Res> implements $BeatModelCopyWith<$Res> {
  factory _$BeatModelCopyWith(_BeatModel value, $Res Function(_BeatModel) _then) = __$BeatModelCopyWithImpl;
@override @useResult
$Res call({
 int sample, BeatType type
});




}
/// @nodoc
class __$BeatModelCopyWithImpl<$Res>
    implements _$BeatModelCopyWith<$Res> {
  __$BeatModelCopyWithImpl(this._self, this._then);

  final _BeatModel _self;
  final $Res Function(_BeatModel) _then;

/// Create a copy of BeatModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sample = null,Object? type = null,}) {
  return _then(_BeatModel(
sample: null == sample ? _self.sample : sample // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BeatType,
  ));
}


}


/// @nodoc
mixin _$SectionModel {

 int get startSample; int get endSample; String get name; int get colorArgb;
/// Create a copy of SectionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SectionModelCopyWith<SectionModel> get copyWith => _$SectionModelCopyWithImpl<SectionModel>(this as SectionModel, _$identity);

  /// Serializes this SectionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SectionModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SectionModel&&(identical(other.startSample, _this.startSample) || other.startSample == _this.startSample)&&(identical(other.endSample, _this.endSample) || other.endSample == _this.endSample)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.colorArgb, _this.colorArgb) || other.colorArgb == _this.colorArgb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SectionModel;
  return Object.hash(runtimeType,_this.startSample,_this.endSample,_this.name,_this.colorArgb);
}

@override
String toString() {
  final _this = this as SectionModel;
  return 'SectionModel(startSample: ${_this.startSample}, endSample: ${_this.endSample}, name: ${_this.name}, colorArgb: ${_this.colorArgb})';
}


}

/// @nodoc
abstract mixin class $SectionModelCopyWith<$Res>  {
  factory $SectionModelCopyWith(SectionModel value, $Res Function(SectionModel) _then) = _$SectionModelCopyWithImpl;
@useResult
$Res call({
 int startSample, int endSample, String name, int colorArgb
});




}
/// @nodoc
class _$SectionModelCopyWithImpl<$Res>
    implements $SectionModelCopyWith<$Res> {
  _$SectionModelCopyWithImpl(this._self, this._then);

  final SectionModel _self;
  final $Res Function(SectionModel) _then;

/// Create a copy of SectionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startSample = null,Object? endSample = null,Object? name = null,Object? colorArgb = null,}) {
  return _then(SectionModel(
startSample: null == startSample ? _self.startSample : startSample // ignore: cast_nullable_to_non_nullable
as int,endSample: null == endSample ? _self.endSample : endSample // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colorArgb: null == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SectionModel].
extension SectionModelPatterns on SectionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SectionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SectionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SectionModel value)  $default,){
final _that = this;
switch (_that) {
case _SectionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SectionModel value)?  $default,){
final _that = this;
switch (_that) {
case _SectionModel() when $default != null:
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
case _SectionModel() when $default != null:
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
case _SectionModel():
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
case _SectionModel() when $default != null:
return $default(_that.startSample,_that.endSample,_that.name,_that.colorArgb);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SectionModel implements SectionModel {
  const _SectionModel({required this.startSample, required this.endSample, required this.name, required this.colorArgb});
  factory _SectionModel.fromJson(Map<String, dynamic> json) => _$SectionModelFromJson(json);

@override final  int startSample;
@override final  int endSample;
@override final  String name;
@override final  int colorArgb;

/// Create a copy of SectionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SectionModelCopyWith<_SectionModel> get copyWith => __$SectionModelCopyWithImpl<_SectionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SectionModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SectionModel&&(identical(other.startSample, startSample) || other.startSample == startSample)&&(identical(other.endSample, endSample) || other.endSample == endSample)&&(identical(other.name, name) || other.name == name)&&(identical(other.colorArgb, colorArgb) || other.colorArgb == colorArgb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,startSample,endSample,name,colorArgb);
}

@override
String toString() {
    return 'SectionModel(startSample: $startSample, endSample: $endSample, name: $name, colorArgb: $colorArgb)';
}


}

/// @nodoc
abstract mixin class _$SectionModelCopyWith<$Res> implements $SectionModelCopyWith<$Res> {
  factory _$SectionModelCopyWith(_SectionModel value, $Res Function(_SectionModel) _then) = __$SectionModelCopyWithImpl;
@override @useResult
$Res call({
 int startSample, int endSample, String name, int colorArgb
});




}
/// @nodoc
class __$SectionModelCopyWithImpl<$Res>
    implements _$SectionModelCopyWith<$Res> {
  __$SectionModelCopyWithImpl(this._self, this._then);

  final _SectionModel _self;
  final $Res Function(_SectionModel) _then;

/// Create a copy of SectionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startSample = null,Object? endSample = null,Object? name = null,Object? colorArgb = null,}) {
  return _then(_SectionModel(
startSample: null == startSample ? _self.startSample : startSample // ignore: cast_nullable_to_non_nullable
as int,endSample: null == endSample ? _self.endSample : endSample // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colorArgb: null == colorArgb ? _self.colorArgb : colorArgb // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DetectionSettingsModel {

 double get sensitivity; BeatFilter get filter; DetectionStatus get status;
/// Create a copy of DetectionSettingsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectionSettingsModelCopyWith<DetectionSettingsModel> get copyWith => _$DetectionSettingsModelCopyWithImpl<DetectionSettingsModel>(this as DetectionSettingsModel, _$identity);

  /// Serializes this DetectionSettingsModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DetectionSettingsModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectionSettingsModel&&(identical(other.sensitivity, _this.sensitivity) || other.sensitivity == _this.sensitivity)&&(identical(other.filter, _this.filter) || other.filter == _this.filter)&&(identical(other.status, _this.status) || other.status == _this.status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DetectionSettingsModel;
  return Object.hash(runtimeType,_this.sensitivity,_this.filter,_this.status);
}

@override
String toString() {
  final _this = this as DetectionSettingsModel;
  return 'DetectionSettingsModel(sensitivity: ${_this.sensitivity}, filter: ${_this.filter}, status: ${_this.status})';
}


}

/// @nodoc
abstract mixin class $DetectionSettingsModelCopyWith<$Res>  {
  factory $DetectionSettingsModelCopyWith(DetectionSettingsModel value, $Res Function(DetectionSettingsModel) _then) = _$DetectionSettingsModelCopyWithImpl;
@useResult
$Res call({
 double sensitivity, BeatFilter filter, DetectionStatus status
});




}
/// @nodoc
class _$DetectionSettingsModelCopyWithImpl<$Res>
    implements $DetectionSettingsModelCopyWith<$Res> {
  _$DetectionSettingsModelCopyWithImpl(this._self, this._then);

  final DetectionSettingsModel _self;
  final $Res Function(DetectionSettingsModel) _then;

/// Create a copy of DetectionSettingsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sensitivity = null,Object? filter = null,Object? status = null,}) {
  return _then(DetectionSettingsModel(
sensitivity: null == sensitivity ? _self.sensitivity : sensitivity // ignore: cast_nullable_to_non_nullable
as double,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as BeatFilter,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DetectionStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [DetectionSettingsModel].
extension DetectionSettingsModelPatterns on DetectionSettingsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetectionSettingsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetectionSettingsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetectionSettingsModel value)  $default,){
final _that = this;
switch (_that) {
case _DetectionSettingsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetectionSettingsModel value)?  $default,){
final _that = this;
switch (_that) {
case _DetectionSettingsModel() when $default != null:
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
case _DetectionSettingsModel() when $default != null:
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
case _DetectionSettingsModel():
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
case _DetectionSettingsModel() when $default != null:
return $default(_that.sensitivity,_that.filter,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DetectionSettingsModel implements DetectionSettingsModel {
  const _DetectionSettingsModel({this.sensitivity = 0.5, this.filter = BeatFilter.every, this.status = DetectionStatus.notRun});
  factory _DetectionSettingsModel.fromJson(Map<String, dynamic> json) => _$DetectionSettingsModelFromJson(json);

@override@JsonKey() final  double sensitivity;
@override@JsonKey() final  BeatFilter filter;
@override@JsonKey() final  DetectionStatus status;

/// Create a copy of DetectionSettingsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetectionSettingsModelCopyWith<_DetectionSettingsModel> get copyWith => __$DetectionSettingsModelCopyWithImpl<_DetectionSettingsModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DetectionSettingsModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetectionSettingsModel&&(identical(other.sensitivity, sensitivity) || other.sensitivity == sensitivity)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sensitivity,filter,status);
}

@override
String toString() {
    return 'DetectionSettingsModel(sensitivity: $sensitivity, filter: $filter, status: $status)';
}


}

/// @nodoc
abstract mixin class _$DetectionSettingsModelCopyWith<$Res> implements $DetectionSettingsModelCopyWith<$Res> {
  factory _$DetectionSettingsModelCopyWith(_DetectionSettingsModel value, $Res Function(_DetectionSettingsModel) _then) = __$DetectionSettingsModelCopyWithImpl;
@override @useResult
$Res call({
 double sensitivity, BeatFilter filter, DetectionStatus status
});




}
/// @nodoc
class __$DetectionSettingsModelCopyWithImpl<$Res>
    implements _$DetectionSettingsModelCopyWith<$Res> {
  __$DetectionSettingsModelCopyWithImpl(this._self, this._then);

  final _DetectionSettingsModel _self;
  final $Res Function(_DetectionSettingsModel) _then;

/// Create a copy of DetectionSettingsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sensitivity = null,Object? filter = null,Object? status = null,}) {
  return _then(_DetectionSettingsModel(
sensitivity: null == sensitivity ? _self.sensitivity : sensitivity // ignore: cast_nullable_to_non_nullable
as double,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as BeatFilter,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DetectionStatus,
  ));
}


}


/// @nodoc
mixin _$ProjectSummaryModel {

 String get id; String get title; int get beatCount; double? get bpm; int get sampleRate; int get sampleCount; DateTime get updatedAt; List<int> get thumbnail;
/// Create a copy of ProjectSummaryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSummaryModelCopyWith<ProjectSummaryModel> get copyWith => _$ProjectSummaryModelCopyWithImpl<ProjectSummaryModel>(this as ProjectSummaryModel, _$identity);

  /// Serializes this ProjectSummaryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProjectSummaryModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSummaryModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.beatCount, _this.beatCount) || other.beatCount == _this.beatCount)&&(identical(other.bpm, _this.bpm) || other.bpm == _this.bpm)&&(identical(other.sampleRate, _this.sampleRate) || other.sampleRate == _this.sampleRate)&&(identical(other.sampleCount, _this.sampleCount) || other.sampleCount == _this.sampleCount)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&const DeepCollectionEquality().equals(other.thumbnail, _this.thumbnail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProjectSummaryModel;
  return Object.hash(runtimeType,_this.id,_this.title,_this.beatCount,_this.bpm,_this.sampleRate,_this.sampleCount,_this.updatedAt,const DeepCollectionEquality().hash(_this.thumbnail));
}

@override
String toString() {
  final _this = this as ProjectSummaryModel;
  return 'ProjectSummaryModel(id: ${_this.id}, title: ${_this.title}, beatCount: ${_this.beatCount}, bpm: ${_this.bpm}, sampleRate: ${_this.sampleRate}, sampleCount: ${_this.sampleCount}, updatedAt: ${_this.updatedAt}, thumbnail: ${_this.thumbnail})';
}


}

/// @nodoc
abstract mixin class $ProjectSummaryModelCopyWith<$Res>  {
  factory $ProjectSummaryModelCopyWith(ProjectSummaryModel value, $Res Function(ProjectSummaryModel) _then) = _$ProjectSummaryModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, int beatCount, double? bpm, int sampleRate, int sampleCount, DateTime updatedAt, List<int> thumbnail
});




}
/// @nodoc
class _$ProjectSummaryModelCopyWithImpl<$Res>
    implements $ProjectSummaryModelCopyWith<$Res> {
  _$ProjectSummaryModelCopyWithImpl(this._self, this._then);

  final ProjectSummaryModel _self;
  final $Res Function(ProjectSummaryModel) _then;

/// Create a copy of ProjectSummaryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? beatCount = null,Object? bpm = freezed,Object? sampleRate = null,Object? sampleCount = null,Object? updatedAt = null,Object? thumbnail = null,}) {
  return _then(ProjectSummaryModel(
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


/// Adds pattern-matching-related methods to [ProjectSummaryModel].
extension ProjectSummaryModelPatterns on ProjectSummaryModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSummaryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSummaryModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSummaryModel value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSummaryModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSummaryModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSummaryModel() when $default != null:
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
case _ProjectSummaryModel() when $default != null:
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
case _ProjectSummaryModel():
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
case _ProjectSummaryModel() when $default != null:
return $default(_that.id,_that.title,_that.beatCount,_that.bpm,_that.sampleRate,_that.sampleCount,_that.updatedAt,_that.thumbnail);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectSummaryModel implements ProjectSummaryModel {
  const _ProjectSummaryModel({required this.id, required this.title, required this.beatCount, this.bpm, required this.sampleRate, required this.sampleCount, required this.updatedAt,  List<int> thumbnail = const <int>[]}): _thumbnail = thumbnail;
  factory _ProjectSummaryModel.fromJson(Map<String, dynamic> json) => _$ProjectSummaryModelFromJson(json);

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


/// Create a copy of ProjectSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSummaryModelCopyWith<_ProjectSummaryModel> get copyWith => __$ProjectSummaryModelCopyWithImpl<_ProjectSummaryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectSummaryModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSummaryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.beatCount, beatCount) || other.beatCount == beatCount)&&(identical(other.bpm, bpm) || other.bpm == bpm)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.thumbnail, _thumbnail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,beatCount,bpm,sampleRate,sampleCount,updatedAt,const DeepCollectionEquality().hash(_thumbnail));
}

@override
String toString() {
    return 'ProjectSummaryModel(id: $id, title: $title, beatCount: $beatCount, bpm: $bpm, sampleRate: $sampleRate, sampleCount: $sampleCount, updatedAt: $updatedAt, thumbnail: $thumbnail)';
}


}

/// @nodoc
abstract mixin class _$ProjectSummaryModelCopyWith<$Res> implements $ProjectSummaryModelCopyWith<$Res> {
  factory _$ProjectSummaryModelCopyWith(_ProjectSummaryModel value, $Res Function(_ProjectSummaryModel) _then) = __$ProjectSummaryModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, int beatCount, double? bpm, int sampleRate, int sampleCount, DateTime updatedAt, List<int> thumbnail
});




}
/// @nodoc
class __$ProjectSummaryModelCopyWithImpl<$Res>
    implements _$ProjectSummaryModelCopyWith<$Res> {
  __$ProjectSummaryModelCopyWithImpl(this._self, this._then);

  final _ProjectSummaryModel _self;
  final $Res Function(_ProjectSummaryModel) _then;

/// Create a copy of ProjectSummaryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? beatCount = null,Object? bpm = freezed,Object? sampleRate = null,Object? sampleCount = null,Object? updatedAt = null,Object? thumbnail = null,}) {
  return _then(_ProjectSummaryModel(
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


/// @nodoc
mixin _$ProjectIndexModel {

 int get schemaVersion; List<ProjectSummaryModel> get projects;
/// Create a copy of ProjectIndexModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectIndexModelCopyWith<ProjectIndexModel> get copyWith => _$ProjectIndexModelCopyWithImpl<ProjectIndexModel>(this as ProjectIndexModel, _$identity);

  /// Serializes this ProjectIndexModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProjectIndexModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectIndexModel&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&const DeepCollectionEquality().equals(other.projects, _this.projects));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProjectIndexModel;
  return Object.hash(runtimeType,_this.schemaVersion,const DeepCollectionEquality().hash(_this.projects));
}

@override
String toString() {
  final _this = this as ProjectIndexModel;
  return 'ProjectIndexModel(schemaVersion: ${_this.schemaVersion}, projects: ${_this.projects})';
}


}

/// @nodoc
abstract mixin class $ProjectIndexModelCopyWith<$Res>  {
  factory $ProjectIndexModelCopyWith(ProjectIndexModel value, $Res Function(ProjectIndexModel) _then) = _$ProjectIndexModelCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, List<ProjectSummaryModel> projects
});




}
/// @nodoc
class _$ProjectIndexModelCopyWithImpl<$Res>
    implements $ProjectIndexModelCopyWith<$Res> {
  _$ProjectIndexModelCopyWithImpl(this._self, this._then);

  final ProjectIndexModel _self;
  final $Res Function(ProjectIndexModel) _then;

/// Create a copy of ProjectIndexModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? projects = null,}) {
  return _then(ProjectIndexModel(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,projects: null == projects ? _self.projects : projects // ignore: cast_nullable_to_non_nullable
as List<ProjectSummaryModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectIndexModel].
extension ProjectIndexModelPatterns on ProjectIndexModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectIndexModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectIndexModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectIndexModel value)  $default,){
final _that = this;
switch (_that) {
case _ProjectIndexModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectIndexModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectIndexModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  List<ProjectSummaryModel> projects)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectIndexModel() when $default != null:
return $default(_that.schemaVersion,_that.projects);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  List<ProjectSummaryModel> projects)  $default,) {final _that = this;
switch (_that) {
case _ProjectIndexModel():
return $default(_that.schemaVersion,_that.projects);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  List<ProjectSummaryModel> projects)?  $default,) {final _that = this;
switch (_that) {
case _ProjectIndexModel() when $default != null:
return $default(_that.schemaVersion,_that.projects);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _ProjectIndexModel implements ProjectIndexModel {
  const _ProjectIndexModel({this.schemaVersion = currentProjectSchemaVersion,  List<ProjectSummaryModel> projects = const <ProjectSummaryModel>[]}): _projects = projects;
  factory _ProjectIndexModel.fromJson(Map<String, dynamic> json) => _$ProjectIndexModelFromJson(json);

@override@JsonKey() final  int schemaVersion;
 final  List<ProjectSummaryModel> _projects;
@override@JsonKey() List<ProjectSummaryModel> get projects {
  if (_projects is EqualUnmodifiableListView) return _projects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_projects);
}


/// Create a copy of ProjectIndexModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectIndexModelCopyWith<_ProjectIndexModel> get copyWith => __$ProjectIndexModelCopyWithImpl<_ProjectIndexModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectIndexModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectIndexModel&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&const DeepCollectionEquality().equals(other.projects, _projects));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,const DeepCollectionEquality().hash(_projects));
}

@override
String toString() {
    return 'ProjectIndexModel(schemaVersion: $schemaVersion, projects: $projects)';
}


}

/// @nodoc
abstract mixin class _$ProjectIndexModelCopyWith<$Res> implements $ProjectIndexModelCopyWith<$Res> {
  factory _$ProjectIndexModelCopyWith(_ProjectIndexModel value, $Res Function(_ProjectIndexModel) _then) = __$ProjectIndexModelCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, List<ProjectSummaryModel> projects
});




}
/// @nodoc
class __$ProjectIndexModelCopyWithImpl<$Res>
    implements _$ProjectIndexModelCopyWith<$Res> {
  __$ProjectIndexModelCopyWithImpl(this._self, this._then);

  final _ProjectIndexModel _self;
  final $Res Function(_ProjectIndexModel) _then;

/// Create a copy of ProjectIndexModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? projects = null,}) {
  return _then(_ProjectIndexModel(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,projects: null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<ProjectSummaryModel>,
  ));
}


}

// dart format on
