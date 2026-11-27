import 'dart:developer' as developer;

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'core/core.dart';
import 'features/export/data/repositories/export_repository.dart';
import 'features/projects/data/repositories/project_repository.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'shared/shared.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  try {
    await locator<SettingsRepository>().load();
  } catch (e) {
    developer.log('Settings load failed: $e', name: 'main');
  }
  try {
    await locator<ProjectRepository>().cleanUpOrphans().timeout(
      const Duration(milliseconds: 500),
    );
  } catch (e) {
    developer.log('Orphan project cleanup failed: $e', name: 'main');
  }
  try {
    await locator<ExportRepository>().cleanUpStaleParts().timeout(
      const Duration(milliseconds: 500),
    );
  } catch (e) {
    developer.log('Stale export cleanup failed: $e', name: 'main');
  }
  // Painters draw text directly, so fonts must be ready before first frame.
  // Don't block launch forever when offline; fall back to system fonts.
  try {
    await GoogleFonts.pendingFonts(KvText.preload)
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
  runApp(const KickVoltApp());
}
