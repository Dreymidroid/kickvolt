import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

/// Audio output route classification used for latency calibration and
/// Bluetooth delay warnings (§6.1, §6.3).
enum OutputKind { unknown, builtIn, wired, bluetooth }

/// Persisted user settings (§6.1).
///
/// Latency offset is stored in milliseconds (never sample frames) because
/// different songs can have different sample rates; convert per project with
/// `project.msToSamples(latencyOffsetMs)`.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// Tap-to-mark latency compensation in ms, clamped to `[-100, 500]`.
    @Default(0) int latencyOffsetMs,

    /// Output route on which [latencyOffsetMs] was calibrated.
    /// [OutputKind.unknown] means not yet calibrated.
    @Default(OutputKind.unknown) OutputKind latencyCalibratedOn,

    /// Global haptics switch (§6.2).
    @Default(true) bool hapticsEnabled,
  }) = _AppSettings;
}
