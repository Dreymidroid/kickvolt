// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'projects_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectsState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectsState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ProjectsState()';
}


}

/// @nodoc
class $ProjectsStateCopyWith<$Res>  {
$ProjectsStateCopyWith(ProjectsState _, $Res Function(ProjectsState) __);
}


/// Adds pattern-matching-related methods to [ProjectsState].
extension ProjectsStatePatterns on ProjectsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ProjectsLoading value)?  loading,TResult Function( ProjectsLoaded value)?  loaded,TResult Function( ProjectsError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ProjectsLoading() when loading != null:
return loading(_that);case ProjectsLoaded() when loaded != null:
return loaded(_that);case ProjectsError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ProjectsLoading value)  loading,required TResult Function( ProjectsLoaded value)  loaded,required TResult Function( ProjectsError value)  error,}){
final _that = this;
switch (_that) {
case ProjectsLoading():
return loading(_that);case ProjectsLoaded():
return loaded(_that);case ProjectsError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ProjectsLoading value)?  loading,TResult? Function( ProjectsLoaded value)?  loaded,TResult? Function( ProjectsError value)?  error,}){
final _that = this;
switch (_that) {
case ProjectsLoading() when loading != null:
return loading(_that);case ProjectsLoaded() when loaded != null:
return loaded(_that);case ProjectsError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( List<ProjectSummary> projects)?  loaded,TResult Function( String error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ProjectsLoading() when loading != null:
return loading();case ProjectsLoaded() when loaded != null:
return loaded(_that.projects);case ProjectsError() when error != null:
return error(_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( List<ProjectSummary> projects)  loaded,required TResult Function( String error)  error,}) {final _that = this;
switch (_that) {
case ProjectsLoading():
return loading();case ProjectsLoaded():
return loaded(_that.projects);case ProjectsError():
return error(_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( List<ProjectSummary> projects)?  loaded,TResult? Function( String error)?  error,}) {final _that = this;
switch (_that) {
case ProjectsLoading() when loading != null:
return loading();case ProjectsLoaded() when loaded != null:
return loaded(_that.projects);case ProjectsError() when error != null:
return error(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class ProjectsLoading implements ProjectsState {
  const ProjectsLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectsLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ProjectsState.loading()';
}


}




/// @nodoc


class ProjectsLoaded implements ProjectsState {
  const ProjectsLoaded( List<ProjectSummary> projects): _projects = projects;
  

 final  List<ProjectSummary> _projects;
 List<ProjectSummary> get projects {
  if (_projects is EqualUnmodifiableListView) return _projects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_projects);
}


/// Create a copy of ProjectsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectsLoadedCopyWith<ProjectsLoaded> get copyWith => _$ProjectsLoadedCopyWithImpl<ProjectsLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectsLoaded&&const DeepCollectionEquality().equals(other.projects, _projects));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_projects));
}

@override
String toString() {
    return 'ProjectsState.loaded(projects: $projects)';
}


}

/// @nodoc
abstract mixin class $ProjectsLoadedCopyWith<$Res> implements $ProjectsStateCopyWith<$Res> {
  factory $ProjectsLoadedCopyWith(ProjectsLoaded value, $Res Function(ProjectsLoaded) _then) = _$ProjectsLoadedCopyWithImpl;
@useResult
$Res call({
 List<ProjectSummary> projects
});




}
/// @nodoc
class _$ProjectsLoadedCopyWithImpl<$Res>
    implements $ProjectsLoadedCopyWith<$Res> {
  _$ProjectsLoadedCopyWithImpl(this._self, this._then);

  final ProjectsLoaded _self;
  final $Res Function(ProjectsLoaded) _then;

/// Create a copy of ProjectsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? projects = null,}) {
  return _then(ProjectsLoaded(
null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<ProjectSummary>,
  ));
}


}

/// @nodoc


class ProjectsError implements ProjectsState {
  const ProjectsError({required this.error});
  

 final  String error;

/// Create a copy of ProjectsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectsErrorCopyWith<ProjectsError> get copyWith => _$ProjectsErrorCopyWithImpl<ProjectsError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectsError&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString() {
    return 'ProjectsState.error(error: $error)';
}


}

/// @nodoc
abstract mixin class $ProjectsErrorCopyWith<$Res> implements $ProjectsStateCopyWith<$Res> {
  factory $ProjectsErrorCopyWith(ProjectsError value, $Res Function(ProjectsError) _then) = _$ProjectsErrorCopyWithImpl;
@useResult
$Res call({
 String error
});




}
/// @nodoc
class _$ProjectsErrorCopyWithImpl<$Res>
    implements $ProjectsErrorCopyWith<$Res> {
  _$ProjectsErrorCopyWithImpl(this._self, this._then);

  final ProjectsError _self;
  final $Res Function(ProjectsError) _then;

/// Create a copy of ProjectsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(ProjectsError(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
