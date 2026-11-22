part of 'projects_cubit.dart';

@freezed
sealed class ProjectsState with _$ProjectsState {
  const factory ProjectsState.loading() = ProjectsLoading;

  const factory ProjectsState.loaded(List<ProjectSummary> projects) =
      ProjectsLoaded;

  const factory ProjectsState.error({required String error}) = ProjectsError;
}
