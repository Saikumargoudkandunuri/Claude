import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/drawings_repository.dart';
import '../domain/drawing_file.dart';

final drawingsRepositoryProvider =
    Provider<DrawingsRepository>((ref) => DrawingsRepository(ref.watch(dioProvider)));

/// All files for a project (drawings + media), grouped by the UI.
final projectFilesProvider =
    FutureProvider.autoDispose.family<List<DrawingFile>, String>((ref, projectId) async {
  final repo = ref.watch(drawingsRepositoryProvider);
  return repo.listForProject(projectId);
});
