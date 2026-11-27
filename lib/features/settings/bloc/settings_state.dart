part of 'settings_cubit.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState.loading() = SettingsLoading;
  const factory SettingsState.ready({
    required AppSettings settings,
    String? error,
  }) = SettingsReady;
  const factory SettingsState.error({required String error}) = SettingsError;
}
