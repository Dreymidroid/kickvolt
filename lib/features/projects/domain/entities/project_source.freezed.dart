// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectSource {

 ImportSourceKind get kind; String get originalName;/// Relative file name inside the project folder (e.g. `source.m4a`), or
/// null for iOS music library items.
 String? get copiedFileName;
/// Create a copy of ProjectSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSourceCopyWith<ProjectSource> get copyWith => _$ProjectSourceCopyWithImpl<ProjectSource>(this as ProjectSource, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProjectSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSource&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.originalName, _this.originalName) || other.originalName == _this.originalName)&&(identical(other.copiedFileName, _this.copiedFileName) || other.copiedFileName == _this.copiedFileName));
}


@override
int get hashCode {
  final _this = this as ProjectSource;
  return Object.hash(runtimeType,_this.kind,_this.originalName,_this.copiedFileName);
}

@override
String toString() {
  final _this = this as ProjectSource;
  return 'ProjectSource(kind: ${_this.kind}, originalName: ${_this.originalName}, copiedFileName: ${_this.copiedFileName})';
}


}

/// @nodoc
abstract mixin class $ProjectSourceCopyWith<$Res>  {
  factory $ProjectSourceCopyWith(ProjectSource value, $Res Function(ProjectSource) _then) = _$ProjectSourceCopyWithImpl;
@useResult
$Res call({
 ImportSourceKind kind, String originalName, String? copiedFileName
});




}
/// @nodoc
class _$ProjectSourceCopyWithImpl<$Res>
    implements $ProjectSourceCopyWith<$Res> {
  _$ProjectSourceCopyWithImpl(this._self, this._then);

  final ProjectSource _self;
  final $Res Function(ProjectSource) _then;

/// Create a copy of ProjectSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? originalName = null,Object? copiedFileName = freezed,}) {
  return _then(ProjectSource(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ImportSourceKind,originalName: null == originalName ? _self.originalName : originalName // ignore: cast_nullable_to_non_nullable
as String,copiedFileName: freezed == copiedFileName ? _self.copiedFileName : copiedFileName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectSource].
extension ProjectSourcePatterns on ProjectSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSource value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSource value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSource() when $default != null:
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
case _ProjectSource() when $default != null:
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
case _ProjectSource():
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
case _ProjectSource() when $default != null:
return $default(_that.kind,_that.originalName,_that.copiedFileName);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectSource implements ProjectSource {
  const _ProjectSource({required this.kind, required this.originalName, this.copiedFileName});
  

@override final  ImportSourceKind kind;
@override final  String originalName;
/// Relative file name inside the project folder (e.g. `source.m4a`), or
/// null for iOS music library items.
@override final  String? copiedFileName;

/// Create a copy of ProjectSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSourceCopyWith<_ProjectSource> get copyWith => __$ProjectSourceCopyWithImpl<_ProjectSource>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSource&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.originalName, originalName) || other.originalName == originalName)&&(identical(other.copiedFileName, copiedFileName) || other.copiedFileName == copiedFileName));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,originalName,copiedFileName);
}

@override
String toString() {
    return 'ProjectSource(kind: $kind, originalName: $originalName, copiedFileName: $copiedFileName)';
}


}

/// @nodoc
abstract mixin class _$ProjectSourceCopyWith<$Res> implements $ProjectSourceCopyWith<$Res> {
  factory _$ProjectSourceCopyWith(_ProjectSource value, $Res Function(_ProjectSource) _then) = __$ProjectSourceCopyWithImpl;
@override @useResult
$Res call({
 ImportSourceKind kind, String originalName, String? copiedFileName
});




}
/// @nodoc
class __$ProjectSourceCopyWithImpl<$Res>
    implements _$ProjectSourceCopyWith<$Res> {
  __$ProjectSourceCopyWithImpl(this._self, this._then);

  final _ProjectSource _self;
  final $Res Function(_ProjectSource) _then;

/// Create a copy of ProjectSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? originalName = null,Object? copiedFileName = freezed,}) {
  return _then(_ProjectSource(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ImportSourceKind,originalName: null == originalName ? _self.originalName : originalName // ignore: cast_nullable_to_non_nullable
as String,copiedFileName: freezed == copiedFileName ? _self.copiedFileName : copiedFileName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
