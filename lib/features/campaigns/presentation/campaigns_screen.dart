import 'package:fitgen_admin/core/admin_api.dart';
import 'package:fitgen_admin/core/admin_session.dart';
import 'package:fitgen_admin/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({
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
                Text('Campaigns & Marketing', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('New Campaign'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: EmptyState(
                title: 'Campaigns',
                message: 'Pushes, promo coupons, challenges, and broadcast announcements.',
                icon: Icons.campaign_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
