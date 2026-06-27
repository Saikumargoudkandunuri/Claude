import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/customer_auth/application/customer_auth_controller.dart';
import '../../features/customer_auth/presentation/customer_login_screen.dart';
import '../../features/customer_auth/presentation/customer_set_pin_screen.dart';
import '../../features/customer_portal/presentation/customer_home_screen.dart';
import '../../features/customer_portal/presentation/customer_messages_screen.dart';
import '../../features/customer_portal/presentation/customer_payments_screen.dart';
import '../../features/customer_portal/presentation/customer_photos_screen.dart';
import '../../features/customer_portal/presentation/customer_shell.dart';
import '../../features/customer_portal/presentation/customer_timeline_screen.dart';

/// Dedicated GoRouter for the Customer Portal application.
/// Contains ONLY customer routes — no ERP/admin/supervisor/worker routes.
final customerRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(customerAuthControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/customer-login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(customerAuthControllerProvider);
      final loc = state.matchedLocation;

      final isAuthPage = loc == '/customer-login' || loc == '/customer-set-pin';

      // Still loading — stay put
      if (auth.isLoading) return null;

      // Not authenticated → force to login (unless already there)
      if (!auth.isAuthenticated) {
        return isAuthPage ? null : '/customer-login';
      }

      // Authenticated → redirect away from auth pages to home
      if (isAuthPage) return '/customer';

      return null;
    },
    routes: [
      // Auth routes (no bottom nav)
      GoRoute(
        path: '/customer-login',
        builder: (_, __) => const CustomerLoginScreen(),
      ),
      GoRoute(
        path: '/customer-set-pin',
        builder: (_, state) => const CustomerSetPinScreen(),
      ),

      // Customer portal shell with bottom navigation
      ShellRoute(
        builder: (_, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: '/customer',
            builder: (_, __) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: '/customer/photos',
            builder: (_, __) => const CustomerPhotosScreen(),
          ),
          GoRoute(
            path: '/customer/timeline',
            builder: (_, __) => const CustomerTimelineScreen(),
          ),
          GoRoute(
            path: '/customer/payments',
            builder: (_, __) => const CustomerPaymentsScreen(),
          ),
          GoRoute(
            path: '/customer/messages',
            builder: (_, __) => const CustomerMessagesScreen(),
          ),
        ],
      ),
    ],
  );
});
