import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/secure_store.dart';

/// Builds authenticated, environment-correct URLs for stored files.
///
/// The URL is ALWAYS derived from [Env.apiBaseUrl] (the API_BASE_URL build
/// define), so it never contains localhost / 127.0.0.1 / LAN IPs and works on
/// Render. Files are served behind JWT auth, so callers must send the auth
/// header — never open these URLs in an external browser.
class FileAccess {
  FileAccess._();

  /// Canonical streaming/preview URL for a stored file id.
  static String urlFor(String fileId) => '${Env.apiBaseUrl}/files/$fileId/download';

  /// Authorization headers for in-app viewers (PDF/image network loaders).
  static Future<Map<String, String>> authHeaders() async {
    final token = await SecureStore.instance.accessToken;
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Lightweight diagnostics (debug builds only).
  static void log(String message) {
    if (kDebugMode) debugPrint('[Attachment] $message');
  }
}
