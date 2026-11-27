import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/settings/settings.dart';

void main() {
  group('SensitivityPreset', () {
    test(
      'maps Low / Balanced / High to 0.25 / 0.5 / 0.75 and display labels',
      () {
        expect(SensitivityPreset.low.value, 0.25);
        expect(SensitivityPreset.low.label, 'Low');

        expect(SensitivityPreset.balanced.value, 0.5);
        expect(SensitivityPreset.balanced.label, 'Balanced');

        expect(SensitivityPreset.high.value, 0.75);
        expect(SensitivityPreset.high.label, 'High');
      },
    );

    test('fromValue round-trips each preset and classifies boundaries', () {
      for (final preset in SensitivityPreset.values) {
        expect(SensitivityPreset.fromValue(preset.value), preset);
      }

      expect(SensitivityPreset.fromValue(0.0), SensitivityPreset.low);
      expect(SensitivityPreset.fromValue(0.37), SensitivityPreset.low);
      expect(SensitivityPreset.fromValue(0.375), SensitivityPreset.balanced);
      expect(SensitivityPreset.fromValue(0.5), SensitivityPreset.balanced);
      expect(SensitivityPreset.fromValue(0.625), SensitivityPreset.balanced);
      expect(SensitivityPreset.fromValue(0.626), SensitivityPreset.high);
      expect(SensitivityPreset.fromValue(1.0), SensitivityPreset.high);
    });

    test('AppSettings exposes sensitivityPreset and withSensitivityPreset', () {
      const defaults = AppSettings();
      expect(defaults.defaultSensitivity, 0.5);
      expect(defaults.sensitivityPreset, SensitivityPreset.balanced);

      final low = defaults.withSensitivityPreset(SensitivityPreset.low);
      expect(low.defaultSensitivity, 0.25);
      expect(low.sensitivityPreset, SensitivityPreset.low);

      final high = defaults.withSensitivityPreset(SensitivityPreset.high);
      expect(high.defaultSensitivity, 0.75);
      expect(high.sensitivityPreset, SensitivityPreset.high);
    });
  });
}
