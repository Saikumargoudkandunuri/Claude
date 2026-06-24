import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Manages FCM push token registration with the backend.
/// Call [registerToken] after successful login to ensure the backend
/// has the device's FCM token for push delivery.
class PushNotificationService {
  PushNotificationService(this._ref);
  final Ref _ref;

  /// Get the current FCM token and send it to the backend.
  /// Also listens for token refresh events.
  Future<void> registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Get current token
      final token = await messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }

      // Listen for token refreshes (happens when app is reinstalled, etc.)
      messaging.onTokenRefresh.listen(_sendTokenToBackend);
    } catch (e) {
      // Firebase not configured — silently ignore
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.put('/auth/me/push-token', data: {'pushToken': token});
    } catch (_) {
      // Non-critical: token will be sent on next app launch
    }
  }
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) => PushNotificationService(ref));
