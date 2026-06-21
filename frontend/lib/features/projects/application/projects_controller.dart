import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/projects_repository.dart';
import '../domain/project.dart';

final projectsRepositoryProvider =
    Provider<ProjectsRepository>((ref) => ProjectsRepository(ref.watch(dioProvider)));

/// Filter for the projects list.
class ProjectsFilter {
  const ProjectsFilter({this.stage, this.query});
  final String? stage;
  final String? query;

  ProjectsFilter copyWith({String? stage, String? query, bool clearStage = false}) =>
      ProjectsFilter(
        stage: clearStage ? null : (stage ?? this.stage),
        query: query ?? this.query,
      );
}

final projectsFilterProvider =
    StateProvider<ProjectsFilter>((ref) => const ProjectsFilter());

/// Project list, reactive to the active filter.
final projectsListProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  final filter = ref.watch(projectsFilterProvider);
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.list(stage: filter.stage, q: filter.query);
});

/// Single project detail.
final projectDetailProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, id) async {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.getById(id);
});

/// Assignments for a project.
final projectAssignmentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.assignments(id);
});
