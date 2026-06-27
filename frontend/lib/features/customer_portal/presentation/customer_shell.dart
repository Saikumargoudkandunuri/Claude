import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/portal_theme.dart';

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
      label: 'Journal',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
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
      backgroundColor: PortalColors.neutral,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: PortalColors.border, width: 0.8),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      tab: _tabs[i],
                      selected: i == selectedIndex,
                      onTap: () => context.go(_tabs[i].route),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single bottom-nav item with a teal dot indicator and a tap scale bounce.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _CustomerTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.selected ? PortalColors.primary : PortalColors.textSoft;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.85),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    widget.selected ? PortalColors.primary : Colors.transparent,
              ),
            ),
            Icon(
              widget.selected ? widget.tab.selectedIcon : widget.tab.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              widget.tab.label,
              style: PortalText.label(size: 10, color: color).copyWith(
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
              ),
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
