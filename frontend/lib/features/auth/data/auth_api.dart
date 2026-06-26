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
    final res =
        await _dio.put('/auth/me/worker-status', data: {'status': status});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> updatePushToken(String token) async {
    await _dio.put('/auth/me/push-token', data: {'pushToken': token});
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    final res = await _dio.put(
      '/auth/me',
      data: {
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
      },
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _dio.put(
      '/auth/me/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(
      '/auth/forgot-password',
      data: {'email': email},
      options: Options(extra: {'skipAuth': true}),
    );
  }

  Future<void> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    await _dio.post(
      '/auth/reset-password',
      data: {'email': email, 'otp': otp, 'newPassword': newPassword},
      options: Options(extra: {'skipAuth': true}),
    );
  }

  /// Forgot-password step 1: fetch the security question for an email.
  /// Returns `{ hasQuestion: bool, question: String? }`.
  Future<Map<String, dynamic>> forgotPasswordQuestion(String email) async {
    final res = await _dio.post(
      '/auth/forgot-password-question',
      data: {'email': email},
      options: Options(extra: {'skipAuth': true}),
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Forgot-password step 2: verify the answer, returns a one-time reset token.
  Future<String> verifySecurityAnswer(String email, String answer) async {
    final res = await _dio.post(
      '/auth/verify-security-answer',
      data: {'email': email, 'answer': answer},
      options: Options(extra: {'skipAuth': true}),
    );
    return res.data['data']['resetToken'] as String;
  }

  /// Forgot-password step 3: set a new password using the reset token.
  Future<void> resetPasswordWithToken(
    String resetToken,
    String newPassword,
  ) async {
    await _dio.post(
      '/auth/reset-password-token',
      data: {'resetToken': resetToken, 'newPassword': newPassword},
      options: Options(extra: {'skipAuth': true}),
    );
  }

  /// Whether the current user has a security question set, plus the
  /// available preset questions. Returns `{ hasQuestion, question, options }`.
  Future<Map<String, dynamic>> securityQuestionStatus() async {
    final res = await _dio.get('/auth/me/security-question');
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Set or replace the current user's security question + answer.
  Future<void> setSecurityQuestion(String question, String answer) async {
    await _dio.put(
      '/auth/me/security-question',
      data: {'question': question, 'answer': answer},
    );
  }
}
