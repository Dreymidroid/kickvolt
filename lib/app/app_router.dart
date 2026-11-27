import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../features/features.dart';
import 'onboarding_guard.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey, SettingsRepository? settingsRepository})
    : _onboardingGuard = OnboardingGuard(
        settingsRepository: settingsRepository,
      );

  final OnboardingGuard _onboardingGuard;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: HomeRoute.page, initial: true, guards: [_onboardingGuard]),
    AutoRoute(page: OnboardingRoute.page),
    AutoRoute(page: AnalyzingRoute.page),
    AutoRoute(page: BeatEditorRoute.page),
    AutoRoute(page: ExportRoute.page),
    AutoRoute(page: HowToRoute.page),
    AutoRoute(page: SettingsRoute.page),
    AutoRoute(page: LatencyCalibrationRoute.page),
  ];
}
