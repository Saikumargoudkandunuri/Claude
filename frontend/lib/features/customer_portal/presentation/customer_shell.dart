import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-navigation shell for the customer portal.
///
/// Wraps a [child] widget provided by GoRouter's ShellRoute and displays
/// a 5-tab bottom navigation bar (Home, Photos, Timeline, Payments, Messages)
/// with the #00D1DC teal brand color for the active tab.
class CustomerShell extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _currentIndex(location);

    return Scaffold(
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
