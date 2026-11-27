/// App-wide configuration.
abstract final class AppConstants {
  /// Free tier: beat-pack exports allowed per rolling 7 days. One pack (all
  /// its files) counts as one export.
  static const freeExportsPerWeek = 30;

  /// App version kept equal to `pubspec.yaml`'s `version` field (verified by
  /// `test/app/app_version_test.dart`).
  static const String appVersion = '1.0.0+1';

  /// Placeholder feedback address; fill in before store release (M8 D2).
  static const String feedbackEmail = 'feedback@kickvolt.app';

  /// Placeholder privacy-policy URL; fill in before store release (M8 D2).
  static const String privacyUrl = 'https://kickvolt.app/privacy';
}
