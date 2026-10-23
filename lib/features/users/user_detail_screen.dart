import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/admin_api.dart';
import '../../core/admin_session.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/status_badge.dart';

class UserDetailScreen extends StatefulWidget {
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
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 5, vsync: this);
  bool _busy = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _adjustCoins(int currentCoins) async {
    final amountCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    bool isCredit = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Adjust User Coins'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Balance: $currentCoins coins', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Add Credits (+)')),
                    ButtonSegment(value: false, label: Text('Deduct Credits (-)')),
                  ],
                  selected: {isCredit},
                  onSelectionChanged: (s) => setS(() => isCredit = s.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtl,
                  decoration: const InputDecoration(labelText: 'Amount (Coins) *', hintText: 'e.g. 50'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtl,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Adjustment (required) *',
                    hintText: 'e.g. Compensation for canceled session',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (amountCtl.text.trim().isEmpty || reasonCtl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Apply Adjustment'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final parsed = int.tryParse(amountCtl.text.trim()) ?? 0;
    if (parsed <= 0) return;
    final delta = isCredit ? parsed : -parsed;

    setState(() => _busy = true);
    try {
      final newBal = await widget.api.adjustCoins(
        uid: widget.uid,
        amount: delta,
        reason: reasonCtl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coins adjusted. New balance: $newBal')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _busy = true);
    try {
      final link = await widget.api.resetPassword(uid: widget.uid);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Password Reset Link Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share this one-time link with the user:'),
                const SizedBox(height: 12),
                SelectableText(link, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
                child: const Text('Copy Link'),
              ),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
            ],
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restrict(String status) async {
    final reasonCtl = TextEditingController();
    var days = 7;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(status == 'blocked' ? 'Block User Account' : 'Suspend User Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status == 'blocked'
                    ? 'Blocking will disable Auth sign-in immediately and force token revocation.'
                    : 'Suspension temporarily stops account activity for a set duration.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtl,
                decoration: const InputDecoration(labelText: 'Reason (required) *', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              if (status == 'suspended') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: days,
                  decoration: const InputDecoration(labelText: 'Suspension Duration', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 day')),
                    DropdownMenuItem(value: 3, child: Text('3 days')),
                    DropdownMenuItem(value: 7, child: Text('7 days')),
                    DropdownMenuItem(value: 14, child: Text('14 days')),
                    DropdownMenuItem(value: 30, child: Text('30 days')),
                  ],
                  onChanged: (v) => setS(() => days = v ?? 7),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () {
                if (reasonCtl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: Text(status == 'blocked' ? 'Block User' : 'Suspend User'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.api.setUserStatus(
        uid: widget.uid,
        status: status,
        reason: reasonCtl.text.trim(),
        blockedUntil: status == 'suspended' ? DateTime.now().add(Duration(days: days)) : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User status updated to $status')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Activate User',
      message: 'Restore full account access and unblock this user?',
      confirmLabel: 'Activate',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.setUserStatus(uid: widget.uid, status: 'active');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User account activated successfully')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.session.can(Cap.usersManage);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!.data();
        if (d == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('User Detail')),
            body: const EmptyState(title: 'User Not Found', message: 'No record exists for this UID.'),
          );
        }

        final status = (d['accountStatus'] as String?) ?? 'active';
        final name = (d['name'] as String?) ?? '(unnamed)';
        final email = (d['email'] as String?) ?? 'No email';
        final coins = (d['coins'] is num) ? (d['coins'] as num).toInt() : 0;

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/users'),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            StatusBadge(status),
                          ],
                        ),
                        Text('$email  •  UID: ${widget.uid}', style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    if (canManage && !_busy) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.monetization_on_outlined),
                        label: const Text('Adjust Coins'),
                        onPressed: () => _adjustCoins(coins),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Reset Password'),
                        onPressed: _resetPassword,
                      ),
                      const SizedBox(width: 8),
                      if (status == 'active') ...[
                        OutlinedButton(onPressed: () => _restrict('suspended'), child: const Text('Suspend')),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                          onPressed: () => _restrict('blocked'),
                          child: const Text('Block'),
                        ),
                      ] else ...[
                        FilledButton(onPressed: _activate, child: const Text('Activate')),
                      ],
                    ],
                    if (_busy) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 20),

                // Tabs
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.person_outline), text: 'Profile & Account'),
                    Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Wallet & Coins'),
                    Tab(icon: Icon(Icons.event_available_outlined), text: 'Bookings & Passes'),
                    Tab(icon: Icon(Icons.tune), text: 'Feature Overrides'),
                    Tab(icon: Icon(Icons.warning_amber), text: 'Risk Flags & Reports'),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfileTab(d, status),
                      _buildWalletTab(coins),
                      _buildBookingsTab(),
                      _buildFeaturesTab(),
                      _buildRiskTab(status, d),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileTab(Map<String, dynamic> d, String status) {
    return ListView(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                _row('UID', widget.uid),
                _row('Full Name', d['name']),
                _row('Email', d['email']),
                _row('Phone', d['phone']),
                _row('Role', d['role']),
                _row('Subscription', d['subscriptionType'] ?? 'free'),
                _row('City', d['city']),
                _row('Profile Completed', d['isProfileCompleted']?.toString() ?? 'false'),
                _row('Created At', _formatTimestamp(d['createdAt'])),
                _row('Last Active At', _formatTimestamp(d['lastActiveAt'])),
                if (status != 'active') _row('Restriction Reason', d['blockedReason']),
                if (d['blockedUntil'] != null) _row('Suspended Until', _formatTimestamp(d['blockedUntil'])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletTab(int coins) {
    final theme = Theme.of(context);
    final txQuery = FirebaseFirestore.instance
        .collection('coinTransactions')
        .where('userId', isEqualTo: widget.uid)
        .limit(50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            SizedBox(
              width: 260,
              child: MetricCard(
                title: 'Coin Balance',
                value: Text('$coins Coins'),
                icon: Icons.monetization_on,
                color: Colors.amber.shade800,
                subtitle: 'Available credits',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Transaction History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: txQuery.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return const EmptyState(
                  title: 'No Coin Transactions',
                  message: 'This user has no logged coin ledger transactions.',
                  icon: Icons.receipt_long_outlined,
                );
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = docs[index].data();
                    final amount = (t['amount'] as num?)?.toInt() ?? 0;
                    final isPos = amount >= 0;
                    final source = t['source'] ?? 'transaction';
                    final reason = t['reason'] ?? '';
                    final at = _formatTimestamp(t['createdAt']);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPos ? Colors.green.shade50 : Colors.red.shade50,
                        child: Icon(isPos ? Icons.add : Icons.remove, color: isPos ? Colors.green : Colors.red),
                      ),
                      title: Text('$source ${reason.isNotEmpty ? "• $reason" : ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Date: $at  •  Balance After: ${t['balanceAfter'] ?? 'N/A'}'),
                      trailing: Text(
                        '${isPos ? "+" : ""}$amount',
                        style: TextStyle(
                          color: isPos ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsTab() {
    final reqs = FirebaseFirestore.instance
        .collection('sessionRequests')
        .where('userId', isEqualTo: widget.uid)
        .limit(30);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: reqs.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const EmptyState(
            title: 'No Bookings or Session Requests',
            message: 'User has not created any class or mentor bookings.',
            icon: Icons.event_busy,
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final b = docs[index].data();
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                title: Text('Booking #${docs[index].id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Mentor: ${b['mentorId'] ?? 'N/A'}  •  Status: ${b['status'] ?? 'pending'}'),
                trailing: StatusBadge(b['status'] ?? 'pending'),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFeaturesTab() {
    final ref = FirebaseFirestore.instance.collection('userFeatureAccess').doc(widget.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final overrides = (data?['overrides'] as Map<String, dynamic>?) ?? {};

        const features = [
          ('fg_coach', 'FG Coach Living Plans & AI Chat'),
          ('future_you_studio', 'Future-You Studio 3D Body Model'),
          ('ai_partner_search', 'AI-Powered Workout Partner Matching'),
          ('fit_squad', 'FitSquad Group Training & Challenges'),
          ('challenges', 'Gamified Community Fitness Challenges'),
          ('mentor_booking', '1-on-1 Mentor & Trainer Video Sessions'),
        ];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Per-User Feature Access Overrides', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Override global feature gates specifically for this account.', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                const Divider(height: 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: features.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final (key, desc) = features[index];
                      final isOverridden = overrides.containsKey(key);
                      final isEnabled = isOverridden && (overrides[key]['enabled'] == true);

                      return SwitchListTile(
                        title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isOverridden
                              ? 'Explicit override: ${isEnabled ? "ENABLED" : "DISABLED"}'
                              : 'Default (Inherits from Plan Tier)',
                        ),
                        value: isEnabled,
                        onChanged: (val) async {
                          final updated = Map<String, dynamic>.from(overrides);
                          updated[key] = {'enabled': val};
                          await widget.api.setUserFeatures(uid: widget.uid, overrides: updated);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRiskTab(String status, Map<String, dynamic> d) {
    return ListView(
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account Risk Assessment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                _row('Account Status', status.toUpperCase()),
                _row('Restriction Reason', d['blockedReason'] ?? 'None recorded'),
                _row('Suspended Until', d['blockedUntil'] != null ? _formatTimestamp(d['blockedUntil']) : 'N/A'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Reports Filed Against this User', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('supportTickets')
              .where('reportedUid', isEqualTo: widget.uid)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No reports or complaints logged against this user account.'),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final report = doc.data();
                return Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.report_problem, color: Colors.red),
                    title: Text(report['subject'] ?? 'User Report', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(report['body'] ?? 'No details supplied'),
                    trailing: StatusBadge(report['status'] ?? 'open'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value?.toString() ?? 'None', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
    }
    return timestamp?.toString() ?? 'N/A';
  }
}
