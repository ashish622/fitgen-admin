import 'package:fitgen_admin/core/admin_api.dart';
import 'package:fitgen_admin/core/admin_session.dart';
import 'package:fitgen_admin/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({
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
                Text('Support & Feedback', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: EmptyState(
                title: 'Support Inbox & Moderation',
                message: 'Tickets, user abuse reports, and app satisfaction feedback.',
                icon: Icons.support_agent_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
