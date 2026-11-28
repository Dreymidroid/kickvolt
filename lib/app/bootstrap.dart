import 'dart:developer' as developer;

import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../core/core.dart';
import '../features/export/data/repositories/export_repository.dart';
import '../features/projects/data/repositories/project_repository.dart';
import '../features/settings/data/repositories/settings_repository.dart';
import '../shared/shared.dart';

/// Everything `main()` does before `runApp`: registers services, loads
/// settings, cleans up leftovers from a previous run and preloads fonts.
///
/// [overrides] runs right after the default registrations, with
/// re-registration allowed, so integration tests can swap the few services
/// that open system UI (pickers, share sheet, folder picker, haptics).
/// `main()` passes none.
Future<void> bootstrap({void Function(GetIt locator)? overrides}) async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  if (overrides != null) {
    final previous = locator.allowReassignment;
    locator.allowReassignment = true;
    try {
      overrides(locator);
    } finally {
      locator.allowReassignment = previous;
    }
  }
  try {
    await locator<SettingsRepository>().load();
  } catch (e) {
    developer.log('Settings load failed: $e', name: 'bootstrap');
  }
  try {
    await locator<ProjectRepository>().cleanUpOrphans().timeout(
      const Duration(milliseconds: 500),
    );
  } catch (e) {
    developer.log('Orphan project cleanup failed: $e', name: 'bootstrap');
  }
  try {
    await locator<ExportRepository>().cleanUpStaleParts().timeout(
      const Duration(milliseconds: 500),
    );
  } catch (e) {
    developer.log('Stale export cleanup failed: $e', name: 'bootstrap');
  }
  // Painters draw text directly, so fonts must be ready before first frame.
  // Don't block launch forever when offline; fall back to system fonts.
  try {
    await GoogleFonts.pendingFonts(KvText.preload)
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
}
