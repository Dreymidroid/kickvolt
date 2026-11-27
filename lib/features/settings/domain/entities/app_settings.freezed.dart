// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppSettings {

/// Tap-to-mark latency compensation in ms, clamped to `[-100, 500]`.
 int get latencyOffsetMs;/// Output route on which [latencyOffsetMs] was calibrated, or null if the
/// user hasn't calibrated yet. [OutputKind.unknown] is a real calibration
/// on a route we couldn't classify (e.g. Android BLE-audio headphones).
 OutputKind? get latencyCalibratedOn;/// Global haptics switch (§6.2).
 bool get hapticsEnabled;/// Export defaults (§6.4, M8 §5). The Export screen starts from these.
 ClickStyle get defaultClickStyle; AudioFormat get defaultAudioFormat; bool get includePreviewByDefault; bool get monoGuideTrack;/// Default beat-detection sensitivity for newly created projects (`0.25`
/// Low, `0.5` Balanced, `0.75` High).
 double get defaultSensitivity;/// Whether first-run onboarding has been completed or skipped (M8 §4.1).
 bool get onboardingDone;/// Whether first-run editor coach marks have been completed or skipped
/// (M8 §4.1, §4.3).
 bool get coachMarksDone;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AppSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.latencyOffsetMs, _this.latencyOffsetMs) || other.latencyOffsetMs == _this.latencyOffsetMs)&&(identical(other.latencyCalibratedOn, _this.latencyCalibratedOn) || other.latencyCalibratedOn == _this.latencyCalibratedOn)&&(identical(other.hapticsEnabled, _this.hapticsEnabled) || other.hapticsEnabled == _this.hapticsEnabled)&&(identical(other.defaultClickStyle, _this.defaultClickStyle) || other.defaultClickStyle == _this.defaultClickStyle)&&(identical(other.defaultAudioFormat, _this.defaultAudioFormat) || other.defaultAudioFormat == _this.defaultAudioFormat)&&(identical(other.includePreviewByDefault, _this.includePreviewByDefault) || other.includePreviewByDefault == _this.includePreviewByDefault)&&(identical(other.monoGuideTrack, _this.monoGuideTrack) || other.monoGuideTrack == _this.monoGuideTrack)&&(identical(other.defaultSensitivity, _this.defaultSensitivity) || other.defaultSensitivity == _this.defaultSensitivity)&&(identical(other.onboardingDone, _this.onboardingDone) || other.onboardingDone == _this.onboardingDone)&&(identical(other.coachMarksDone, _this.coachMarksDone) || other.coachMarksDone == _this.coachMarksDone));
}


@override
int get hashCode {
  final _this = this as AppSettings;
  return Object.hash(runtimeType,_this.latencyOffsetMs,_this.latencyCalibratedOn,_this.hapticsEnabled,_this.defaultClickStyle,_this.defaultAudioFormat,_this.includePreviewByDefault,_this.monoGuideTrack,_this.defaultSensitivity,_this.onboardingDone,_this.coachMarksDone);
}

@override
String toString() {
  final _this = this as AppSettings;
  return 'AppSettings(latencyOffsetMs: ${_this.latencyOffsetMs}, latencyCalibratedOn: ${_this.latencyCalibratedOn}, hapticsEnabled: ${_this.hapticsEnabled}, defaultClickStyle: ${_this.defaultClickStyle}, defaultAudioFormat: ${_this.defaultAudioFormat}, includePreviewByDefault: ${_this.includePreviewByDefault}, monoGuideTrack: ${_this.monoGuideTrack}, defaultSensitivity: ${_this.defaultSensitivity}, onboardingDone: ${_this.onboardingDone}, coachMarksDone: ${_this.coachMarksDone})';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 int latencyOffsetMs, OutputKind? latencyCalibratedOn, bool hapticsEnabled, ClickStyle defaultClickStyle, AudioFormat defaultAudioFormat, bool includePreviewByDefault, bool monoGuideTrack, double defaultSensitivity, bool onboardingDone, bool coachMarksDone
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latencyOffsetMs = null,Object? latencyCalibratedOn = freezed,Object? hapticsEnabled = null,Object? defaultClickStyle = null,Object? defaultAudioFormat = null,Object? includePreviewByDefault = null,Object? monoGuideTrack = null,Object? defaultSensitivity = null,Object? onboardingDone = null,Object? coachMarksDone = null,}) {
  return _then(AppSettings(
latencyOffsetMs: null == latencyOffsetMs ? _self.latencyOffsetMs : latencyOffsetMs // ignore: cast_nullable_to_non_nullable
as int,latencyCalibratedOn: freezed == latencyCalibratedOn ? _self.latencyCalibratedOn : latencyCalibratedOn // ignore: cast_nullable_to_non_nullable
as OutputKind?,hapticsEnabled: null == hapticsEnabled ? _self.hapticsEnabled : hapticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,defaultClickStyle: null == defaultClickStyle ? _self.defaultClickStyle : defaultClickStyle // ignore: cast_nullable_to_non_nullable
as ClickStyle,defaultAudioFormat: null == defaultAudioFormat ? _self.defaultAudioFormat : defaultAudioFormat // ignore: cast_nullable_to_non_nullable
as AudioFormat,includePreviewByDefault: null == includePreviewByDefault ? _self.includePreviewByDefault : includePreviewByDefault // ignore: cast_nullable_to_non_nullable
as bool,monoGuideTrack: null == monoGuideTrack ? _self.monoGuideTrack : monoGuideTrack // ignore: cast_nullable_to_non_nullable
as bool,defaultSensitivity: null == defaultSensitivity ? _self.defaultSensitivity : defaultSensitivity // ignore: cast_nullable_to_non_nullable
as double,onboardingDone: null == onboardingDone ? _self.onboardingDone : onboardingDone // ignore: cast_nullable_to_non_nullable
as bool,coachMarksDone: null == coachMarksDone ? _self.coachMarksDone : coachMarksDone // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int latencyOffsetMs,  OutputKind? latencyCalibratedOn,  bool hapticsEnabled,  ClickStyle defaultClickStyle,  AudioFormat defaultAudioFormat,  bool includePreviewByDefault,  bool monoGuideTrack,  double defaultSensitivity,  bool onboardingDone,  bool coachMarksDone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.latencyOffsetMs,_that.latencyCalibratedOn,_that.hapticsEnabled,_that.defaultClickStyle,_that.defaultAudioFormat,_that.includePreviewByDefault,_that.monoGuideTrack,_that.defaultSensitivity,_that.onboardingDone,_that.coachMarksDone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int latencyOffsetMs,  OutputKind? latencyCalibratedOn,  bool hapticsEnabled,  ClickStyle defaultClickStyle,  AudioFormat defaultAudioFormat,  bool includePreviewByDefault,  bool monoGuideTrack,  double defaultSensitivity,  bool onboardingDone,  bool coachMarksDone)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.latencyOffsetMs,_that.latencyCalibratedOn,_that.hapticsEnabled,_that.defaultClickStyle,_that.defaultAudioFormat,_that.includePreviewByDefault,_that.monoGuideTrack,_that.defaultSensitivity,_that.onboardingDone,_that.coachMarksDone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int latencyOffsetMs,  OutputKind? latencyCalibratedOn,  bool hapticsEnabled,  ClickStyle defaultClickStyle,  AudioFormat defaultAudioFormat,  bool includePreviewByDefault,  bool monoGuideTrack,  double defaultSensitivity,  bool onboardingDone,  bool coachMarksDone)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.latencyOffsetMs,_that.latencyCalibratedOn,_that.hapticsEnabled,_that.defaultClickStyle,_that.defaultAudioFormat,_that.includePreviewByDefault,_that.monoGuideTrack,_that.defaultSensitivity,_that.onboardingDone,_that.coachMarksDone);case _:
  return null;

}
}

}

/// @nodoc


class _AppSettings implements AppSettings {
  const _AppSettings({this.latencyOffsetMs = 0, this.latencyCalibratedOn, this.hapticsEnabled = true, this.defaultClickStyle = ClickStyle.snap, this.defaultAudioFormat = AudioFormat.wav, this.includePreviewByDefault = false, this.monoGuideTrack = false, this.defaultSensitivity = 0.5, this.onboardingDone = false, this.coachMarksDone = false});
  

/// Tap-to-mark latency compensation in ms, clamped to `[-100, 500]`.
@override@JsonKey() final  int latencyOffsetMs;
/// Output route on which [latencyOffsetMs] was calibrated, or null if the
/// user hasn't calibrated yet. [OutputKind.unknown] is a real calibration
/// on a route we couldn't classify (e.g. Android BLE-audio headphones).
@override final  OutputKind? latencyCalibratedOn;
/// Global haptics switch (§6.2).
@override@JsonKey() final  bool hapticsEnabled;
/// Export defaults (§6.4, M8 §5). The Export screen starts from these.
@override@JsonKey() final  ClickStyle defaultClickStyle;
@override@JsonKey() final  AudioFormat defaultAudioFormat;
@override@JsonKey() final  bool includePreviewByDefault;
@override@JsonKey() final  bool monoGuideTrack;
/// Default beat-detection sensitivity for newly created projects (`0.25`
/// Low, `0.5` Balanced, `0.75` High).
@override@JsonKey() final  double defaultSensitivity;
/// Whether first-run onboarding has been completed or skipped (M8 §4.1).
@override@JsonKey() final  bool onboardingDone;
/// Whether first-run editor coach marks have been completed or skipped
/// (M8 §4.1, §4.3).
@override@JsonKey() final  bool coachMarksDone;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.latencyOffsetMs, latencyOffsetMs) || other.latencyOffsetMs == latencyOffsetMs)&&(identical(other.latencyCalibratedOn, latencyCalibratedOn) || other.latencyCalibratedOn == latencyCalibratedOn)&&(identical(other.hapticsEnabled, hapticsEnabled) || other.hapticsEnabled == hapticsEnabled)&&(identical(other.defaultClickStyle, defaultClickStyle) || other.defaultClickStyle == defaultClickStyle)&&(identical(other.defaultAudioFormat, defaultAudioFormat) || other.defaultAudioFormat == defaultAudioFormat)&&(identical(other.includePreviewByDefault, includePreviewByDefault) || other.includePreviewByDefault == includePreviewByDefault)&&(identical(other.monoGuideTrack, monoGuideTrack) || other.monoGuideTrack == monoGuideTrack)&&(identical(other.defaultSensitivity, defaultSensitivity) || other.defaultSensitivity == defaultSensitivity)&&(identical(other.onboardingDone, onboardingDone) || other.onboardingDone == onboardingDone)&&(identical(other.coachMarksDone, coachMarksDone) || other.coachMarksDone == coachMarksDone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,latencyOffsetMs,latencyCalibratedOn,hapticsEnabled,defaultClickStyle,defaultAudioFormat,includePreviewByDefault,monoGuideTrack,defaultSensitivity,onboardingDone,coachMarksDone);
}

@override
String toString() {
    return 'AppSettings(latencyOffsetMs: $latencyOffsetMs, latencyCalibratedOn: $latencyCalibratedOn, hapticsEnabled: $hapticsEnabled, defaultClickStyle: $defaultClickStyle, defaultAudioFormat: $defaultAudioFormat, includePreviewByDefault: $includePreviewByDefault, monoGuideTrack: $monoGuideTrack, defaultSensitivity: $defaultSensitivity, onboardingDone: $onboardingDone, coachMarksDone: $coachMarksDone)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 int latencyOffsetMs, OutputKind? latencyCalibratedOn, bool hapticsEnabled, ClickStyle defaultClickStyle, AudioFormat defaultAudioFormat, bool includePreviewByDefault, bool monoGuideTrack, double defaultSensitivity, bool onboardingDone, bool coachMarksDone
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latencyOffsetMs = null,Object? latencyCalibratedOn = freezed,Object? hapticsEnabled = null,Object? defaultClickStyle = null,Object? defaultAudioFormat = null,Object? includePreviewByDefault = null,Object? monoGuideTrack = null,Object? defaultSensitivity = null,Object? onboardingDone = null,Object? coachMarksDone = null,}) {
  return _then(_AppSettings(
latencyOffsetMs: null == latencyOffsetMs ? _self.latencyOffsetMs : latencyOffsetMs // ignore: cast_nullable_to_non_nullable
as int,latencyCalibratedOn: freezed == latencyCalibratedOn ? _self.latencyCalibratedOn : latencyCalibratedOn // ignore: cast_nullable_to_non_nullable
as OutputKind?,hapticsEnabled: null == hapticsEnabled ? _self.hapticsEnabled : hapticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,defaultClickStyle: null == defaultClickStyle ? _self.defaultClickStyle : defaultClickStyle // ignore: cast_nullable_to_non_nullable
as ClickStyle,defaultAudioFormat: null == defaultAudioFormat ? _self.defaultAudioFormat : defaultAudioFormat // ignore: cast_nullable_to_non_nullable
as AudioFormat,includePreviewByDefault: null == includePreviewByDefault ? _self.includePreviewByDefault : includePreviewByDefault // ignore: cast_nullable_to_non_nullable
as bool,monoGuideTrack: null == monoGuideTrack ? _self.monoGuideTrack : monoGuideTrack // ignore: cast_nullable_to_non_nullable
as bool,defaultSensitivity: null == defaultSensitivity ? _self.defaultSensitivity : defaultSensitivity // ignore: cast_nullable_to_non_nullable
as double,onboardingDone: null == onboardingDone ? _self.onboardingDone : onboardingDone // ignore: cast_nullable_to_non_nullable
as bool,coachMarksDone: null == coachMarksDone ? _self.coachMarksDone : coachMarksDone // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
