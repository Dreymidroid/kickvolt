import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/features/export/export.dart';
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
      expect(s.latencyCalibratedOn, isNull);
      expect(s.hapticsEnabled, isTrue);
      expect(s.defaultClickStyle, ClickStyle.snap);
      expect(s.defaultAudioFormat, AudioFormat.wav);
      expect(s.includePreviewByDefault, isFalse);
      expect(s.monoGuideTrack, isFalse);
      expect(s.defaultSensitivity, 0.5);
      expect(s.onboardingDone, isFalse);
      expect(s.coachMarksDone, isFalse);
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
          defaultClickStyle: ClickStyle.kick,
          defaultAudioFormat: AudioFormat.m4a,
          includePreviewByDefault: true,
          monoGuideTrack: true,
          defaultSensitivity: 0.75,
          onboardingDone: true,
          coachMarksDone: true,
        ),
      );

      final repo2 = SettingsRepositoryImpl();
      final loaded = await repo2.load();
      expect(loaded.latencyOffsetMs, 42);
      expect(loaded.latencyCalibratedOn, OutputKind.bluetooth);
      expect(loaded.hapticsEnabled, isFalse);
      expect(loaded.defaultClickStyle, ClickStyle.kick);
      expect(loaded.defaultAudioFormat, AudioFormat.m4a);
      expect(loaded.includePreviewByDefault, isTrue);
      expect(loaded.monoGuideTrack, isTrue);
      expect(loaded.defaultSensitivity, 0.75);
      expect(loaded.onboardingDone, isTrue);
      expect(loaded.coachMarksDone, isTrue);
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

    test('clamps defaultSensitivity to [0.0, 1.0] on save and load', () async {
      SharedPreferences.setMockInitialValues({
        SettingsRepositoryImpl.DEFAULT_SENSITIVITY: 2.5,
      });
      final repo = SettingsRepositoryImpl();
      expect((await repo.load()).defaultSensitivity, 1.0);

      final savedLow = await repo.save(
        const AppSettings(defaultSensitivity: -0.5),
      );
      expect(savedLow.defaultSensitivity, 0.0);
      expect(repo.current.defaultSensitivity, 0.0);
    });

    test('a calibration on an unknown route is kept as calibrated', () async {
      SharedPreferences.setMockInitialValues({});
      await SettingsRepositoryImpl().save(
        const AppSettings(
          latencyOffsetMs: 120,
          latencyCalibratedOn: OutputKind.unknown,
        ),
      );
      final loaded = await SettingsRepositoryImpl().load();
      expect(loaded.latencyCalibratedOn, OutputKind.unknown);
      expect(loaded.latencyOffsetMs, 120);

      // Clearing the calibration removes the key again.
      await SettingsRepositoryImpl().save(
        loaded.copyWith(latencyCalibratedOn: null),
      );
      expect(
        (await SettingsRepositoryImpl().load()).latencyCalibratedOn,
        isNull,
      );
    });
  });
}
