import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/audio_math/click_synth.dart';
import '../../../export/domain/entities/export_options.dart';

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

    /// Output route on which [latencyOffsetMs] was calibrated, or null if the
    /// user hasn't calibrated yet. [OutputKind.unknown] is a real calibration
    /// on a route we couldn't classify (e.g. Android BLE-audio headphones).
    OutputKind? latencyCalibratedOn,

    /// Global haptics switch (§6.2).
    @Default(true) bool hapticsEnabled,

    /// Export defaults (§6.4). The Export screen starts from these.
    @Default(ClickStyle.snap) ClickStyle defaultClickStyle,
    @Default(AudioFormat.wav) AudioFormat defaultAudioFormat,
    @Default(false) bool includePreviewByDefault,
    @Default(false) bool monoGuideTrack,
  }) = _AppSettings;
}
