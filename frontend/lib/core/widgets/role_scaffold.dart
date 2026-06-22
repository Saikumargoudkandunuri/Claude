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
class RoleScaffold extends StatelessWidget {
  const RoleScaffold({
    super.key,
    required this.destinations,
    required this.child,
    required this.location,
  });

  final List<RoleDestination> destinations;
  final Widget child;
  final String location;

  int get _currentIndex {
    // Choose the destination whose route is the longest prefix of [location]
    // so '/admin/projects' selects Projects, not Home ('/admin').
    var bestIndex = 0;
    var bestLen = -1;
    for (var i = 0; i < destinations.length; i++) {
      final route = destinations[i].route;
      if (location == route || location.startsWith('$route/') || location.startsWith(route)) {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit(context);
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => context.go(destinations[i].route),
          destinations: [
            for (final d in destinations)
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

  Future<bool?> _confirmExit(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit')),
        ],
      ),
    );
  }
}
