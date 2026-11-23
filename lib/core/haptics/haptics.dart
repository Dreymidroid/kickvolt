import 'package:flutter/services.dart';

import '../../features/settings/data/repositories/settings_repository.dart';

/// App-wide haptics service (§6.2), honouring the global `hapticsEnabled`
/// setting. Injectable so tests use a recording fake.
abstract interface class Haptics {
  /// Marker placed (add, long-press, tap), snapped, or nudged.
  Future<void> selectionClick();

  /// Strong beat (strong or downbeat) passes playhead while playing + Clicks on.
  Future<void> lightImpact();

  /// Drop passes playhead while playing.
  Future<void> heavyImpact();

  /// Detection committed (and in M6, export finished).
  Future<void> successNotification();

  /// Delete marker or clear range.
  Future<void> warningNotification();
}

class HapticsImpl implements Haptics {
  HapticsImpl({required this._settings});

  final SettingsRepository _settings;

  bool get _enabled => _settings.current.hapticsEnabled;

  @override
  Future<void> selectionClick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  @override
  Future<void> lightImpact() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> heavyImpact() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  @override
  Future<void> successNotification() async {
    if (!_enabled) return;
    await HapticFeedback.successNotification();
  }

  @override
  Future<void> warningNotification() async {
    if (!_enabled) return;
    await HapticFeedback.warningNotification();
  }
}
