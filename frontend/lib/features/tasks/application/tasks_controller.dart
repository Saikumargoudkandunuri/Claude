import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Work plans = worker tasks (today/tomorrow) with status.
class TasksRepository {
  TasksRepository(this._dio);
  final Dio _dio;

  /// Admin/supervisor task panel for a date.
  Future<Map<String, dynamic>> listAll({String? date}) async {
    final res = await _dio.get('/workplans',
        queryParameters: {if (date != null) 'date': date});
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Tasks assigned to me for a date.
  Future<Map<String, dynamic>> forMe({String? date}) async {
    final res = await _dio.get('/workplans/me',
        queryParameters: {if (date != null) 'date': date});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> assign({
    required String projectId,
    required String planDate,
    required List<String> workerIds,
    String? task,
  }) async {
    await _dio.post('/projects/$projectId/workplans', data: {
      'planDate': planDate,
      'workerIds': workerIds,
      if (task != null) 'task': task,
    });
  }

  Future<void> updateStatus(String planId, String status) async {
    await _dio.put('/workplans/$planId/status', data: {'status': status});
  }

  Future<void> delete(String planId) => _dio.delete('/workplans/$planId');
}

final tasksRepositoryProvider =
    Provider<TasksRepository>((ref) => TasksRepository(ref.watch(dioProvider)));

/// Date filter for the admin/supervisor task panel.
final taskPanelDateProvider = StateProvider<String>((ref) {
  return DateTime.now().toIso8601String().substring(0, 10);
});

final taskPanelProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final date = ref.watch(taskPanelDateProvider);
  return ref.watch(tasksRepositoryProvider).listAll(date: date);
});
