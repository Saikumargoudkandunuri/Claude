import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class ReportsRepository {
  ReportsRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> listForProject(
    String projectId, {
    String? date,
  }) async {
    final res = await _dio.get(
      '/projects/$projectId/reports',
      queryParameters: {if (date != null) 'date': date},
    );
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> submit(
    String projectId,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.post(
      '/projects/$projectId/reports',
      data: body,
      options: Options(
        // First request after Render cold-start can take up to 60s.
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> todayForMe() async {
    final res = await _dio.get('/reports/today/me');
    return res.data['data'] as Map<String, dynamic>;
  }

  /// All reports across projects (admin: all, supervisor: own projects).
  Future<List<Map<String, dynamic>>> listAll(
      {String? date, String? type}) async {
    final res = await _dio.get(
      '/reports',
      queryParameters: {
        if (date != null) 'date': date,
        if (type != null) 'type': type,
        'limit': 100,
      },
    );
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Attach a media file (photo/video/voice_note/file) to a report.
  Future<void> addMedia({
    required String reportId,
    required String category,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'category': category,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post(
      '/reports/$reportId/media',
      data: form,
      options: Options(
        // File uploads need generous timeouts — especially on Render free tier
        // which can be slow to respond after a cold-start, and large images
        // can take time to upload over mobile connections.
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(dioProvider)),
);

final projectReportsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  return ref.watch(reportsRepositoryProvider).listForProject(projectId);
});

/// All reports across projects (admin: everything, supervisor: own projects).
final allReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(reportsRepositoryProvider).listAll();
});
