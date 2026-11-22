import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/projects/projects.dart';
import 'package:mocktail/mocktail.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late MockProjectRepository repo;

  final summary1 = ProjectSummary(
    id: 'p1',
    title: 'Midnight Run',
    beatCount: 358,
    bpm: 128.0,
    sampleRate: 44100,
    sampleCount: 44100 * 168,
    updatedAt: DateTime.utc(2026, 11, 22, 12, 0),
    thumbnail: List<int>.filled(64, 120),
  );
  final summary2 = ProjectSummary(
    id: 'p2',
    title: 'Afro Glow',
    beatCount: 0,
    bpm: null,
    sampleRate: 44100,
    sampleCount: 44100 * 142,
    updatedAt: DateTime.utc(2026, 11, 21, 12, 0),
    thumbnail: List<int>.filled(64, 80),
  );

  setUp(() => repo = MockProjectRepository());

  blocTest<ProjectsCubit, ProjectsState>(
    'load emits loading then loaded with projects',
    build: () {
      when(() => repo.listProjects())
          .thenAnswer((_) async => [summary1, summary2]);
      return ProjectsCubit(repository: repo);
    },
    act: (c) => c.load(),
    expect: () => [
      const ProjectsState.loading(),
      ProjectsState.loaded([summary1, summary2]),
    ],
  );

  blocTest<ProjectsCubit, ProjectsState>(
    'load emits loading then empty loaded list when no projects exist',
    build: () {
      when(() => repo.listProjects()).thenAnswer((_) async => const []);
      return ProjectsCubit(repository: repo);
    },
    act: (c) => c.load(),
    expect: () => const [ProjectsState.loading(), ProjectsState.loaded([])],
  );

  blocTest<ProjectsCubit, ProjectsState>(
    'load emits loading then error on repository failure',
    build: () {
      when(() => repo.listProjects())
          .thenThrow(const ProjectCorruptException('bad index'));
      return ProjectsCubit(repository: repo);
    },
    act: (c) => c.load(),
    expect: () => const [
      ProjectsState.loading(),
      ProjectsState.error(error: 'bad index'),
    ],
  );

  blocTest<ProjectsCubit, ProjectsState>(
    'rename updates repository and emits refreshed project list',
    build: () {
      final renamed = summary1.copyWith(title: 'Renamed Song');
      when(() => repo.renameProject('p1', 'Renamed Song'))
          .thenAnswer((_) async {});
      when(() => repo.listProjects()).thenAnswer((_) async => [renamed]);
      return ProjectsCubit(repository: repo);
    },
    act: (c) => c.rename('p1', 'Renamed Song'),
    expect: () => [
      ProjectsState.loaded([summary1.copyWith(title: 'Renamed Song')]),
    ],
    verify: (_) {
      verify(() => repo.renameProject('p1', 'Renamed Song')).called(1);
    },
  );

  blocTest<ProjectsCubit, ProjectsState>(
    'delete removes project from repository and emits refreshed list',
    build: () {
      when(() => repo.deleteProject('p1')).thenAnswer((_) async {});
      when(() => repo.listProjects()).thenAnswer((_) async => [summary2]);
      return ProjectsCubit(repository: repo);
    },
    act: (c) => c.delete('p1'),
    expect: () => [
      ProjectsState.loaded([summary2]),
    ],
    verify: (_) {
      verify(() => repo.deleteProject('p1')).called(1);
    },
  );
}
