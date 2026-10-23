import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/admin_api.dart';
import 'core/admin_session.dart';
import 'features/admins/presentation/admins_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/campaigns/presentation/campaigns_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/feature_flags/presentation/feature_flags_screen.dart';
import 'features/partners/presentation/partner_detail_screen.dart';
import 'features/partners/presentation/partners_screen.dart';
import 'features/plans/presentation/plans_screen.dart';
import 'features/shell/admin_shell.dart';
import 'features/support/presentation/support_screen.dart';
import 'features/users/user_detail_screen.dart';
import 'features/users/users_screen.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});
  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AdminSession session = AdminSession();
  final api = AdminApi();
  late final GoRouter router = _buildRouter();

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: session,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        switch (session.status) {
          case SessionStatus.loading:
            return null;
          case SessionStatus.signedOut:
          case SessionStatus.notAdmin:
            return loc == '/login' ? null : '/login';
          case SessionStatus.admin:
            return loc == '/login' ? '/' : null;
        }
      },
      routes: [
        GoRoute(path: '/login', builder: (_, _) => LoginScreen(session: session)),
        ShellRoute(
          builder: (_, state, child) =>
              AdminShell(session: session, location: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
            GoRoute(
              path: '/users',
              redirect: (_, _) =>
                  session.canAny([Cap.usersRead, Cap.usersManage]) ? null : '/',
              builder: (_, _) => UsersScreen(session: session, api: api),
              routes: [
                GoRoute(
                  path: ':uid',
                  builder: (_, s) => UserDetailScreen(
                    uid: s.pathParameters['uid']!,
                    session: session,
                    api: api,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/partners',
              redirect: (_, _) => session.can(Cap.studioActivation) ? null : '/',
              builder: (_, _) => PartnersScreen(session: session, api: api),
              routes: [
                GoRoute(
                  path: ':partnerId',
                  builder: (_, s) => PartnerDetailScreen(
                    partnerId: s.pathParameters['partnerId']!,
                    session: session,
                    api: api,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/plans',
              redirect: (_, _) => session.canAny([
                Cap.plansManage,
                Cap.studioActivation,
                Cap.usersManage,
              ])
                  ? null
                  : '/',
              builder: (_, _) => PlansScreen(session: session, api: api),
            ),
            GoRoute(
              path: '/campaigns',
              redirect: (_, _) => session.can(Cap.campaignsManage) ? null : '/',
              builder: (_, _) => CampaignsScreen(session: session, api: api),
            ),
            GoRoute(
              path: '/support',
              redirect: (_, _) => session.can(Cap.support) ? null : '/',
              builder: (_, _) => SupportScreen(session: session, api: api),
            ),
            GoRoute(
              path: '/features',
              redirect: (_, _) => session.canAny([
                Cap.featuresManage,
                Cap.aiConfiguration,
              ])
                  ? null
                  : '/',
              builder: (_, _) => FeatureFlagsScreen(session: session, api: api),
            ),
            GoRoute(
              path: '/admins',
              redirect: (_, _) => session.can(Cap.adminsManage) ? null : '/',
              builder: (_, _) => AdminsScreen(session: session, api: api),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    session.dispose();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FitGen Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
