import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../features/features.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: HomeRoute.page, initial: true),
    AutoRoute(page: AnalyzingRoute.page),
    AutoRoute(page: BeatEditorRoute.page),
  ];
}
