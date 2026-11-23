// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'latency_calibration_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LatencyCalibrationState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LatencyCalibrationState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LatencyCalibrationState()';
}


}

/// @nodoc
class $LatencyCalibrationStateCopyWith<$Res>  {
$LatencyCalibrationStateCopyWith(LatencyCalibrationState _, $Res Function(LatencyCalibrationState) __);
}


/// Adds pattern-matching-related methods to [LatencyCalibrationState].
extension LatencyCalibrationStatePatterns on LatencyCalibrationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LatencyCalibrationLoading value)?  loading,TResult Function( LatencyCalibrationReady value)?  ready,TResult Function( LatencyCalibrationError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LatencyCalibrationLoading() when loading != null:
return loading(_that);case LatencyCalibrationReady() when ready != null:
return ready(_that);case LatencyCalibrationError() when error != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LatencyCalibrationLoading value)  loading,required TResult Function( LatencyCalibrationReady value)  ready,required TResult Function( LatencyCalibrationError value)  error,}){
final _that = this;
switch (_that) {
case LatencyCalibrationLoading():
return loading(_that);case LatencyCalibrationReady():
return ready(_that);case LatencyCalibrationError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LatencyCalibrationLoading value)?  loading,TResult? Function( LatencyCalibrationReady value)?  ready,TResult? Function( LatencyCalibrationError value)?  error,}){
final _that = this;
switch (_that) {
case LatencyCalibrationLoading() when loading != null:
return loading(_that);case LatencyCalibrationReady() when ready != null:
return ready(_that);case LatencyCalibrationError() when error != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( bool playing,  bool playbackUnavailable,  int validTapCount,  int requiredTaps,  CalibrationStatus status,  int? measuredOffsetMs,  OutputKind outputKind,  OutputKind calibratedOn,  int? reportedOutputLatencyMs,  bool saved)?  ready,TResult Function( String error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LatencyCalibrationLoading() when loading != null:
return loading();case LatencyCalibrationReady() when ready != null:
return ready(_that.playing,_that.playbackUnavailable,_that.validTapCount,_that.requiredTaps,_that.status,_that.measuredOffsetMs,_that.outputKind,_that.calibratedOn,_that.reportedOutputLatencyMs,_that.saved);case LatencyCalibrationError() when error != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( bool playing,  bool playbackUnavailable,  int validTapCount,  int requiredTaps,  CalibrationStatus status,  int? measuredOffsetMs,  OutputKind outputKind,  OutputKind calibratedOn,  int? reportedOutputLatencyMs,  bool saved)  ready,required TResult Function( String error)  error,}) {final _that = this;
switch (_that) {
case LatencyCalibrationLoading():
return loading();case LatencyCalibrationReady():
return ready(_that.playing,_that.playbackUnavailable,_that.validTapCount,_that.requiredTaps,_that.status,_that.measuredOffsetMs,_that.outputKind,_that.calibratedOn,_that.reportedOutputLatencyMs,_that.saved);case LatencyCalibrationError():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( bool playing,  bool playbackUnavailable,  int validTapCount,  int requiredTaps,  CalibrationStatus status,  int? measuredOffsetMs,  OutputKind outputKind,  OutputKind calibratedOn,  int? reportedOutputLatencyMs,  bool saved)?  ready,TResult? Function( String error)?  error,}) {final _that = this;
switch (_that) {
case LatencyCalibrationLoading() when loading != null:
return loading();case LatencyCalibrationReady() when ready != null:
return ready(_that.playing,_that.playbackUnavailable,_that.validTapCount,_that.requiredTaps,_that.status,_that.measuredOffsetMs,_that.outputKind,_that.calibratedOn,_that.reportedOutputLatencyMs,_that.saved);case LatencyCalibrationError() when error != null:
return error(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class LatencyCalibrationLoading extends LatencyCalibrationState {
  const LatencyCalibrationLoading(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LatencyCalibrationLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'LatencyCalibrationState.loading()';
}


}




/// @nodoc


class LatencyCalibrationReady extends LatencyCalibrationState {
  const LatencyCalibrationReady({this.playing = false, this.playbackUnavailable = false, this.validTapCount = 0, this.requiredTaps = kCalibrationMinTaps, this.status = CalibrationStatus.needMoreTaps, this.measuredOffsetMs, this.outputKind = OutputKind.unknown, this.calibratedOn = OutputKind.unknown, this.reportedOutputLatencyMs, this.saved = false}): super._();
  

@JsonKey() final  bool playing;
@JsonKey() final  bool playbackUnavailable;
@JsonKey() final  int validTapCount;
@JsonKey() final  int requiredTaps;
@JsonKey() final  CalibrationStatus status;
 final  int? measuredOffsetMs;
@JsonKey() final  OutputKind outputKind;
@JsonKey() final  OutputKind calibratedOn;
 final  int? reportedOutputLatencyMs;
@JsonKey() final  bool saved;

/// Create a copy of LatencyCalibrationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LatencyCalibrationReadyCopyWith<LatencyCalibrationReady> get copyWith => _$LatencyCalibrationReadyCopyWithImpl<LatencyCalibrationReady>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LatencyCalibrationReady&&(identical(other.playing, playing) || other.playing == playing)&&(identical(other.playbackUnavailable, playbackUnavailable) || other.playbackUnavailable == playbackUnavailable)&&(identical(other.validTapCount, validTapCount) || other.validTapCount == validTapCount)&&(identical(other.requiredTaps, requiredTaps) || other.requiredTaps == requiredTaps)&&(identical(other.status, status) || other.status == status)&&(identical(other.measuredOffsetMs, measuredOffsetMs) || other.measuredOffsetMs == measuredOffsetMs)&&(identical(other.outputKind, outputKind) || other.outputKind == outputKind)&&(identical(other.calibratedOn, calibratedOn) || other.calibratedOn == calibratedOn)&&(identical(other.reportedOutputLatencyMs, reportedOutputLatencyMs) || other.reportedOutputLatencyMs == reportedOutputLatencyMs)&&(identical(other.saved, saved) || other.saved == saved));
}


@override
int get hashCode {
    return Object.hash(runtimeType,playing,playbackUnavailable,validTapCount,requiredTaps,status,measuredOffsetMs,outputKind,calibratedOn,reportedOutputLatencyMs,saved);
}

@override
String toString() {
    return 'LatencyCalibrationState.ready(playing: $playing, playbackUnavailable: $playbackUnavailable, validTapCount: $validTapCount, requiredTaps: $requiredTaps, status: $status, measuredOffsetMs: $measuredOffsetMs, outputKind: $outputKind, calibratedOn: $calibratedOn, reportedOutputLatencyMs: $reportedOutputLatencyMs, saved: $saved)';
}


}

/// @nodoc
abstract mixin class $LatencyCalibrationReadyCopyWith<$Res> implements $LatencyCalibrationStateCopyWith<$Res> {
  factory $LatencyCalibrationReadyCopyWith(LatencyCalibrationReady value, $Res Function(LatencyCalibrationReady) _then) = _$LatencyCalibrationReadyCopyWithImpl;
@useResult
$Res call({
 bool playing, bool playbackUnavailable, int validTapCount, int requiredTaps, CalibrationStatus status, int? measuredOffsetMs, OutputKind outputKind, OutputKind calibratedOn, int? reportedOutputLatencyMs, bool saved
});




}
/// @nodoc
class _$LatencyCalibrationReadyCopyWithImpl<$Res>
    implements $LatencyCalibrationReadyCopyWith<$Res> {
  _$LatencyCalibrationReadyCopyWithImpl(this._self, this._then);

  final LatencyCalibrationReady _self;
  final $Res Function(LatencyCalibrationReady) _then;

/// Create a copy of LatencyCalibrationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? playing = null,Object? playbackUnavailable = null,Object? validTapCount = null,Object? requiredTaps = null,Object? status = null,Object? measuredOffsetMs = freezed,Object? outputKind = null,Object? calibratedOn = null,Object? reportedOutputLatencyMs = freezed,Object? saved = null,}) {
  return _then(LatencyCalibrationReady(
playing: null == playing ? _self.playing : playing // ignore: cast_nullable_to_non_nullable
as bool,playbackUnavailable: null == playbackUnavailable ? _self.playbackUnavailable : playbackUnavailable // ignore: cast_nullable_to_non_nullable
as bool,validTapCount: null == validTapCount ? _self.validTapCount : validTapCount // ignore: cast_nullable_to_non_nullable
as int,requiredTaps: null == requiredTaps ? _self.requiredTaps : requiredTaps // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CalibrationStatus,measuredOffsetMs: freezed == measuredOffsetMs ? _self.measuredOffsetMs : measuredOffsetMs // ignore: cast_nullable_to_non_nullable
as int?,outputKind: null == outputKind ? _self.outputKind : outputKind // ignore: cast_nullable_to_non_nullable
as OutputKind,calibratedOn: null == calibratedOn ? _self.calibratedOn : calibratedOn // ignore: cast_nullable_to_non_nullable
as OutputKind,reportedOutputLatencyMs: freezed == reportedOutputLatencyMs ? _self.reportedOutputLatencyMs : reportedOutputLatencyMs // ignore: cast_nullable_to_non_nullable
as int?,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class LatencyCalibrationError extends LatencyCalibrationState {
  const LatencyCalibrationError({required this.error}): super._();
  

 final  String error;

/// Create a copy of LatencyCalibrationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LatencyCalibrationErrorCopyWith<LatencyCalibrationError> get copyWith => _$LatencyCalibrationErrorCopyWithImpl<LatencyCalibrationError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LatencyCalibrationError&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,error);
}

@override
String toString() {
    return 'LatencyCalibrationState.error(error: $error)';
}


}

/// @nodoc
abstract mixin class $LatencyCalibrationErrorCopyWith<$Res> implements $LatencyCalibrationStateCopyWith<$Res> {
  factory $LatencyCalibrationErrorCopyWith(LatencyCalibrationError value, $Res Function(LatencyCalibrationError) _then) = _$LatencyCalibrationErrorCopyWithImpl;
@useResult
$Res call({
 String error
});




}
/// @nodoc
class _$LatencyCalibrationErrorCopyWithImpl<$Res>
    implements $LatencyCalibrationErrorCopyWith<$Res> {
  _$LatencyCalibrationErrorCopyWithImpl(this._self, this._then);

  final LatencyCalibrationError _self;
  final $Res Function(LatencyCalibrationError) _then;

/// Create a copy of LatencyCalibrationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(LatencyCalibrationError(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
