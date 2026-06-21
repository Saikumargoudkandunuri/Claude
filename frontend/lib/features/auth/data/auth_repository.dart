import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_store.dart';
import '../domain/auth_user.dart';
import 'auth_api.dart';

/// Coordinates auth API calls with secure token storage.
class AuthRepository {
  AuthRepository(this._api);
  final AuthApi _api;

  Future<AuthUser> login(String email, String password) async {
    final data = await _api.login(email: email, password: password);
    await SecureStore.instance.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<String> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _api.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );
    return (data['message'] ?? 'Registration received.') as String;
  }

  Future<AuthUser?> currentUser() async {
    final token = await SecureStore.instance.accessToken;
    if (token == null) return null;
    try {
      final data = await _api.me();
      return AuthUser.fromJson(data);
    } catch (e) {
      // Token invalid/expired and refresh failed.
      if (DioClient.toApiException(e).isUnauthorized) {
        await SecureStore.instance.clear();
      }
      return null;
    }
  }

  Future<void> logout() async {
    final refresh = await SecureStore.instance.refreshToken;
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        /* ignore network errors on logout */
      }
    }
    await SecureStore.instance.clear();
  }

  Future<AuthUser> updateWorkerStatus(String status) async {
    final data = await _api.updateWorkerStatus(status);
    return AuthUser.fromJson(data);
  }
}
