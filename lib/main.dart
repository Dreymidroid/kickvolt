import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  await bootstrap();
  runApp(const KickVoltApp());
}
