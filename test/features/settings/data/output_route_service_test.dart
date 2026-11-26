import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/settings/settings.dart';

void main() {
  group('shouldShowBluetoothWarning', () {
    bool warn(OutputKind current, OutputKind? calibratedOn) =>
        shouldShowBluetoothWarning(
          currentOutput: current,
          calibratedOn: calibratedOn,
        );

    test('Bluetooth output without a Bluetooth calibration warns', () {
      expect(warn(OutputKind.bluetooth, null), isTrue);
      expect(warn(OutputKind.bluetooth, OutputKind.builtIn), isTrue);
      expect(warn(OutputKind.bluetooth, OutputKind.unknown), isTrue);
    });

    test('Bluetooth output calibrated on Bluetooth does not warn', () {
      expect(warn(OutputKind.bluetooth, OutputKind.bluetooth), isFalse);
    });

    test('calibrated on Bluetooth but now on a known other output warns', () {
      expect(warn(OutputKind.builtIn, OutputKind.bluetooth), isTrue);
      expect(warn(OutputKind.wired, OutputKind.bluetooth), isTrue);
      expect(warn(OutputKind.unknown, OutputKind.bluetooth), isFalse);
    });

    test('no Bluetooth involved does not warn', () {
      expect(warn(OutputKind.builtIn, null), isFalse);
      expect(warn(OutputKind.wired, OutputKind.builtIn), isFalse);
    });
  });
}
