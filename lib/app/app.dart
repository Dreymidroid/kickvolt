import 'package:material_ui/material_ui.dart';

import 'app_router.dart';
import 'app_theme.dart';

class KickVoltApp extends StatefulWidget {
  const KickVoltApp({super.key, this.router});

  final AppRouter? router;

  @override
  State<KickVoltApp> createState() => _KickVoltAppState();
}

class _KickVoltAppState extends State<KickVoltApp> {
  late final AppRouter _router = widget.router ?? AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KickVolt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: _router.config(),
    );
  }
}
