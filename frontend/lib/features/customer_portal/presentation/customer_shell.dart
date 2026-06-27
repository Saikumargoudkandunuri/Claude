import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/customer_dio_client.dart';
import '../../customer_auth/application/customer_auth_controller.dart';
import '../application/customer_providers.dart';

/// Bottom-navigation shell for the customer portal.
///
/// Wraps a [child] widget provided by GoRouter's ShellRoute and displays
/// a 5-tab bottom navigation bar (Home, Photos, Timeline, Payments, Messages)
/// with the #00D1DC teal brand color for the active tab.
/// Includes a logout button in the app bar.
class CustomerShell extends ConsumerWidget {
  const CustomerShell({super.key, required this.child});

  final Widget child;

  static const _brandTeal = Color(0xFF00D1DC);

  static const _tabs = [
    _CustomerTab(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: '/customer',
    ),
    _CustomerTab(
      label: 'Photos',
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      route: '/customer/photos',
    ),
    _CustomerTab(
      label: 'Timeline',
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline,
      route: '/customer/timeline',
    ),
    _CustomerTab(
      label: 'Payments',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      route: '/customer/payments',
    ),
    _CustomerTab(
      label: 'Messages',
      icon: Icons.message_outlined,
      selectedIcon: Icons.message,
      route: '/customer/messages',
    ),
  ];

  int _currentIndex(String location) {
    var bestIndex = 0;
    var bestLen = -1;
    for (var i = 0; i < _tabs.length; i++) {
      final route = _tabs[i].route;
      if (location == route || location.startsWith('$route/')) {
        if (route.length > bestLen) {
          bestLen = route.length;
          bestIndex = i;
        }
      }
    }
    return bestIndex;
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Log out of customer portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Clear token
    await CustomerDioClient.clearToken();

    // Clear auth state
    ref.read(customerAuthControllerProvider.notifier).logout();

    // Invalidate all customer data providers
    ref.invalidate(customerOverviewProvider);
    ref.invalidate(customerTimelineProvider);
    ref.invalidate(customerPhotosProvider);
    ref.invalidate(customerDrawingsProvider);
    ref.invalidate(customerPaymentSummaryProvider);
    ref.invalidate(customerNotificationsProvider);
    ref.invalidate(customerMessagesProvider);

    // Navigate to login
    if (context.mounted) {
      context.go('/customer-login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _currentIndex(location);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Metal & More',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        indicatorColor: _brandTeal.withValues(alpha: 0.15),
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon, color: _brandTeal),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _CustomerTab {
  const _CustomerTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
