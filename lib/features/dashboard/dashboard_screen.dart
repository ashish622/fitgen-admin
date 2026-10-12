import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Phase 0 dashboard: live headline counts via Firestore aggregation
/// queries. Richer charts arrive with Phase 4 (adminStats).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<int> _count(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection('users');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _StatCard('Total users', _count(users)),
          _StatCard('Blocked users',
              _count(users.where('accountStatus', isEqualTo: 'blocked'))),
          _StatCard('Suspended users',
              _count(users.where('accountStatus', isEqualTo: 'suspended'))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);
  final String label;
  final Future<int> value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: value,
                builder: (_, s) => Text(
                  s.hasError ? '—' : (s.data?.toString() ?? '…'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
