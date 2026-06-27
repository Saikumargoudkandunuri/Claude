import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/customer_router.dart';
import 'core/theme/app_theme.dart';

/// Standalone Customer Portal application widget.
/// Uses the dedicated [customerRouterProvider] that only includes customer routes.
class CustomerPortalApp extends ConsumerWidget {
  const CustomerPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(customerRouterProvider);
    return MaterialApp.router(
      title: 'Metal & More Interiors',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
