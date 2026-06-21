import 'package:dio/dio.dart';

/// Thin HTTP layer for auth endpoints.
class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      },
      options: Options(extra: {'skipAuth': true}),
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: {'skipAuth': true}),
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );
  }

  Future<Map<String, dynamic>> updateWorkerStatus(String status) async {
    final res = await _dio.put('/auth/me/worker-status', data: {'status': status});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> updatePushToken(String token) async {
    await _dio.put('/auth/me/push-token', data: {'pushToken': token});
  }
}
