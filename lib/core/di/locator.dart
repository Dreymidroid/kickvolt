import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/playback/data/audio_playback.dart';
import '../../features/playback/data/just_audio_playback.dart';

import '../../features/import/data/datasources/source_picker.dart';
import '../../features/import/data/repositories/import_repository.dart';
import '../../features/projects/data/repositories/project_repository.dart';
import '../audio_native/audio_native_client.dart';
import '../storage/project_paths.dart';

final locator = GetIt.instance;

void setupLocator() {
  // External / platform.
  locator.registerLazySingleton<AudioNative>(AudioNativeClient.new);
  locator.registerLazySingleton<Future<ProjectPaths>>(
    () async => ProjectPaths((await getApplicationDocumentsDirectory()).path),
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
    () => ProjectRepositoryImpl(paths: () => locator<Future<ProjectPaths>>()),
  );

  // A new player per editor; the editor disposes it.
  locator.registerFactory<AudioPlayback>(JustAudioPlayback.new);
}
