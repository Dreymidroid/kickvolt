// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'song_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SongSection {

 int get startMs; int get endMs; SectionKind get kind;
/// Create a copy of SongSection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SongSectionCopyWith<SongSection> get copyWith => _$SongSectionCopyWithImpl<SongSection>(this as SongSection, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SongSection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SongSection&&(identical(other.startMs, _this.startMs) || other.startMs == _this.startMs)&&(identical(other.endMs, _this.endMs) || other.endMs == _this.endMs)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}


@override
int get hashCode {
  final _this = this as SongSection;
  return Object.hash(runtimeType,_this.startMs,_this.endMs,_this.kind);
}

@override
String toString() {
  final _this = this as SongSection;
  return 'SongSection(startMs: ${_this.startMs}, endMs: ${_this.endMs}, kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $SongSectionCopyWith<$Res>  {
  factory $SongSectionCopyWith(SongSection value, $Res Function(SongSection) _then) = _$SongSectionCopyWithImpl;
@useResult
$Res call({
 int startMs, int endMs, SectionKind kind
});




}
/// @nodoc
class _$SongSectionCopyWithImpl<$Res>
    implements $SongSectionCopyWith<$Res> {
  _$SongSectionCopyWithImpl(this._self, this._then);

  final SongSection _self;
  final $Res Function(SongSection) _then;

/// Create a copy of SongSection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startMs = null,Object? endMs = null,Object? kind = null,}) {
  return _then(SongSection(
startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as SectionKind,
  ));
}

}


/// Adds pattern-matching-related methods to [SongSection].
extension SongSectionPatterns on SongSection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SongSection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SongSection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SongSection value)  $default,){
final _that = this;
switch (_that) {
case _SongSection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SongSection value)?  $default,){
final _that = this;
switch (_that) {
case _SongSection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startMs,  int endMs,  SectionKind kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SongSection() when $default != null:
return $default(_that.startMs,_that.endMs,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startMs,  int endMs,  SectionKind kind)  $default,) {final _that = this;
switch (_that) {
case _SongSection():
return $default(_that.startMs,_that.endMs,_that.kind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startMs,  int endMs,  SectionKind kind)?  $default,) {final _that = this;
switch (_that) {
case _SongSection() when $default != null:
return $default(_that.startMs,_that.endMs,_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class _SongSection implements SongSection {
  const _SongSection({required this.startMs, required this.endMs, required this.kind});
  

@override final  int startMs;
@override final  int endMs;
@override final  SectionKind kind;

/// Create a copy of SongSection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SongSectionCopyWith<_SongSection> get copyWith => __$SongSectionCopyWithImpl<_SongSection>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SongSection&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,startMs,endMs,kind);
}

@override
String toString() {
    return 'SongSection(startMs: $startMs, endMs: $endMs, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$SongSectionCopyWith<$Res> implements $SongSectionCopyWith<$Res> {
  factory _$SongSectionCopyWith(_SongSection value, $Res Function(_SongSection) _then) = __$SongSectionCopyWithImpl;
@override @useResult
$Res call({
 int startMs, int endMs, SectionKind kind
});




}
/// @nodoc
class __$SongSectionCopyWithImpl<$Res>
    implements _$SongSectionCopyWith<$Res> {
  __$SongSectionCopyWithImpl(this._self, this._then);

  final _SongSection _self;
  final $Res Function(_SongSection) _then;

/// Create a copy of SongSection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startMs = null,Object? endMs = null,Object? kind = null,}) {
  return _then(_SongSection(
startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as SectionKind,
  ));
}


}

// dart format on
