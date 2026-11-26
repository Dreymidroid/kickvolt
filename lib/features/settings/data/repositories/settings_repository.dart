// Project rules (.ai/rules/structure.md & M5 §6.1) require UPPER_SNAKE_CASE
// storage key constants.
// ignore_for_file: constant_identifier_names

import 'package:shared_preferences/shared_preferences.dart';

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

    _current = AppSettings(
      latencyOffsetMs: clampedOffset,
      latencyCalibratedOn: kind,
      hapticsEnabled: haptics,
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
    _current = clamped;
    return clamped;
  }
}
