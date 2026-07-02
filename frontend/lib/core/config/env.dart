/// Environment configuration. Override at build time with:
/// `flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1`
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://icms-backend-s2va.onrender.com/api/v1',
  );

  /// Connection timeouts in milliseconds.
  static const int connectTimeoutMs = 30000; // 30s — covers Render cold-start
  static const int receiveTimeoutMs =
      120000; // 2 min — covers large file downloads
}
