import 'package:fitgen_admin/core/admin_api.dart';
import 'package:fitgen_admin/core/admin_session.dart';
import 'package:fitgen_admin/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({
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
                Text('Plans & Subscriptions', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Create Plan'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: EmptyState(
                title: 'Plans Center',
                message: 'Manage Studio allowances, FitGen Pro memberships, and AI Living plans.',
                icon: Icons.card_membership_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
