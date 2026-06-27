import 'package:dio/dio.dart';

/// Thin HTTP layer for customer authentication endpoints.
class CustomerAuthApi {
  CustomerAuthApi(this._dio);
  final Dio _dio;

  /// Check if a mobile number is linked to a project.
  /// Returns `{ found: bool, customerName: String?, pinSet: bool? }`.
  Future<Map<String, dynamic>> checkMobile(String mobile) async {
    final res = await _dio.post(
      '/customer/auth/check-mobile',
      data: {'mobile': mobile},
      options: Options(extra: {'skipAuth': true}),
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Set a 4-digit PIN for a first-time customer.
  /// Returns `{ success: true }`.
  Future<Map<String, dynamic>> setPin(String mobile, String pin) async {
    final res = await _dio.post(
      '/customer/auth/set-pin',
      data: {'mobile': mobile, 'pin': pin},
      options: Options(extra: {'skipAuth': true}),
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Login with mobile + PIN.
  /// Returns `{ token: String, customerName: String, customerId: String, projectId: String }`.
  Future<Map<String, dynamic>> login(String mobile, String pin) async {
    final res = await _dio.post(
      '/customer/auth/login',
      data: {'mobile': mobile, 'pin': pin},
      options: Options(extra: {'skipAuth': true}),
    );
    return res.data['data'] as Map<String, dynamic>;
  }
}
