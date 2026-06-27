import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_app.dart';

/// Entry point for the Customer Portal standalone application.
///
/// Build with:
///   flutter build web -t lib/customer_main.dart --release \
///     --dart-define=API_BASE_URL=https://icms-backend-s2va.onrender.com/api/v1
///
/// This produces a web build containing ONLY the customer portal — no ERP,
/// no admin/supervisor/worker routes, no Firebase push notifications.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: CustomerPortalApp()));
}
