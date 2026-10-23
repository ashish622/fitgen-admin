import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_api.dart';
import '../../core/admin_session.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import 'create_user_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.session, required this.api});
  final AdminSession session;
  final AdminApi api;
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _pageSize = 100;
  final _search = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';
  String _tierFilter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Email-prefix search; ordered by email so prefix range queries work.
  Query<Map<String, dynamic>> get _queryRef {
    var q = FirebaseFirestore.instance.collection('users').orderBy('email');
    if (_query.isNotEmpty) {
      q = q.startAt([_query]).endAt(['$_query\uf8ff']);
    }
    return q.limit(_pageSize);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.session.can(Cap.usersManage);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Management', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage member accounts, coin balances, moderation flags, and subscriptions.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const Spacer(),
                if (canManage)
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Add User'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => CreateUserDialog(api: widget.api),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: 'Search by email prefix...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (v) => setState(() => _query = v.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'active', label: Text('Active')),
                        ButtonSegment(value: 'suspended', label: Text('Suspended')),
                        ButtonSegment(value: 'blocked', label: Text('Blocked')),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (s) => setState(() => _statusFilter = s.first),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _tierFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Tiers')),
                        DropdownMenuItem(value: 'pro', child: Text('Pro Tier Only')),
                        DropdownMenuItem(value: 'free', child: Text('Free Tier Only')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _tierFilter = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Users List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _queryRef.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Failed to load users: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs.where((d) {
                    final data = d.data();
                    final s = (data['accountStatus'] as String?) ?? 'active';
                    final tier = (data['subscriptionType'] as String?) ?? 'free';

                    final matchesStatus = _statusFilter == 'all' || s == _statusFilter;
                    final matchesTier = _tierFilter == 'all' || tier == _tierFilter;
                    return matchesStatus && matchesTier;
                  }).toList();

                  if (docs.isEmpty) {
                    return const EmptyState(
                      title: 'No Users Found',
                      message: 'No user accounts match the current filter criteria.',
                      icon: Icons.people_outline,
                    );
                  }

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = docs[i].data();
                        final name = (d['name'] as String?) ?? '(no name)';
                        final email = (d['email'] as String?) ?? docs[i].id;
                        final status = (d['accountStatus'] as String?) ?? 'active';
                        final role = (d['role'] as String?) ?? 'member';
                        final coins = d['coins'] ?? 0;
                        final tier = (d['subscriptionType'] as String?) ?? 'free';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: tier == 'pro' ? Colors.amber.shade100 : theme.colorScheme.primaryContainer,
                            foregroundColor: tier == 'pro' ? Colors.amber.shade900 : theme.colorScheme.primary,
                            child: Icon(tier == 'pro' ? Icons.star : Icons.person_outline, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (tier == 'pro') ...[
                                const SizedBox(width: 8),
                                const StatusBadge('active', customLabel: 'PRO'),
                              ],
                              const SizedBox(width: 8),
                              StatusBadge(status),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '$email  •  Role: $role  •  Coins: $coins  •  UID: ${docs[i].id}',
                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                            ),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () => context.go('/users/${docs[i].id}'),
                            child: const Text('Manage'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
