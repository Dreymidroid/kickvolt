import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/audio_native/audio_native_client.dart';
import '../../../core/di/locator.dart';
import '../../settings/data/repositories/settings_repository.dart';
import '../domain/first_run.dart';

part 'onboarding_cubit.freezed.dart';
part 'onboarding_state.dart';

/// Drives the 3-page first-run onboarding flow (`Main`, `Onboarding2`,
/// `Onboarding3`, M8 §4.1–§4.2).
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({SettingsRepository? settingsRepository, AudioNative? audio})
    : _settings = settingsRepository ?? locator<SettingsRepository>(),
      _audio = audio ?? locator<AudioNative>(),
      super(const OnboardingState());

  final SettingsRepository _settings;
  final AudioNative _audio;

  void setPage(int index) {
    final clamped = index.clamp(0, 2);
    if (clamped != state.pageIndex) {
      emit(state.copyWith(pageIndex: clamped));
    }
  }

  void nextPage() => setPage(state.pageIndex + 1);

  void previousPage() => setPage(state.pageIndex - 1);

  /// Marks `onboardingDone = true` without requesting permissions ("Skip" on
  /// any page or "Not now" on page 3).
  Future<void> skip() async {
    if (state.isSubmitting || state.completed) return;
    emit(state.copyWith(isSubmitting: true));
    await _finishOnboarding();
  }

  /// Alias for [skip] on the permissions screen ("Not now").
  Future<void> notNow() => skip();

  /// Requests audio/music-library access through the native Pigeon bridge, then
  /// marks `onboardingDone = true` regardless of whether access was granted or
  /// denied (§4.2).
  Future<void> allowAccess() async {
    if (state.isSubmitting || state.completed) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _audio.requestAudioPermission();
    } catch (_) {
      // A denied or unsupported permission does not block entering the app:
      // Files import needs no permission, and library import surfaces its own
      // message if needed.
    }
    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    try {
      final loaded = await _settings.load();
      await _settings.save(completeOnboarding(loaded));
    } catch (_) {
      await _settings.save(completeOnboarding(_settings.current));
    }
    if (!isClosed) {
      emit(state.copyWith(isSubmitting: false, completed: true));
    }
  }
}
