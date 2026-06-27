import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';

/// Configured Dio instance for customer portal authentication.
///
/// Uses a separate storage key (`customer_access_token`) from the staff
/// `access_token` to maintain complete session isolation. No refresh token
/// logic — on 401 the token is cleared and [onSessionExpired] is invoked.
class CustomerDioClient {
  CustomerDioClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: Env.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: Env.receiveTimeoutMs),
        contentType: Headers.jsonContentType,
      ),
    );
    _dio.interceptors.add(_authInterceptor());
  }

  static final CustomerDioClient instance = CustomerDioClient._();

  late final Dio _dio;
  Dio get dio => _dio;

  /// Callback invoked when a 401 is received (forces customer logout).
  void Function()? onSessionExpired;

  // ---------------------------------------------------------------------------
  // Token storage
  // ---------------------------------------------------------------------------

  static const _kCustomerAccess = 'customer_access_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Persist the customer access token.
  static Future<void> saveToken(String token) =>
      _storage.write(key: _kCustomerAccess, value: token);

  /// Read the stored customer access token (or null if not set).
  static Future<String?> getToken() => _storage.read(key: _kCustomerAccess);

  /// Remove the customer access token from secure storage.
  static Future<void> clearToken() => _storage.delete(key: _kCustomerAccess);

  // ---------------------------------------------------------------------------
  // Interceptor
  // ---------------------------------------------------------------------------

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['skipAuth'] != true) {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await clearToken();
          onSessionExpired?.call();
        }
        handler.reject(error);
      },
    );
  }
}
