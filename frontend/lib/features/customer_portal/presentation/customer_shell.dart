import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/customer_theme.dart';

/// Bottom-navigation shell for the customer portal.
///
/// Wraps a [child] widget provided by GoRouter's ShellRoute and displays
/// a 5-tab bottom navigation bar (Home, Photos, Journey, Payments, Updates).
/// No AppBar — screens handle their own headers.
/// Logout functionality is in the home screen hero card.
class CustomerShell extends ConsumerWidget {
  const CustomerShell({super.key, required this.child});

  final Widget child;

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
      label: 'Journey',
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline,
      route: '/customer/timeline',
    ),
    _CustomerTab(
      label: 'Payments',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      route: '/customer/payments',
    ),
    _CustomerTab(
      label: 'Updates',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _currentIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: CTheme.inactive, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (i) => context.go(_tabs[i].route),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: CTheme.primary,
          unselectedItemColor: CTheme.textLight,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          backgroundColor: CTheme.bgWhite,
          elevation: 0,
          items: [
            for (final tab in _tabs)
              BottomNavigationBarItem(
                icon: Icon(tab.icon),
                activeIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
          ],
        ),
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
