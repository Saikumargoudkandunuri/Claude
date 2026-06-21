import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class ReportsRepository {
  ReportsRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> listForProject(String projectId,
      {String? date}) async {
    final res = await _dio.get(
      '/projects/$projectId/reports',
      queryParameters: {if (date != null) 'date': date},
    );
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> submit(
      String projectId, Map<String, dynamic> body) async {
    final res = await _dio.post('/projects/$projectId/reports', data: body);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> todayForMe() async {
    final res = await _dio.get('/reports/today/me');
    return res.data['data'] as Map<String, dynamic>;
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
    (ref) => ReportsRepository(ref.watch(dioProvider)));

final projectReportsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  return ref.watch(reportsRepositoryProvider).listForProject(projectId);
});
