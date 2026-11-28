import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../app/app_constants.dart';
import '../../../core/audio_math/click_synth.dart';
import '../../../core/di/locator.dart';
import '../../export/domain/entities/export_options.dart';
import '../data/external_link_service.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/entities/app_settings.dart';
import '../domain/sensitivity_preset.dart';

part 'settings_cubit.freezed.dart';
part 'settings_state.dart';

/// Manages the Settings screen over [SettingsRepository] (M8 §5). Every change
/// is persisted immediately.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    SettingsRepository? repository,
    ExternalLinkService? linkService,
  }) : _repository = repository ?? locator<SettingsRepository>(),
       _links = linkService ?? locator<ExternalLinkService>(),
       super(const SettingsState.loading());

  final SettingsRepository _repository;
  final ExternalLinkService _links;

  Future<void> load() async {
    emit(const SettingsState.loading());
    try {
      final loaded = await _repository.load();
      if (!isClosed) emit(SettingsState.ready(settings: loaded));
    } catch (e) {
      if (!isClosed) emit(SettingsState.error(error: e.toString()));
    }
  }

  /// Refreshes after returning from a sub-screen (such as latency calibration)
  /// without flashing the loading spinner.
  Future<void> refresh() async {
    try {
      final loaded = await _repository.load();
      if (!isClosed) emit(SettingsState.ready(settings: loaded));
    } catch (e) {
      final cur = state;
      if (!isClosed && cur is SettingsReady) {
        emit(cur.copyWith(error: e.toString()));
      }
    }
  }

  Future<void> _saveMutated(AppSettings Function(AppSettings) mutate) async {
    final cur = state;
    final base = cur is SettingsReady ? cur.settings : _repository.current;
    final next = mutate(base);
    try {
      final saved = await _repository.save(next);
      if (!isClosed) emit(SettingsState.ready(settings: saved));
    } catch (e) {
      if (!isClosed) {
        emit(SettingsState.ready(settings: base, error: e.toString()));
      }
    }
  }

  Future<void> setDefaultClickStyle(ClickStyle style) =>
      _saveMutated((s) => s.copyWith(defaultClickStyle: style));

  Future<void> setDefaultAudioFormat(AudioFormat format) =>
      _saveMutated((s) => s.copyWith(defaultAudioFormat: format));

  Future<void> setMonoGuideTrack(bool enabled) =>
      _saveMutated((s) => s.copyWith(monoGuideTrack: enabled));

  Future<void> setIncludePreviewByDefault(bool enabled) =>
      _saveMutated((s) => s.copyWith(includePreviewByDefault: enabled));

  Future<void> setIncludeVideoByDefault(bool enabled) =>
      _saveMutated((s) => s.copyWith(includeVideoByDefault: enabled));

  Future<void> setSensitivityPreset(SensitivityPreset preset) =>
      _saveMutated((s) => s.withSensitivityPreset(preset));

  Future<void> setHapticsEnabled(bool enabled) =>
      _saveMutated((s) => s.copyWith(hapticsEnabled: enabled));

  Future<bool> sendFeedback() =>
      _links.openFeedbackEmail(AppConstants.feedbackEmail);

  Future<bool> openPrivacyPolicy() =>
      _links.openPrivacyPolicy(AppConstants.privacyUrl);
}
