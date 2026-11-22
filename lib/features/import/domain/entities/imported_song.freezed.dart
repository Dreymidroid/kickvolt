// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'imported_song.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ImportedSong {

 String get projectId; String get title; PickedSource get source;/// Copy of the original file, or null for iOS library items.
 String? get sourceCopyPath; String get wavPath; int get sampleRate; int get channels;/// Sample frames in [wavPath]. The project's master timebase.
 int get frameCount;
/// Create a copy of ImportedSong
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImportedSongCopyWith<ImportedSong> get copyWith => _$ImportedSongCopyWithImpl<ImportedSong>(this as ImportedSong, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ImportedSong;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImportedSong&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.sourceCopyPath, _this.sourceCopyPath) || other.sourceCopyPath == _this.sourceCopyPath)&&(identical(other.wavPath, _this.wavPath) || other.wavPath == _this.wavPath)&&(identical(other.sampleRate, _this.sampleRate) || other.sampleRate == _this.sampleRate)&&(identical(other.channels, _this.channels) || other.channels == _this.channels)&&(identical(other.frameCount, _this.frameCount) || other.frameCount == _this.frameCount));
}


@override
int get hashCode {
  final _this = this as ImportedSong;
  return Object.hash(runtimeType,_this.projectId,_this.title,_this.source,_this.sourceCopyPath,_this.wavPath,_this.sampleRate,_this.channels,_this.frameCount);
}

@override
String toString() {
  final _this = this as ImportedSong;
  return 'ImportedSong(projectId: ${_this.projectId}, title: ${_this.title}, source: ${_this.source}, sourceCopyPath: ${_this.sourceCopyPath}, wavPath: ${_this.wavPath}, sampleRate: ${_this.sampleRate}, channels: ${_this.channels}, frameCount: ${_this.frameCount})';
}


}

/// @nodoc
abstract mixin class $ImportedSongCopyWith<$Res>  {
  factory $ImportedSongCopyWith(ImportedSong value, $Res Function(ImportedSong) _then) = _$ImportedSongCopyWithImpl;
@useResult
$Res call({
 String projectId, String title, PickedSource source, String? sourceCopyPath, String wavPath, int sampleRate, int channels, int frameCount
});


$PickedSourceCopyWith<$Res> get source;

}
/// @nodoc
class _$ImportedSongCopyWithImpl<$Res>
    implements $ImportedSongCopyWith<$Res> {
  _$ImportedSongCopyWithImpl(this._self, this._then);

  final ImportedSong _self;
  final $Res Function(ImportedSong) _then;

/// Create a copy of ImportedSong
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? title = null,Object? source = null,Object? sourceCopyPath = freezed,Object? wavPath = null,Object? sampleRate = null,Object? channels = null,Object? frameCount = null,}) {
  return _then(ImportedSong(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PickedSource,sourceCopyPath: freezed == sourceCopyPath ? _self.sourceCopyPath : sourceCopyPath // ignore: cast_nullable_to_non_nullable
as String?,wavPath: null == wavPath ? _self.wavPath : wavPath // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,frameCount: null == frameCount ? _self.frameCount : frameCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ImportedSong
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PickedSourceCopyWith<$Res> get source {
  
  return $PickedSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// Adds pattern-matching-related methods to [ImportedSong].
extension ImportedSongPatterns on ImportedSong {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImportedSong value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImportedSong() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImportedSong value)  $default,){
final _that = this;
switch (_that) {
case _ImportedSong():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImportedSong value)?  $default,){
final _that = this;
switch (_that) {
case _ImportedSong() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String projectId,  String title,  PickedSource source,  String? sourceCopyPath,  String wavPath,  int sampleRate,  int channels,  int frameCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImportedSong() when $default != null:
return $default(_that.projectId,_that.title,_that.source,_that.sourceCopyPath,_that.wavPath,_that.sampleRate,_that.channels,_that.frameCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String projectId,  String title,  PickedSource source,  String? sourceCopyPath,  String wavPath,  int sampleRate,  int channels,  int frameCount)  $default,) {final _that = this;
switch (_that) {
case _ImportedSong():
return $default(_that.projectId,_that.title,_that.source,_that.sourceCopyPath,_that.wavPath,_that.sampleRate,_that.channels,_that.frameCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String projectId,  String title,  PickedSource source,  String? sourceCopyPath,  String wavPath,  int sampleRate,  int channels,  int frameCount)?  $default,) {final _that = this;
switch (_that) {
case _ImportedSong() when $default != null:
return $default(_that.projectId,_that.title,_that.source,_that.sourceCopyPath,_that.wavPath,_that.sampleRate,_that.channels,_that.frameCount);case _:
  return null;

}
}

}

/// @nodoc


class _ImportedSong extends ImportedSong {
  const _ImportedSong({required this.projectId, required this.title, required this.source, this.sourceCopyPath, required this.wavPath, required this.sampleRate, required this.channels, required this.frameCount}): super._();
  

@override final  String projectId;
@override final  String title;
@override final  PickedSource source;
/// Copy of the original file, or null for iOS library items.
@override final  String? sourceCopyPath;
@override final  String wavPath;
@override final  int sampleRate;
@override final  int channels;
/// Sample frames in [wavPath]. The project's master timebase.
@override final  int frameCount;

/// Create a copy of ImportedSong
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImportedSongCopyWith<_ImportedSong> get copyWith => __$ImportedSongCopyWithImpl<_ImportedSong>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImportedSong&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.title, title) || other.title == title)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourceCopyPath, sourceCopyPath) || other.sourceCopyPath == sourceCopyPath)&&(identical(other.wavPath, wavPath) || other.wavPath == wavPath)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.frameCount, frameCount) || other.frameCount == frameCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,projectId,title,source,sourceCopyPath,wavPath,sampleRate,channels,frameCount);
}

@override
String toString() {
    return 'ImportedSong(projectId: $projectId, title: $title, source: $source, sourceCopyPath: $sourceCopyPath, wavPath: $wavPath, sampleRate: $sampleRate, channels: $channels, frameCount: $frameCount)';
}


}

/// @nodoc
abstract mixin class _$ImportedSongCopyWith<$Res> implements $ImportedSongCopyWith<$Res> {
  factory _$ImportedSongCopyWith(_ImportedSong value, $Res Function(_ImportedSong) _then) = __$ImportedSongCopyWithImpl;
@override @useResult
$Res call({
 String projectId, String title, PickedSource source, String? sourceCopyPath, String wavPath, int sampleRate, int channels, int frameCount
});


@override $PickedSourceCopyWith<$Res> get source;

}
/// @nodoc
class __$ImportedSongCopyWithImpl<$Res>
    implements _$ImportedSongCopyWith<$Res> {
  __$ImportedSongCopyWithImpl(this._self, this._then);

  final _ImportedSong _self;
  final $Res Function(_ImportedSong) _then;

/// Create a copy of ImportedSong
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? title = null,Object? source = null,Object? sourceCopyPath = freezed,Object? wavPath = null,Object? sampleRate = null,Object? channels = null,Object? frameCount = null,}) {
  return _then(_ImportedSong(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PickedSource,sourceCopyPath: freezed == sourceCopyPath ? _self.sourceCopyPath : sourceCopyPath // ignore: cast_nullable_to_non_nullable
as String?,wavPath: null == wavPath ? _self.wavPath : wavPath // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,frameCount: null == frameCount ? _self.frameCount : frameCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ImportedSong
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PickedSourceCopyWith<$Res> get source {
  
  return $PickedSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}

// dart format on
