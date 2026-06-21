import 'package:dio/dio.dart';

import '../domain/project.dart';

/// Data access for projects, stages and assignments.
class ProjectsRepository {
  ProjectsRepository(this._dio);
  final Dio _dio;

  Future<List<Project>> list(
      {String? stage, String? q, bool assignedToMe = false}) async {
    final res = await _dio.get(
      '/projects',
      queryParameters: {
        if (stage != null) 'stage': stage,
        if (q != null && q.isNotEmpty) 'q': q,
        if (assignedToMe) 'assigned': 'me',
        'limit': 100,
      },
    );
    final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(Project.fromJson).toList();
  }

  Future<Project> getById(String id) async {
    final res = await _dio.get('/projects/$id');
    return Project.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Project> create(Map<String, dynamic> body) async {
    final res = await _dio.post('/projects', data: body);
    return Project.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Project> update(String id, Map<String, dynamic> body) async {
    final res = await _dio.put('/projects/$id', data: body);
    return Project.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _dio.delete('/projects/$id');

  Future<Project> setStage(String id, String stage,
      {String status = 'in_progress', String? note}) async {
    final res = await _dio.put(
      '/projects/$id/stage',
      data: {
        'stage': stage,
        'status': status,
        if (note != null) 'note': note,
      },
    );
    return Project.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> assignments(String id) async {
    final res = await _dio.get('/projects/$id/assignments');
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> assignWorker(String id, String userId, {String? task}) async {
    await _dio.post(
      '/projects/$id/assignments',
      data: {
        'userId': userId,
        'role': 'worker',
        if (task != null) 'task': task,
      },
    );
  }

  Future<List<Map<String, dynamic>>> assignable(String role) async {
    final res =
        await _dio.get('/users/assignable', queryParameters: {'role': role});
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
}
