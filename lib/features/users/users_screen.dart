import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_api.dart';
import '../../core/admin_session.dart';
import 'create_user_dialog.dart';
import 'status_chip.dart';

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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Email-prefix search; ordered by email so prefix range queries work.
  /// Status is filtered client-side to avoid a composite index per combo.
  Query<Map<String, dynamic>> get _queryRef {
    var q = FirebaseFirestore.instance.collection('users').orderBy('email');
    if (_query.isNotEmpty) {
      q = q.startAt([_query]).endAt(['$_query\uf8ff']);
    }
    return q.limit(_pageSize);
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.session.can(Cap.usersManage);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Users', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            if (canManage)
              FilledButton.icon(
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add user'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => CreateUserDialog(api: widget.api),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by email prefix',
                ),
                onSubmitted: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(width: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'blocked', label: Text('Blocked')),
                ButtonSegment(value: 'suspended', label: Text('Suspended')),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (s) => setState(() => _statusFilter = s.first),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _queryRef.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Failed to load users: ${snap.error}');
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs.where((d) {
                  final s = (d.data()['accountStatus'] as String?) ?? 'active';
                  return _statusFilter == 'all' || s == _statusFilter;
                }).toList();
                if (docs.isEmpty) return const Text('No users found.');
                return Card(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      return ListTile(
                        title: Text((d['name'] as String?) ?? '(no name)'),
                        subtitle: Text((d['email'] as String?) ?? docs[i].id),
                        trailing: StatusChip((d['accountStatus'] as String?) ?? 'active'),
                        onTap: () => context.go('/users/${docs[i].id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
