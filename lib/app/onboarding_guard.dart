import 'package:auto_route/auto_route.dart';

import '../core/di/locator.dart';
import '../features/onboarding/domain/first_run.dart';
import '../features/settings/data/repositories/settings_repository.dart';
import 'app_router.dart';

/// Redirects the initial Home route to [OnboardingRoute] before the first frame
/// whenever `onboardingDone` is `false` (M8 §4.1).
class OnboardingGuard extends AutoRouteGuard {
  OnboardingGuard({SettingsRepository? settingsRepository})
    : _settings = settingsRepository ?? locator<SettingsRepository>();

  final SettingsRepository _settings;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (shouldShowOnboarding(_settings.current)) {
      router.push(OnboardingRoute());
      resolver.next(false);
    } else {
      resolver.next(true);
    }
  }
}
