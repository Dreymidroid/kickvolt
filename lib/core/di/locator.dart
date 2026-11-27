import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/playback/data/audio_playback.dart';
import '../../features/playback/data/just_audio_playback.dart';

import '../../features/beat_detection/data/repositories/beat_detection_repository.dart';
import '../../features/click_preview/data/repositories/click_preview_repository.dart';
import '../../features/export/data/repositories/export_repository.dart';
import '../../features/export/data/share_service.dart';
import '../../features/import/data/datasources/source_picker.dart';
import '../../features/import/data/repositories/import_repository.dart';
import '../../features/projects/data/repositories/project_repository.dart';
import '../../features/settings/data/external_link_service.dart';
import '../../features/settings/data/output_route_service.dart';
import '../../features/settings/data/repositories/settings_repository.dart';
import '../audio_native/audio_native_client.dart';
import '../entitlements/entitlement_service.dart';
import '../haptics/haptics.dart';
import '../storage/project_paths.dart';

final locator = GetIt.instance;

void setupLocator() {
  // External / platform.
  locator.registerLazySingleton<AudioNative>(AudioNativeClient.new);
  locator.registerLazySingleton<Future<ProjectPaths>>(
    () async => ProjectPaths((await getApplicationDocumentsDirectory()).path),
  );
  locator.registerLazySingleton<SettingsRepository>(SettingsRepositoryImpl.new);
  locator.registerLazySingleton<ExternalLinkService>(
    UrlLauncherExternalLinkService.new,
  );
  locator.registerLazySingleton<OutputRouteService>(
    AudioSessionOutputRouteService.new,
  );
  locator.registerLazySingleton<Haptics>(
    () => HapticsImpl(settings: locator<SettingsRepository>()),
  );

  // Datasources and repositories.
  locator.registerLazySingleton<SourcePicker>(
    () => SourcePickerImpl(audio: locator<AudioNative>()),
  );
  locator.registerLazySingleton<ImportRepository>(
    () => ImportRepositoryImpl(
      audio: locator<AudioNative>(),
      paths: () => locator<Future<ProjectPaths>>(),
    ),
  );
  locator.registerLazySingleton<ProjectRepository>(
    () => ProjectRepositoryImpl(
      paths: () => locator<Future<ProjectPaths>>(),
      settingsRepository: locator<SettingsRepository>(),
    ),
  );
  locator.registerLazySingleton<BeatDetectionRepository>(
    () => BeatDetectionRepositoryImpl(
      paths: () => locator<Future<ProjectPaths>>(),
      projectRepository: locator<ProjectRepository>(),
    ),
  );
  locator.registerLazySingleton<ClickPreviewRepository>(
    () => ClickPreviewRepositoryImpl(
      paths: () => locator<Future<ProjectPaths>>(),
    ),
  );

  // A new player per editor; the editor disposes it.
  locator.registerFactory<AudioPlayback>(JustAudioPlayback.new);

  // Export (M6) and the one place that answers "is this allowed?".
  locator.registerLazySingleton<EntitlementService>(
    UnlimitedEntitlementService.new,
  );
  locator.registerLazySingleton<ShareService>(SharePlusShareService.new);
  locator.registerLazySingleton<ExportRepository>(
    () => ExportRepositoryImpl(
      audio: locator<AudioNative>(),
      paths: () => locator<Future<ProjectPaths>>(),
      entitlements: locator<EntitlementService>(),
    ),
  );
}
