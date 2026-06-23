import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';

/// Wraps a full-screen (pushed) page so the Android system back button and
/// the AppBar back button behave correctly:
///  • if a previous route exists → pop to it
///  • otherwise → navigate to the role Dashboard (never close the app)
class BackGuard extends ConsumerWidget {
  const BackGuard({super.key, required this.child});

  final Widget child;

  static String dashboardRouteForRole(String? role) {
    switch (role) {
      case 'admin':
        return '/admin';
      case 'supervisor':
        return '/supervisor';
      case 'designer':
        return '/designer';
      case 'worker':
        return '/worker';
      default:
        return '/login';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          final role = ref.read(authControllerProvider).user?.role;
          context.go(dashboardRouteForRole(role));
        }
      },
      child: child,
    );
  }
}
