import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../features/features.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    // Editor is the entry point until Home and onboarding are built.
    AutoRoute(page: BeatEditorRoute.page, initial: true),
  ];
}
