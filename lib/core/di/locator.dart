import 'package:get_it/get_it.dart';

import '../../features/beat_editor/data/repositories/beat_project_repository.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<BeatProjectRepository>(
    DemoBeatProjectRepository.new,
  );
}
