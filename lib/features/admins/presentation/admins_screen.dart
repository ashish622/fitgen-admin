import 'package:fitgen_admin/core/admin_api.dart';
import 'package:fitgen_admin/core/admin_session.dart';
import 'package:fitgen_admin/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class AdminsScreen extends StatelessWidget {
  const AdminsScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Admins & Audit Trail', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Admin'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: EmptyState(
                title: 'Platform Admins & Audit Logs',
                message: 'Manage admin roles, capabilities, and inspect the immutable audit trail.',
                icon: Icons.security_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
