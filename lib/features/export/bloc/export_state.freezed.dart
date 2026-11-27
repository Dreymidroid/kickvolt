// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'export_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExportState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExportState()';
}


}

/// @nodoc
class $ExportStateCopyWith<$Res>  {
$ExportStateCopyWith(ExportState _, $Res Function(ExportState) __);
}


/// Adds pattern-matching-related methods to [ExportState].
extension ExportStatePatterns on ExportState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ExportLoading value)?  loading,TResult Function( ExportError value)?  error,TResult Function( ExportEditing value)?  editing,TResult Function( ExportExporting value)?  exporting,TResult Function( ExportFailed value)?  failed,TResult Function( ExportDone value)?  done,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ExportLoading() when loading != null:
return loading(_that);case ExportError() when error != null:
return error(_that);case ExportEditing() when editing != null:
return editing(_that);case ExportExporting() when exporting != null:
return exporting(_that);case ExportFailed() when failed != null:
return failed(_that);case ExportDone() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ExportLoading value)  loading,required TResult Function( ExportError value)  error,required TResult Function( ExportEditing value)  editing,required TResult Function( ExportExporting value)  exporting,required TResult Function( ExportFailed value)  failed,required TResult Function( ExportDone value)  done,}){
final _that = this;
switch (_that) {
case ExportLoading():
return loading(_that);case ExportError():
return error(_that);case ExportEditing():
return editing(_that);case ExportExporting():
return exporting(_that);case ExportFailed():
return failed(_that);case ExportDone():
return done(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ExportLoading value)?  loading,TResult? Function( ExportError value)?  error,TResult? Function( ExportEditing value)?  editing,TResult? Function( ExportExporting value)?  exporting,TResult? Function( ExportFailed value)?  failed,TResult? Function( ExportDone value)?  done,}){
final _that = this;
switch (_that) {
case ExportLoading() when loading != null:
return loading(_that);case ExportError() when error != null:
return error(_that);case ExportEditing() when editing != null:
return editing(_that);case ExportExporting() when exporting != null:
return exporting(_that);case ExportFailed() when failed != null:
return failed(_that);case ExportDone() when done != null:
return done(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( String message)?  error,TResult Function( Project project,  ExportOptions options,  BeatPackPlan plan,  ExportQuota quota)?  editing,TResult Function( ExportOptions options,  BeatPackPlan plan,  ExportProgress progress)?  exporting,TResult Function( ExportFailure failure,  Project project,  ExportOptions options,  BeatPackPlan plan,  ExportQuota quota)?  failed,TResult Function( BeatPack pack,  bool saved)?  done,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ExportLoading() when loading != null:
return loading();case ExportError() when error != null:
return error(_that.message);case ExportEditing() when editing != null:
return editing(_that.project,_that.options,_that.plan,_that.quota);case ExportExporting() when exporting != null:
return exporting(_that.options,_that.plan,_that.progress);case ExportFailed() when failed != null:
return failed(_that.failure,_that.project,_that.options,_that.plan,_that.quota);case ExportDone() when done != null:
return done(_that.pack,_that.saved);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( String message)  error,required TResult Function( Project project,  ExportOptions options,  BeatPackPlan plan,  ExportQuota quota)  editing,required TResult Function( ExportOptions options,  BeatPackPlan plan,  ExportProgress progress)  exporting,required TResult Function( ExportFailure failure,  Project project,  ExportOptions options,  BeatPackPlan plan,  ExportQuota quota)  failed,required TResult Function( BeatPack pack,  bool saved)  done,}) {final _that = this;
switch (_that) {
case ExportLoading():
return loading();case ExportError():
return error(_that.message);case ExportEditing():
return editing(_that.project,_that.options,_that.plan,_that.quota);case ExportExporting():
return exporting(_that.options,_that.plan,_that.progress);case ExportFailed():
return failed(_that.failure,_that.project,_that.options,_that.plan,_that.quota);case ExportDone():
return done(_that.pack,_that.saved);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( String message)?  error,TResult? Function( Project project,  ExportOptions options,  BeatPackPlan plan,  ExportQuota quota)?  editing,TResult? Function( ExportOptions options,  BeatPackPlan plan,  ExportProgress progress)?  exporting,TResult? Function( ExportFailure failure,  Project project,  ExportOptions options,  BeatPackPlan plan,  ExportQuota quota)?  failed,TResult? Function( BeatPack pack,  bool saved)?  done,}) {final _that = this;
switch (_that) {
case ExportLoading() when loading != null:
return loading();case ExportError() when error != null:
return error(_that.message);case ExportEditing() when editing != null:
return editing(_that.project,_that.options,_that.plan,_that.quota);case ExportExporting() when exporting != null:
return exporting(_that.options,_that.plan,_that.progress);case ExportFailed() when failed != null:
return failed(_that.failure,_that.project,_that.options,_that.plan,_that.quota);case ExportDone() when done != null:
return done(_that.pack,_that.saved);case _:
  return null;

}
}

}

/// @nodoc


class ExportLoading implements ExportState {
  const ExportLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExportState.loading()';
}


}




/// @nodoc


class ExportError implements ExportState {
  const ExportError(this.message);
  

 final  String message;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExportErrorCopyWith<ExportError> get copyWith => _$ExportErrorCopyWithImpl<ExportError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'ExportState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $ExportErrorCopyWith<$Res> implements $ExportStateCopyWith<$Res> {
  factory $ExportErrorCopyWith(ExportError value, $Res Function(ExportError) _then) = _$ExportErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$ExportErrorCopyWithImpl<$Res>
    implements $ExportErrorCopyWith<$Res> {
  _$ExportErrorCopyWithImpl(this._self, this._then);

  final ExportError _self;
  final $Res Function(ExportError) _then;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(ExportError(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ExportEditing implements ExportState {
  const ExportEditing({required this.project, required this.options, required this.plan, required this.quota});
  

 final  Project project;
 final  ExportOptions options;
 final  BeatPackPlan plan;
 final  ExportQuota quota;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExportEditingCopyWith<ExportEditing> get copyWith => _$ExportEditingCopyWithImpl<ExportEditing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportEditing&&(identical(other.project, project) || other.project == project)&&(identical(other.options, options) || other.options == options)&&(identical(other.plan, plan) || other.plan == plan)&&(identical(other.quota, quota) || other.quota == quota));
}


@override
int get hashCode {
    return Object.hash(runtimeType,project,options,plan,quota);
}

@override
String toString() {
    return 'ExportState.editing(project: $project, options: $options, plan: $plan, quota: $quota)';
}


}

/// @nodoc
abstract mixin class $ExportEditingCopyWith<$Res> implements $ExportStateCopyWith<$Res> {
  factory $ExportEditingCopyWith(ExportEditing value, $Res Function(ExportEditing) _then) = _$ExportEditingCopyWithImpl;
@useResult
$Res call({
 Project project, ExportOptions options, BeatPackPlan plan, ExportQuota quota
});


$ProjectCopyWith<$Res> get project;

}
/// @nodoc
class _$ExportEditingCopyWithImpl<$Res>
    implements $ExportEditingCopyWith<$Res> {
  _$ExportEditingCopyWithImpl(this._self, this._then);

  final ExportEditing _self;
  final $Res Function(ExportEditing) _then;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? project = null,Object? options = null,Object? plan = null,Object? quota = null,}) {
  return _then(ExportEditing(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as Project,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as ExportOptions,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as BeatPackPlan,quota: null == quota ? _self.quota : quota // ignore: cast_nullable_to_non_nullable
as ExportQuota,
  ));
}

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectCopyWith<$Res> get project {
  
  return $ProjectCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}

/// @nodoc


class ExportExporting implements ExportState {
  const ExportExporting({required this.options, required this.plan, required this.progress});
  

 final  ExportOptions options;
 final  BeatPackPlan plan;
 final  ExportProgress progress;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExportExportingCopyWith<ExportExporting> get copyWith => _$ExportExportingCopyWithImpl<ExportExporting>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportExporting&&(identical(other.options, options) || other.options == options)&&(identical(other.plan, plan) || other.plan == plan)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode {
    return Object.hash(runtimeType,options,plan,progress);
}

@override
String toString() {
    return 'ExportState.exporting(options: $options, plan: $plan, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $ExportExportingCopyWith<$Res> implements $ExportStateCopyWith<$Res> {
  factory $ExportExportingCopyWith(ExportExporting value, $Res Function(ExportExporting) _then) = _$ExportExportingCopyWithImpl;
@useResult
$Res call({
 ExportOptions options, BeatPackPlan plan, ExportProgress progress
});




}
/// @nodoc
class _$ExportExportingCopyWithImpl<$Res>
    implements $ExportExportingCopyWith<$Res> {
  _$ExportExportingCopyWithImpl(this._self, this._then);

  final ExportExporting _self;
  final $Res Function(ExportExporting) _then;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,Object? plan = null,Object? progress = null,}) {
  return _then(ExportExporting(
options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as ExportOptions,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as BeatPackPlan,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ExportProgress,
  ));
}


}

/// @nodoc


class ExportFailed implements ExportState {
  const ExportFailed({required this.failure, required this.project, required this.options, required this.plan, required this.quota});
  

 final  ExportFailure failure;
 final  Project project;
 final  ExportOptions options;
 final  BeatPackPlan plan;
 final  ExportQuota quota;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExportFailedCopyWith<ExportFailed> get copyWith => _$ExportFailedCopyWithImpl<ExportFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportFailed&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.project, project) || other.project == project)&&(identical(other.options, options) || other.options == options)&&(identical(other.plan, plan) || other.plan == plan)&&(identical(other.quota, quota) || other.quota == quota));
}


@override
int get hashCode {
    return Object.hash(runtimeType,failure,project,options,plan,quota);
}

@override
String toString() {
    return 'ExportState.failed(failure: $failure, project: $project, options: $options, plan: $plan, quota: $quota)';
}


}

/// @nodoc
abstract mixin class $ExportFailedCopyWith<$Res> implements $ExportStateCopyWith<$Res> {
  factory $ExportFailedCopyWith(ExportFailed value, $Res Function(ExportFailed) _then) = _$ExportFailedCopyWithImpl;
@useResult
$Res call({
 ExportFailure failure, Project project, ExportOptions options, BeatPackPlan plan, ExportQuota quota
});


$ProjectCopyWith<$Res> get project;

}
/// @nodoc
class _$ExportFailedCopyWithImpl<$Res>
    implements $ExportFailedCopyWith<$Res> {
  _$ExportFailedCopyWithImpl(this._self, this._then);

  final ExportFailed _self;
  final $Res Function(ExportFailed) _then;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,Object? project = null,Object? options = null,Object? plan = null,Object? quota = null,}) {
  return _then(ExportFailed(
failure: null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ExportFailure,project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as Project,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as ExportOptions,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as BeatPackPlan,quota: null == quota ? _self.quota : quota // ignore: cast_nullable_to_non_nullable
as ExportQuota,
  ));
}

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectCopyWith<$Res> get project {
  
  return $ProjectCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}

/// @nodoc


class ExportDone implements ExportState {
  const ExportDone({required this.pack, this.saved = false});
  

 final  BeatPack pack;
/// True after the user saved the pack to a folder they picked.
@JsonKey() final  bool saved;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExportDoneCopyWith<ExportDone> get copyWith => _$ExportDoneCopyWithImpl<ExportDone>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExportDone&&(identical(other.pack, pack) || other.pack == pack)&&(identical(other.saved, saved) || other.saved == saved));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pack,saved);
}

@override
String toString() {
    return 'ExportState.done(pack: $pack, saved: $saved)';
}


}

/// @nodoc
abstract mixin class $ExportDoneCopyWith<$Res> implements $ExportStateCopyWith<$Res> {
  factory $ExportDoneCopyWith(ExportDone value, $Res Function(ExportDone) _then) = _$ExportDoneCopyWithImpl;
@useResult
$Res call({
 BeatPack pack, bool saved
});




}
/// @nodoc
class _$ExportDoneCopyWithImpl<$Res>
    implements $ExportDoneCopyWith<$Res> {
  _$ExportDoneCopyWithImpl(this._self, this._then);

  final ExportDone _self;
  final $Res Function(ExportDone) _then;

/// Create a copy of ExportState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pack = null,Object? saved = null,}) {
  return _then(ExportDone(
pack: null == pack ? _self.pack : pack // ignore: cast_nullable_to_non_nullable
as BeatPack,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
