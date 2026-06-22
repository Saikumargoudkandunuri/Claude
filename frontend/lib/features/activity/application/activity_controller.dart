import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class ActivityRepository {
  ActivityRepository(this._dio);
  final Dio _dio;

  /// Full project history (creation -> completion), ascending by time.
  Future<List<Map<String, dynamic>>> timeline(String projectId) async {
    final res = await _dio.get('/projects/$projectId/timeline');
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
}

final activityRepositoryProvider =
    Provider<ActivityRepository>((ref) => ActivityRepository(ref.watch(dioProvider)));

final projectTimelineProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  return ref.watch(activityRepositoryProvider).timeline(projectId);
});
