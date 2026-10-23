import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/metric_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<int> _count(Query<Map<String, dynamic>> q) async {
    try {
      final snap = await q.count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Widget _countText(Future<int> future) {
    return FutureBuilder<int>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }
        return Text('${snap.data ?? 0}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;
    final users = fs.collection('users');
    final partners = fs.collection('partners');
    final tickets = fs.collection('supportTickets');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operations Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'High-level operational overview across users, partner studios, plans, and support.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 28),

          Text(
            'Users & Memberships',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 900
                  ? (constraints.maxWidth - 48) / 4
                  : (constraints.maxWidth > 600
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Total Users',
                      icon: Icons.people_outline,
                      value: _countText(_count(users)),
                      onTap: () => context.go('/users'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Active Accounts',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      value: _countText(
                        _count(users.where('accountStatus', isEqualTo: 'active')),
                      ),
                      onTap: () => context.go('/users'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Suspended Users',
                      icon: Icons.pause_circle_outline,
                      color: Colors.orange,
                      value: _countText(
                        _count(users.where('accountStatus', isEqualTo: 'suspended')),
                      ),
                      onTap: () => context.go('/users'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Blocked Users',
                      icon: Icons.block,
                      color: Colors.red,
                      value: _countText(
                        _count(users.where('accountStatus', isEqualTo: 'blocked')),
                      ),
                      onTap: () => context.go('/users'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          Text(
            'Partners & Studios',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 900
                  ? (constraints.maxWidth - 48) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Total Partner Studios',
                      icon: Icons.storefront_outlined,
                      color: Colors.teal,
                      value: _countText(_count(partners)),
                      onTap: () => context.go('/partners'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Active Studios',
                      icon: Icons.verified_outlined,
                      color: Colors.green,
                      value: _countText(
                        _count(partners.where('status', isEqualTo: 'active')),
                      ),
                      onTap: () => context.go('/partners'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Pending Activation',
                      icon: Icons.pending_actions_outlined,
                      color: Colors.amber.shade800,
                      value: _countText(
                        _count(partners.where('status', isEqualTo: 'pending_activation')),
                      ),
                      onTap: () => context.go('/partners'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          Text(
            'Support & Moderation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 900
                  ? (constraints.maxWidth - 48) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'Open Support Tickets',
                      icon: Icons.support_agent_outlined,
                      color: Colors.indigo,
                      value: _countText(
                        _count(tickets.where('status', isEqualTo: 'open')),
                      ),
                      onTap: () => context.go('/support'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: MetricCard(
                      title: 'User Reports Pending',
                      icon: Icons.report_problem_outlined,
                      color: Colors.deepOrange,
                      value: _countText(
                        _count(tickets.where('type', isEqualTo: 'report_user')),
                      ),
                      onTap: () => context.go('/support'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
