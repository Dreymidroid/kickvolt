import 'entities/app_settings.dart';

/// User-facing presets for new-project detection sensitivity (§5).
enum SensitivityPreset {
  low(0.25, 'Low'),
  balanced(0.5, 'Balanced'),
  high(0.75, 'High');

  const SensitivityPreset(this.value, this.label);

  /// Sensitivity value in `[0.0, 1.0]` passed to `DetectionSettings`.
  final double value;

  /// Display label shown in Settings.
  final String label;

  /// Maps any stored sensitivity value in `[0.0, 1.0]` to its nearest preset.
  static SensitivityPreset fromValue(double v) {
    if (v < 0.375) return SensitivityPreset.low;
    if (v <= 0.625) return SensitivityPreset.balanced;
    return SensitivityPreset.high;
  }
}

extension AppSettingsSensitivityX on AppSettings {
  SensitivityPreset get sensitivityPreset =>
      SensitivityPreset.fromValue(defaultSensitivity);

  AppSettings withSensitivityPreset(SensitivityPreset preset) =>
      copyWith(defaultSensitivity: preset.value);
}
