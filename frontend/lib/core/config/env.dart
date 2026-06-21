/// Environment configuration. Override at build time with:
/// `flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1`
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000/api/v1', // Android emulator -> host
  );

  /// Connection timeouts in milliseconds.
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;
}
