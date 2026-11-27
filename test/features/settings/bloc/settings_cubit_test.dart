import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/app/app_constants.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:kickvolt/features/settings/settings.dart';

import '../../../fixtures/editor_fakes.dart';

class _RecordingLinks implements ExternalLinkService {
  final opened = <String>[];

  @override
  Future<bool> openFeedbackEmail(String email) async {
    opened.add('mail:$email');
    return true;
  }

  @override
  Future<bool> openPrivacyPolicy(String url) async {
    opened.add(url);
    return true;
  }
}

class _FailingSettingsRepository extends FakeSettingsRepository {
  @override
  Future<AppSettings> save(AppSettings settings) async =>
      throw StateError('disk');
}

void main() {
  late FakeSettingsRepository repo;
  late _RecordingLinks links;

  setUp(() {
    repo = FakeSettingsRepository();
    links = _RecordingLinks();
  });

  SettingsCubit build() =>
      SettingsCubit(repository: repo, linkService: links);

  blocTest<SettingsCubit, SettingsState>(
    'load emits loading then ready with stored settings',
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const SettingsState.loading(),
      const SettingsState.ready(settings: AppSettings()),
    ],
  );

  group('each setting is persisted immediately', () {
    Future<void> check(
      Future<void> Function(SettingsCubit c) act,
      bool Function(AppSettings s) persisted,
    ) async {
      final c = build();
      await c.load();
      await act(c);
      expect(persisted(repo.current), isTrue);
      final state = c.state;
      expect(state, isA<SettingsReady>());
      expect(persisted((state as SettingsReady).settings), isTrue);
      await c.close();
    }

    test('click style', () async {
      await check(
        (c) => c.setDefaultClickStyle(ClickStyle.kick),
        (s) => s.defaultClickStyle == ClickStyle.kick,
      );
    });

    test('audio format', () async {
      await check(
        (c) => c.setDefaultAudioFormat(AudioFormat.m4a),
        (s) => s.defaultAudioFormat == AudioFormat.m4a,
      );
    });

    test('mono guide track', () async {
      await check(
        (c) => c.setMonoGuideTrack(true),
        (s) => s.monoGuideTrack,
      );
    });

    test('preview mix in packs', () async {
      final initial = repo.current.includePreviewByDefault;
      await check(
        (c) => c.setIncludePreviewByDefault(!initial),
        (s) => s.includePreviewByDefault == !initial,
      );
    });

    test('haptics', () async {
      await check(
        (c) => c.setHapticsEnabled(false),
        (s) => !s.hapticsEnabled,
      );
    });

    for (final preset in SensitivityPreset.values) {
      test('sensitivity ${preset.label} -> ${preset.value}', () async {
        await check(
          (c) => c.setSensitivityPreset(preset),
          (s) => s.defaultSensitivity == preset.value,
        );
      });
    }
  });

  test('a failed save keeps the previous settings and reports it', () async {
    final failing = _FailingSettingsRepository();
    final c = SettingsCubit(repository: failing, linkService: links);
    await c.load();
    await c.setHapticsEnabled(false);
    final state = c.state as SettingsReady;
    expect(state.settings.hapticsEnabled, isTrue);
    expect(state.error, contains('disk'));
    await c.close();
  });

  test('feedback and privacy open the configured targets', () async {
    final c = build();
    await c.sendFeedback();
    await c.openPrivacyPolicy();
    expect(links.opened, [
      'mail:${AppConstants.feedbackEmail}',
      AppConstants.privacyUrl,
    ]);
    await c.close();
  });
}
