import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_session.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.path, [this.capabilities]);
  final String label;
  final IconData icon;
  final String path;
  final List<String>? capabilities;

  bool isVisible(AdminSession session) {
    if (capabilities == null || capabilities!.isEmpty) return true;
    return session.canAny(capabilities!);
  }
}

const _items = [
  _NavItem('Dashboard', Icons.dashboard_outlined, '/'),
  _NavItem('Users', Icons.people_outline, '/users', [Cap.usersRead, Cap.usersManage]),
  _NavItem('Partners', Icons.storefront_outlined, '/partners', [Cap.studioActivation]),
  _NavItem('Plans', Icons.card_membership_outlined, '/plans', [
    Cap.plansManage,
    Cap.studioActivation,
    Cap.usersManage,
  ]),
  _NavItem('Campaigns', Icons.campaign_outlined, '/campaigns', [Cap.campaignsManage]),
  _NavItem('Support', Icons.support_agent_outlined, '/support', [Cap.support]),
  _NavItem('Feature Flags', Icons.toggle_on_outlined, '/features', [
    Cap.featuresManage,
    Cap.aiConfiguration,
  ]),
  _NavItem('Admins & Audit', Icons.security_outlined, '/admins', [Cap.adminsManage]),
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
    final visible = _items.where((i) => i.isVisible(session)).toList();
    var selected = visible.lastIndexWhere(
      (i) => i.path == '/' ? location == '/' : location.startsWith(i.path),
    );
    if (selected < 0) selected = 0;

    final isWide = MediaQuery.sizeOf(context).width > 1100;

    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      extended: isWide,
                      minExtendedWidth: 200,
                      selectedIndex: selected,
                      onDestinationSelected: (i) => context.go(visible[i].path),
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.fitness_center,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            if (isWide) ...[
                              const SizedBox(width: 12),
                              const Text(
                                'FitGen Admin',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                          NavigationRailDestination(
                            icon: Icon(i.icon),
                            selectedIcon: Icon(i.icon, color: Theme.of(context).colorScheme.primary),
                            label: Text(i.label),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
