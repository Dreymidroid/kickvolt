// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'beat_project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BeatProject {

 String get id; String get name; int get durationMs; int get bpm; List<Beat> get beats; List<SongSection> get sections;/// Peak amplitude (0–1) per [peakBinMs] slice of the song.
 List<double> get peaks; int get peakBinMs;
/// Create a copy of BeatProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BeatProjectCopyWith<BeatProject> get copyWith => _$BeatProjectCopyWithImpl<BeatProject>(this as BeatProject, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BeatProject;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BeatProject&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.bpm, _this.bpm) || other.bpm == _this.bpm)&&const DeepCollectionEquality().equals(other.beats, _this.beats)&&const DeepCollectionEquality().equals(other.sections, _this.sections)&&const DeepCollectionEquality().equals(other.peaks, _this.peaks)&&(identical(other.peakBinMs, _this.peakBinMs) || other.peakBinMs == _this.peakBinMs));
}


@override
int get hashCode {
  final _this = this as BeatProject;
  return Object.hash(runtimeType,_this.id,_this.name,_this.durationMs,_this.bpm,const DeepCollectionEquality().hash(_this.beats),const DeepCollectionEquality().hash(_this.sections),const DeepCollectionEquality().hash(_this.peaks),_this.peakBinMs);
}

@override
String toString() {
  final _this = this as BeatProject;
  return 'BeatProject(id: ${_this.id}, name: ${_this.name}, durationMs: ${_this.durationMs}, bpm: ${_this.bpm}, beats: ${_this.beats}, sections: ${_this.sections}, peaks: ${_this.peaks}, peakBinMs: ${_this.peakBinMs})';
}


}

/// @nodoc
abstract mixin class $BeatProjectCopyWith<$Res>  {
  factory $BeatProjectCopyWith(BeatProject value, $Res Function(BeatProject) _then) = _$BeatProjectCopyWithImpl;
@useResult
$Res call({
 String id, String name, int durationMs, int bpm, List<Beat> beats, List<SongSection> sections, List<double> peaks, int peakBinMs
});




}
/// @nodoc
class _$BeatProjectCopyWithImpl<$Res>
    implements $BeatProjectCopyWith<$Res> {
  _$BeatProjectCopyWithImpl(this._self, this._then);

  final BeatProject _self;
  final $Res Function(BeatProject) _then;

/// Create a copy of BeatProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? durationMs = null,Object? bpm = null,Object? beats = null,Object? sections = null,Object? peaks = null,Object? peakBinMs = null,}) {
  return _then(BeatProject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as int,beats: null == beats ? _self.beats : beats // ignore: cast_nullable_to_non_nullable
as List<Beat>,sections: null == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as List<SongSection>,peaks: null == peaks ? _self.peaks : peaks // ignore: cast_nullable_to_non_nullable
as List<double>,peakBinMs: null == peakBinMs ? _self.peakBinMs : peakBinMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BeatProject].
extension BeatProjectPatterns on BeatProject {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BeatProject value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BeatProject() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BeatProject value)  $default,){
final _that = this;
switch (_that) {
case _BeatProject():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BeatProject value)?  $default,){
final _that = this;
switch (_that) {
case _BeatProject() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int durationMs,  int bpm,  List<Beat> beats,  List<SongSection> sections,  List<double> peaks,  int peakBinMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BeatProject() when $default != null:
return $default(_that.id,_that.name,_that.durationMs,_that.bpm,_that.beats,_that.sections,_that.peaks,_that.peakBinMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int durationMs,  int bpm,  List<Beat> beats,  List<SongSection> sections,  List<double> peaks,  int peakBinMs)  $default,) {final _that = this;
switch (_that) {
case _BeatProject():
return $default(_that.id,_that.name,_that.durationMs,_that.bpm,_that.beats,_that.sections,_that.peaks,_that.peakBinMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int durationMs,  int bpm,  List<Beat> beats,  List<SongSection> sections,  List<double> peaks,  int peakBinMs)?  $default,) {final _that = this;
switch (_that) {
case _BeatProject() when $default != null:
return $default(_that.id,_that.name,_that.durationMs,_that.bpm,_that.beats,_that.sections,_that.peaks,_that.peakBinMs);case _:
  return null;

}
}

}

/// @nodoc


class _BeatProject extends BeatProject {
  const _BeatProject({required this.id, required this.name, required this.durationMs, required this.bpm, required  List<Beat> beats, required  List<SongSection> sections, required  List<double> peaks, this.peakBinMs = 10}): _beats = beats,_sections = sections,_peaks = peaks,super._();
  

@override final  String id;
@override final  String name;
@override final  int durationMs;
@override final  int bpm;
 final  List<Beat> _beats;
@override List<Beat> get beats {
  if (_beats is EqualUnmodifiableListView) return _beats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_beats);
}

 final  List<SongSection> _sections;
@override List<SongSection> get sections {
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sections);
}

/// Peak amplitude (0–1) per [peakBinMs] slice of the song.
 final  List<double> _peaks;
/// Peak amplitude (0–1) per [peakBinMs] slice of the song.
@override List<double> get peaks {
  if (_peaks is EqualUnmodifiableListView) return _peaks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_peaks);
}

@override@JsonKey() final  int peakBinMs;

/// Create a copy of BeatProject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BeatProjectCopyWith<_BeatProject> get copyWith => __$BeatProjectCopyWithImpl<_BeatProject>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BeatProject&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.bpm, bpm) || other.bpm == bpm)&&const DeepCollectionEquality().equals(other.beats, _beats)&&const DeepCollectionEquality().equals(other.sections, _sections)&&const DeepCollectionEquality().equals(other.peaks, _peaks)&&(identical(other.peakBinMs, peakBinMs) || other.peakBinMs == peakBinMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,durationMs,bpm,const DeepCollectionEquality().hash(_beats),const DeepCollectionEquality().hash(_sections),const DeepCollectionEquality().hash(_peaks),peakBinMs);
}

@override
String toString() {
    return 'BeatProject(id: $id, name: $name, durationMs: $durationMs, bpm: $bpm, beats: $beats, sections: $sections, peaks: $peaks, peakBinMs: $peakBinMs)';
}


}

/// @nodoc
abstract mixin class _$BeatProjectCopyWith<$Res> implements $BeatProjectCopyWith<$Res> {
  factory _$BeatProjectCopyWith(_BeatProject value, $Res Function(_BeatProject) _then) = __$BeatProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int durationMs, int bpm, List<Beat> beats, List<SongSection> sections, List<double> peaks, int peakBinMs
});




}
/// @nodoc
class __$BeatProjectCopyWithImpl<$Res>
    implements _$BeatProjectCopyWith<$Res> {
  __$BeatProjectCopyWithImpl(this._self, this._then);

  final _BeatProject _self;
  final $Res Function(_BeatProject) _then;

/// Create a copy of BeatProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? durationMs = null,Object? bpm = null,Object? beats = null,Object? sections = null,Object? peaks = null,Object? peakBinMs = null,}) {
  return _then(_BeatProject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as int,beats: null == beats ? _self._beats : beats // ignore: cast_nullable_to_non_nullable
as List<Beat>,sections: null == sections ? _self._sections : sections // ignore: cast_nullable_to_non_nullable
as List<SongSection>,peaks: null == peaks ? _self._peaks : peaks // ignore: cast_nullable_to_non_nullable
as List<double>,peakBinMs: null == peakBinMs ? _self.peakBinMs : peakBinMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
