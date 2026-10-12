import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/admin_api.dart';
import 'core/admin_session.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/shell/admin_shell.dart';
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
              redirect: (_, _) => session.can(Cap.usersRead) ? null : '/',
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
