import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/onboarding/onboarding.dart';
import 'package:kickvolt/features/settings/settings.dart';

import '../../../fixtures/editor_fakes.dart';
import '../../../fixtures/export_fakes.dart';

class _Audio extends FakeCubitAudioNative {
  _Audio({this.throws = false});

  final bool throws;
  int calls = 0;

  @override
  Future<bool> requestAudioPermission() async {
    calls++;
    if (throws) throw StateError('denied');
    return false;
  }
}

void main() {
  late FakeSettingsRepository settings;

  setUp(() => settings = FakeSettingsRepository());

  test('pages clamp to 0..2', () async {
    final c = OnboardingCubit(settingsRepository: settings, audio: _Audio());
    c.previousPage();
    expect(c.state.pageIndex, 0);
    c
      ..nextPage()
      ..nextPage()
      ..nextPage();
    expect(c.state.pageIndex, 2);
    await c.close();
  });

  test('skip sets onboardingDone without a permission prompt', () async {
    final audio = _Audio();
    final c = OnboardingCubit(settingsRepository: settings, audio: audio);
    await c.skip();
    expect(settings.current.onboardingDone, isTrue);
    expect(audio.calls, 0);
    expect(c.state.completed, isTrue);
    await c.close();
  });

  test('allowAccess prompts once and finishes even when denied', () async {
    final audio = _Audio();
    final c = OnboardingCubit(settingsRepository: settings, audio: audio);
    await c.allowAccess();
    await c.allowAccess(); // second tap ignored
    expect(audio.calls, 1);
    expect(settings.current.onboardingDone, isTrue);
    await c.close();
  });

  test('allowAccess finishes when the native call throws', () async {
    final c = OnboardingCubit(
      settingsRepository: settings,
      audio: _Audio(throws: true),
    );
    await c.allowAccess();
    expect(settings.current.onboardingDone, isTrue);
    expect(c.state.completed, isTrue);
    await c.close();
  });

  test('onboarding keeps other settings', () async {
    await settings.save(const AppSettings(hapticsEnabled: false));
    final c = OnboardingCubit(settingsRepository: settings, audio: _Audio());
    await c.notNow();
    expect(settings.current.hapticsEnabled, isFalse);
    expect(settings.current.onboardingDone, isTrue);
    await c.close();
  });
}
