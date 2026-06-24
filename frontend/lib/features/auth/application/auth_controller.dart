import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/push_notification_service.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));
final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => AuthRepository(ref.watch(authApiProvider)));

/// Auth state consumed by the router and screens.
class AuthState {
  const AuthState({this.user, this.isLoading = true, this.error});

  final AuthUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith(
      {AuthUser? user,
      bool? isLoading,
      String? error,
      bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Hook session expiry (refresh failure) to force logout.
    DioClient.instance.onSessionExpired = () {
      state = const AuthState(user: null, isLoading: false);
    };
    _bootstrap();
    return const AuthState(isLoading: true);
  }

  Future<void> _bootstrap() async {
    final user = await _repo.currentUser();
    state = AuthState(user: user, isLoading: false);
    if (user != null) {
      // Register FCM push token after successful session restore
      ref.read(pushNotificationServiceProvider).registerToken();
    }
  }

  Future<void> refreshUser() async {
    final user = await _repo.currentUser();
    state =
        state.copyWith(user: user, isLoading: false, clearUser: user == null);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(email, password);
      state = AuthState(user: user, isLoading: false);
      // Register FCM push token after successful login
      ref.read(pushNotificationServiceProvider).registerToken();
      return true;
    } catch (e) {
      state = AuthState(
        user: null,
        isLoading: false,
        error: DioClient.toApiException(e).message,
      );
      return false;
    }
  }

  Future<String?> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      return await _repo.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );
    } catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  Future<void> updateWorkerStatus(String status) async {
    try {
      final user = await _repo.updateWorkerStatus(status);
      state = state.copyWith(user: user);
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(user: null, isLoading: false);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
