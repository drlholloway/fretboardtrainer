import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _destinations = [
  (
    path: '/learn',
    icon: Icons.school_outlined,
    selected: Icons.school,
    label: 'Learn',
  ),
  (
    path: '/drill',
    icon: Icons.bolt_outlined,
    selected: Icons.bolt,
    label: 'Drill',
  ),
  (
    path: '/settings',
    icon: Icons.settings_outlined,
    selected: Icons.settings,
    label: 'Settings',
  ),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    var index = _destinations.indexWhere((d) => loc.startsWith(d.path));
    if (index < 0) index = 0;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    void go(int i) => context.go(_destinations[i].path);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
