import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_session.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.path, this.capability);
  final String label;
  final IconData icon;
  final String path;
  final String? capability; // null = visible to every admin
}

const _items = [
  _NavItem('Dashboard', Icons.dashboard_outlined, '/', null),
  _NavItem('Users', Icons.people_outline, '/users', Cap.usersRead),
];

/// Side navigation showing only modules the admin has a capability for.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.session,
    required this.location,
    required this.child,
  });
  final AdminSession session;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible =
        _items.where((i) => i.capability == null || session.can(i.capability!)).toList();
    var selected = visible.lastIndexWhere(
        (i) => i.path == '/' ? location == '/' : location.startsWith(i.path));
    if (selected < 0) selected = 0;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width > 900,
            selectedIndex: selected,
            onDestinationSelected: (i) => context.go(visible[i].path),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('FitGen Admin', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton(
                    tooltip: 'Sign out (${session.user?.email ?? ''})',
                    icon: const Icon(Icons.logout),
                    onPressed: session.signOut,
                  ),
                ),
              ),
            ),
            destinations: [
              for (final i in visible)
                NavigationRailDestination(icon: Icon(i.icon), label: Text(i.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
