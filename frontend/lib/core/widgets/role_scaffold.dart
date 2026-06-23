import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// A navigation destination for the role bottom bar.
class RoleDestination {
  const RoleDestination({
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

/// Material 3 bottom-navigation scaffold shared by every role shell.
/// Back behavior:
///  • On a non-home tab → switch to the home (Dashboard) tab.
///  • On the home tab → first back shows "Press back again to exit",
///    second back within 2 seconds exits the app.
class RoleScaffold extends StatefulWidget {
  const RoleScaffold({
    super.key,
    required this.destinations,
    required this.child,
    required this.location,
  });

  final List<RoleDestination> destinations;
  final Widget child;
  final String location;

  @override
  State<RoleScaffold> createState() => _RoleScaffoldState();
}

class _RoleScaffoldState extends State<RoleScaffold> {
  DateTime? _lastBack;

  String get _homeRoute => widget.destinations.first.route;
  bool get _isHome => widget.location == _homeRoute;

  int get _currentIndex {
    var bestIndex = 0;
    var bestLen = -1;
    for (var i = 0; i < widget.destinations.length; i++) {
      final route = widget.destinations[i].route;
      if (widget.location == route ||
          widget.location.startsWith('$route/') ||
          widget.location.startsWith(route)) {
        if (route.length > bestLen) {
          bestLen = route.length;
          bestIndex = i;
        }
      }
    }
    return bestIndex;
  }

  void _handleBack() {
    final router = GoRouter.of(context);

    // If something is stacked above the shell, pop it first.
    if (router.canPop()) {
      router.pop();
      return;
    }

    // Not on the home tab → go home instead of exiting.
    if (!_isHome) {
      context.go(_homeRoute);
      return;
    }

    // On the home tab → double-back to exit.
    final now = DateTime.now();
    if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => context.go(widget.destinations[i].route),
          destinations: [
            for (final d in widget.destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}
