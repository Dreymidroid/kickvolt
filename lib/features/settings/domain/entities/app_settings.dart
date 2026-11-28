import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/audio_math/click_synth.dart';
import '../../../export/domain/entities/export_options.dart';

part 'app_settings.freezed.dart';

/// Audio output route classification used for latency calibration and
/// Bluetooth delay warnings (§6.1, §6.3).
enum OutputKind { unknown, builtIn, wired, bluetooth }

/// Persisted user settings (§6.1, M8 §4.1, M8 §5).
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

    /// Export defaults (§6.4, M8 §5). The Export screen starts from these.
    @Default(ClickStyle.snap) ClickStyle defaultClickStyle,
    @Default(AudioFormat.wav) AudioFormat defaultAudioFormat,
    @Default(false) bool includePreviewByDefault,

    /// "Guide video in packs" (M7 §7): the Export screen's video default.
    @Default(false) bool includeVideoByDefault,
    @Default(false) bool monoGuideTrack,

    /// Default beat-detection sensitivity for newly created projects (`0.25`
    /// Low, `0.5` Balanced, `0.75` High).
    @Default(0.5) double defaultSensitivity,

    /// Whether first-run onboarding has been completed or skipped (M8 §4.1).
    @Default(false) bool onboardingDone,

    /// Whether first-run editor coach marks have been completed or skipped
    /// (M8 §4.1, §4.3).
    @Default(false) bool coachMarksDone,
  }) = _AppSettings;
}
