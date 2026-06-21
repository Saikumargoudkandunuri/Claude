import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

/// Configured Dio instance with auth + automatic token refresh.
class DioClient {
  DioClient._() {
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

  static final DioClient instance = DioClient._();
  late final Dio _dio;
  Dio get dio => _dio;

  /// Callback invoked when refresh fails (forces logout in the app layer).
  void Function()? onSessionExpired;

  bool _refreshing = false;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['skipAuth'] != true) {
          final token = await SecureStore.instance.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final isAuthCall = error.requestOptions.path.contains('/auth/');

        // Try a one-shot refresh on 401 (but never for auth endpoints).
        if (status == 401 && !isAuthCall && !_refreshing) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            try {
              final clone = await _retry(error.requestOptions);
              return handler.resolve(clone);
            } catch (_) {
              // fall through to error mapping
            }
          } else {
            onSessionExpired?.call();
          }
        }
        handler.reject(error);
      },
    );
  }

  Future<bool> _tryRefresh() async {
    _refreshing = true;
    try {
      final refreshToken = await SecureStore.instance.refreshToken;
      if (refreshToken == null) return false;
      final res = await Dio(BaseOptions(baseUrl: Env.apiBaseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      await SecureStore.instance.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await SecureStore.instance.clear();
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await SecureStore.instance.accessToken;
    final options = Options(
      method: requestOptions.method,
      headers: {...requestOptions.headers, 'Authorization': 'Bearer $token'},
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  /// Convert a DioException into a friendly [ApiException].
  static ApiException toApiException(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final res = error.response;
      final data = res?.data;
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        return ApiException(
          (err['message'] ?? 'Request failed').toString(),
          code: err['code']?.toString(),
          statusCode: res?.statusCode,
          details: err['details'],
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return ApiException('Cannot reach server. Check your connection.');
      }
      return ApiException(
        error.message ?? 'Network error',
        statusCode: res?.statusCode,
      );
    }
    return ApiException(error.toString());
  }
}
