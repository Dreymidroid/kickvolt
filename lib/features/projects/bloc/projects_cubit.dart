import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/di/locator.dart';
import '../data/repositories/project_repository.dart';
import '../domain/entities/project_exception.dart';
import '../domain/entities/project_summary.dart';

part 'projects_cubit.freezed.dart';
part 'projects_state.dart';

class ProjectsCubit extends Cubit<ProjectsState> {
  ProjectsCubit({ProjectRepository? repository})
    : _repository = repository ?? locator<ProjectRepository>(),
      super(const ProjectsState.loading());

  final ProjectRepository _repository;

  Future<void> load() async {
    emit(const ProjectsState.loading());
    try {
      final projects = await _repository.listProjects();
      if (!isClosed) emit(ProjectsState.loaded(projects));
    } on ProjectException catch (e) {
      if (!isClosed) emit(ProjectsState.error(error: e.message));
    } catch (e) {
      if (!isClosed) emit(ProjectsState.error(error: e.toString()));
    }
  }

  Future<void> rename(String id, String title) async {
    try {
      await _repository.renameProject(id, title);
      final projects = await _repository.listProjects();
      if (!isClosed) emit(ProjectsState.loaded(projects));
    } on ProjectException catch (e) {
      if (!isClosed) emit(ProjectsState.error(error: e.message));
    } catch (e) {
      if (!isClosed) emit(ProjectsState.error(error: e.toString()));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repository.deleteProject(id);
      final projects = await _repository.listProjects();
      if (!isClosed) emit(ProjectsState.loaded(projects));
    } on ProjectException catch (e) {
      if (!isClosed) emit(ProjectsState.error(error: e.message));
    } catch (e) {
      if (!isClosed) emit(ProjectsState.error(error: e.toString()));
    }
  }
}
