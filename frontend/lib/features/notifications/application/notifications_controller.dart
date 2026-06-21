import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> list() async {
    final res = await _dio.get('/notifications', queryParameters: {'limit': 50});
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<int> unreadCount() async {
    final res = await _dio.get('/notifications/unread-count');
    return (res.data['data']['count'] as num).toInt();
  }

  Future<void> markRead(String id) => _dio.post('/notifications/$id/read');
  Future<void> markAllRead() => _dio.post('/notifications/read-all');
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(dioProvider)));

final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(notificationsRepositoryProvider).list();
});
