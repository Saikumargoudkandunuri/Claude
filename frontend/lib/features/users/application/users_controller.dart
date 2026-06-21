import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class UsersRepository {
  UsersRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> pending() async {
    final res = await _dio.get('/users/pending');
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> approve(String id, String role) =>
      _dio.post('/users/$id/approve', data: {'role': role});

  Future<void> reject(String id) => _dio.post('/users/$id/reject');
}

final usersRepositoryProvider =
    Provider<UsersRepository>((ref) => UsersRepository(ref.watch(dioProvider)));

final pendingUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(usersRepositoryProvider).pending();
});
