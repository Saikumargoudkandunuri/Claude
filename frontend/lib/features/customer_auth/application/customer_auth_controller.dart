import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/customer_dio_client.dart';
import '../data/customer_auth_api.dart';

/// Provider for the [CustomerAuthApi] instance.
final customerAuthApiProvider = Provider<CustomerAuthApi>(
  (ref) => CustomerAuthApi(CustomerDioClient.instance.dio),
);

/// Customer authentication state.
class CustomerAuthState {
  const CustomerAuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.customerName,
    this.customerId,
    this.projectId,
    this.error,
  });

  final bool isLoading;
  final bool isAuthenticated;
  final String? customerName;
  final String? customerId;
  final String? projectId;
  final String? error;

  CustomerAuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? customerName,
    String? customerId,
    String? projectId,
    String? error,
    bool clearError = false,
    bool clearCustomerName = false,
    bool clearCustomerId = false,
    bool clearProjectId = false,
  }) {
    return CustomerAuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      customerName:
          clearCustomerName ? null : (customerName ?? this.customerName),
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages customer authentication state via mobile + PIN flow.
class CustomerAuthController extends Notifier<CustomerAuthState> {
  CustomerAuthApi get _api => ref.read(customerAuthApiProvider);

  @override
  CustomerAuthState build() {
    // Hook 401 session expiry to force customer logout.
    CustomerDioClient.instance.onSessionExpired = () {
      _performLogout();
    };
    _bootstrap();
    return const CustomerAuthState(isLoading: true);
  }

  /// Check if a stored token exists and mark as authenticated.
  Future<void> _bootstrap() async {
    final token = await CustomerDioClient.getToken();
    if (token != null) {
      state = const CustomerAuthState(
        isLoading: false,
        isAuthenticated: true,
      );
    } else {
      state = const CustomerAuthState(isLoading: false);
    }
  }

  /// Check if a mobile number is linked to a project.
  ///
  /// Returns the API response map containing:
  /// - `found` (bool)
  /// - `customerName` (String?) — present when found is true
  /// - `pinSet` (bool?) — present when found is true
  Future<Map<String, dynamic>> checkMobile(String mobile) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.checkMobile(mobile);
      state = state.copyWith(isLoading: false);
      return data;
    } catch (e) {
      final message = _extractError(e);
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    }
  }

  /// Set a PIN for a first-time customer, then auto-login.
  ///
  /// Calls the set-pin endpoint and then performs a login with the same
  /// credentials to obtain a token and navigate into the portal.
  Future<void> setPin(String mobile, String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.setPin(mobile, pin);
      // Auto-login after successful PIN creation.
      await login(mobile, pin);
    } catch (e) {
      final message = _extractError(e);
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    }
  }

  /// Login with mobile + PIN. Saves token and updates state.
  Future<void> login(String mobile, String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.login(mobile, pin);
      final token = data['token'] as String;
      final customerName = data['customerName'] as String?;
      final customerId = data['customerId'] as String?;
      final projectId = data['projectId'] as String?;

      // Persist token in secure storage.
      await CustomerDioClient.saveToken(token);

      state = CustomerAuthState(
        isLoading: false,
        isAuthenticated: true,
        customerName: customerName,
        customerId: customerId,
        projectId: projectId,
      );
    } catch (e) {
      final message = _extractError(e);
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    }
  }

  /// Logout: clear token and reset state.
  Future<void> logout() async {
    await _performLogout();
  }

  Future<void> _performLogout() async {
    await CustomerDioClient.clearToken();
    state = const CustomerAuthState(
      isLoading: false,
      isAuthenticated: false,
    );
  }

  /// Extract a user-friendly error message from an exception.
  String _extractError(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
}

/// Provider for [CustomerAuthController].
final customerAuthControllerProvider =
    NotifierProvider<CustomerAuthController, CustomerAuthState>(
  CustomerAuthController.new,
);
