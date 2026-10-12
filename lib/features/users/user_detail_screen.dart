import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/admin_api.dart';
import '../../core/admin_session.dart';
import 'status_chip.dart';

class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({
    super.key,
    required this.uid,
    required this.session,
    required this.api,
  });
  final String uid;
  final AdminSession session;
  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!.data();
        if (d == null) return const Center(child: Text('User not found.'));
        final status = (d['accountStatus'] as String?) ?? 'active';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/users')),
              Text((d['name'] as String?) ?? '(no name)',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 12),
              StatusChip(status),
              const Spacer(),
              if (session.can(Cap.usersManage) && uid != session.user?.uid)
                ..._actions(context, status),
            ]),
            const SizedBox(height: 16),
            Card(
              child: Column(children: [
                _row('UID', uid),
                _row('Email', d['email']),
                _row('Phone', d['phone']),
                _row('Role', d['role']),
                _row('Coins', d['coins']),
                _row('Subscription', d['subscriptionType']),
                _row('City', d['city']),
                _row('Created', _fmt(d['createdAt'])),
                if (status != 'active') _row('Restriction reason', d['blockedReason']),
                if (d['blockedUntil'] != null) _row('Suspended until', _fmt(d['blockedUntil'])),
              ]),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _actions(BuildContext context, String status) {
    return [
      if (status == 'active') ...[
        OutlinedButton(
            onPressed: () => _restrict(context, 'suspended'), child: const Text('Suspend')),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => _restrict(context, 'blocked'),
          child: const Text('Block'),
        ),
      ] else
        FilledButton(onPressed: () => _activate(context), child: const Text('Activate')),
    ];
  }

  Future<void> _restrict(BuildContext context, String status) async {
    final reasonCtl = TextEditingController();
    var days = 7;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(status == 'blocked' ? 'Block user' : 'Suspend user'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: reasonCtl,
              decoration: const InputDecoration(labelText: 'Reason (required)'),
              maxLines: 2,
            ),
            if (status == 'suspended')
              DropdownButtonFormField<int>(
                initialValue: days,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: const [1, 3, 7, 14, 30]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n days')))
                    .toList(),
                onChanged: (v) => setS(() => days = v ?? 7),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _call(
      context,
      () => api.setUserStatus(
        uid: uid,
        status: status,
        reason: reasonCtl.text,
        blockedUntil:
            status == 'suspended' ? DateTime.now().add(Duration(days: days)) : null,
      ),
    );
  }

  Future<void> _activate(BuildContext context) =>
      _call(context, () => api.setUserStatus(uid: uid, status: 'active'));

  Future<void> _call(BuildContext context, Future<void> Function() fn) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await fn();
      messenger.showSnackBar(const SnackBar(content: Text('Updated.')));
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    }
  }

  static String? _fmt(dynamic v) =>
      v is Timestamp ? DateFormat.yMMMd().add_jm().format(v.toDate()) : null;

  static Widget _row(String label, dynamic value) => ListTile(
        dense: true,
        title: Text(label),
        trailing: SelectableText(value?.toString() ?? '—'),
      );
}
