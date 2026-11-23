import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepositoryImpl', () {
    test('returns defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepositoryImpl();
      final s = await repo.load();
      expect(s.latencyOffsetMs, 0);
      expect(s.latencyCalibratedOn, OutputKind.unknown);
      expect(s.hapticsEnabled, isTrue);
      expect(repo.current, s);
    });

    test('round-trips saved values across instances', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = SettingsRepositoryImpl();
      await repo1.save(
        const AppSettings(
          latencyOffsetMs: 42,
          latencyCalibratedOn: OutputKind.bluetooth,
          hapticsEnabled: false,
        ),
      );

      final repo2 = SettingsRepositoryImpl();
      final loaded = await repo2.load();
      expect(loaded.latencyOffsetMs, 42);
      expect(loaded.latencyCalibratedOn, OutputKind.bluetooth);
      expect(loaded.hapticsEnabled, isFalse);
    });

    test('clamps latencyOffsetMs to [-100, 500] on save and load', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepositoryImpl.LATENCY_OFFSET_MS: 999,
      });
      final repo = SettingsRepositoryImpl();
      final loaded = await repo.load();
      expect(loaded.latencyOffsetMs, 500);

      final savedLow = await repo.save(
        const AppSettings(latencyOffsetMs: -250),
      );
      expect(savedLow.latencyOffsetMs, -100);
      expect(repo.current.latencyOffsetMs, -100);
    });
  });
}
