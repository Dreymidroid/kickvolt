import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'core/core.dart';
import 'shared/shared.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  // Painters draw text directly, so fonts must be ready before first frame.
  // Don't block launch forever when offline; fall back to system fonts.
  try {
    await GoogleFonts.pendingFonts(KvText.preload)
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
  runApp(const KickVoltApp());
}
