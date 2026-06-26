import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class WeeklyStatusApi {
  final Dio _dio = DioClient.instance.dio;

  Future<Map<String, dynamic>?> getCurrentStatus(String projectId) async {
    final res = await _dio.get('/projects/$projectId/weekly-status');
    return res.data['data'] as Map<String, dynamic>?;
  }

  Future<List<dynamic>> getStatusHistory(String projectId) async {
    final res = await _dio.get('/projects/$projectId/weekly-status/history');
    return res.data['data'] as List;
  }

  Future<Map<String, dynamic>> setStatus(String projectId, String status,
      {String? notes}) async {
    final res = await _dio.put(
      '/projects/$projectId/weekly-status',
      data: {
        'status': status,
        if (notes != null && notes.isNotEmpty) 'notes': notes
      },
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeeklyOverview() async {
    final res = await _dio.get('/dashboard/weekly-overview');
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<dynamic>> getNeedsReview() async {
    final res = await _dio.get('/dashboard/needs-review');
    return res.data['data'] as List;
  }
}
