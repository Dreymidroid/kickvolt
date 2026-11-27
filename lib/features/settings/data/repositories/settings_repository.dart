// Project rules (.ai/rules/structure.md & M5 §6.1) require UPPER_SNAKE_CASE
// storage key constants.
// ignore_for_file: constant_identifier_names

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/audio_math/click_synth.dart';
import '../../../export/domain/entities/export_options.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/latency_calibration.dart';

/// Persists [AppSettings] scalar values (§6.1).
abstract interface class SettingsRepository {
  /// Returns the currently loaded settings synchronously (defaults until
  /// [load] has been called).
  AppSettings get current;

  /// Loads settings from persistent storage.
  Future<AppSettings> load();

  /// Saves [settings] (clamping `latencyOffsetMs` to `[-100, 500]`) and
  /// updates [current].
  Future<AppSettings> save(AppSettings settings);
}

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({Future<SharedPreferences> Function()? prefsProvider})
    : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  static const String LATENCY_OFFSET_MS = 'LATENCY_OFFSET_MS';
  static const String LATENCY_CALIBRATED_ON = 'LATENCY_CALIBRATED_ON';
  static const String HAPTICS_ENABLED = 'HAPTICS_ENABLED';
  static const String DEFAULT_CLICK_STYLE = 'DEFAULT_CLICK_STYLE';
  static const String DEFAULT_AUDIO_FORMAT = 'DEFAULT_AUDIO_FORMAT';
  static const String INCLUDE_PREVIEW_BY_DEFAULT = 'INCLUDE_PREVIEW_BY_DEFAULT';
  static const String MONO_GUIDE_TRACK = 'MONO_GUIDE_TRACK';

  final Future<SharedPreferences> Function() _prefsProvider;
  AppSettings _current = const AppSettings();

  @override
  AppSettings get current => _current;

  @override
  Future<AppSettings> load() async {
    final prefs = await _prefsProvider();
    final rawOffset = prefs.getInt(LATENCY_OFFSET_MS) ?? 0;
    final clampedOffset = rawOffset.clamp(
      kLatencyOffsetMinMs,
      kLatencyOffsetMaxMs,
    );
    final rawKind = prefs.getString(LATENCY_CALIBRATED_ON);
    final kind = rawKind == null
        ? null
        : OutputKind.values.where((k) => k.name == rawKind).firstOrNull;
    final haptics = prefs.getBool(HAPTICS_ENABLED) ?? true;
    final style = ClickStyle.values
        .where((s) => s.name == prefs.getString(DEFAULT_CLICK_STYLE))
        .firstOrNull;
    final format = AudioFormat.values
        .where((f) => f.name == prefs.getString(DEFAULT_AUDIO_FORMAT))
        .firstOrNull;

    _current = AppSettings(
      latencyOffsetMs: clampedOffset,
      latencyCalibratedOn: kind,
      hapticsEnabled: haptics,
      defaultClickStyle: style ?? ClickStyle.snap,
      defaultAudioFormat: format ?? AudioFormat.wav,
      includePreviewByDefault:
          prefs.getBool(INCLUDE_PREVIEW_BY_DEFAULT) ?? false,
      monoGuideTrack: prefs.getBool(MONO_GUIDE_TRACK) ?? false,
    );
    return _current;
  }

  @override
  Future<AppSettings> save(AppSettings settings) async {
    final clamped = settings.copyWith(
      latencyOffsetMs: settings.latencyOffsetMs.clamp(
        kLatencyOffsetMinMs,
        kLatencyOffsetMaxMs,
      ),
    );
    final prefs = await _prefsProvider();
    await prefs.setInt(LATENCY_OFFSET_MS, clamped.latencyOffsetMs);
    final calibratedOn = clamped.latencyCalibratedOn;
    if (calibratedOn == null) {
      await prefs.remove(LATENCY_CALIBRATED_ON);
    } else {
      await prefs.setString(LATENCY_CALIBRATED_ON, calibratedOn.name);
    }
    await prefs.setBool(HAPTICS_ENABLED, clamped.hapticsEnabled);
    await prefs.setString(DEFAULT_CLICK_STYLE, clamped.defaultClickStyle.name);
    await prefs.setString(
      DEFAULT_AUDIO_FORMAT,
      clamped.defaultAudioFormat.name,
    );
    await prefs.setBool(
      INCLUDE_PREVIEW_BY_DEFAULT,
      clamped.includePreviewByDefault,
    );
    await prefs.setBool(MONO_GUIDE_TRACK, clamped.monoGuideTrack);
    _current = clamped;
    return clamped;
  }
}
