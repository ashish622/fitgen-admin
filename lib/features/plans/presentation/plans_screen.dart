import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/admin_api.dart';
import '../../../core/admin_session.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/status_badge.dart';
import 'create_plan_dialog.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);
  String? _selectedPartnerId;
  bool _busy = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCreatePlanDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreatePlanDialog(
        api: widget.api,
        initialPartnerId: _selectedPartnerId,
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan created successfully')),
      );
    }
  }

  Future<void> _issuePeriod(String enrollmentId) async {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final res = await ConfirmDialog.show(
      context,
      title: 'Issue Period Grant',
      message: 'Issue entitlement grant for period "$key" to enrollment $enrollmentId?',
      confirmLabel: 'Issue Period',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      final out = await widget.api.issuePlanPeriod(
        enrollmentId: enrollmentId,
        periodKey: key,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Issued entitlement: ${out['entitlementId']}')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refused: ${e.message ?? e.code}'), backgroundColor: Colors.red),
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

  Future<void> _settleRollover(String enrollmentId) async {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    final key = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';

    final res = await ConfirmDialog.show(
      context,
      title: 'Settle Plan Rollover',
      message: 'Settle rollover visits from period "$key" to current period for enrollment $enrollmentId?',
      confirmLabel: 'Settle Rollover',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      final out = await widget.api.settlePlanRollover(
        enrollmentId: enrollmentId,
        periodKey: key,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rollover settled: carried ${out['carried'] ?? 0} visits')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refused: ${e.message ?? e.code}'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.session.canAny([Cap.plansManage, Cap.studioActivation]);

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
                    Text('Plans & Subscriptions', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage studio visit allowances, member enrollments, platform memberships, and living plans.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const Spacer(),
                if (canManage)
                  FilledButton.icon(
                    onPressed: _openCreatePlanDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Studio Plan'),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.fitness_center), text: 'Studio Pass Plans'),
                Tab(icon: Icon(Icons.group_outlined), text: 'Member Enrollments'),
                Tab(icon: Icon(Icons.workspace_premium), text: 'FitGen Pro Subscriptions'),
                Tab(icon: Icon(Icons.psychology_outlined), text: 'AI & Living Plans'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStudioPlansTab(),
                  _buildEnrollmentsTab(),
                  _buildPlatformSubsTab(),
                  _buildAiLivingPlansTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioPlansTab() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Studio picker filter
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 20),
                const SizedBox(width: 12),
                Text('Studio: ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('partners').snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? [];
                      if (docs.isNotEmpty && _selectedPartnerId == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedPartnerId == null) {
                            setState(() => _selectedPartnerId = docs.first.id);
                          }
                        });
                      }
                      return DropdownButton<String>(
                        value: _selectedPartnerId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('Select a Studio'),
                        items: docs.map((d) {
                          final data = d.data();
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text('${data['name'] ?? d.id} (${d.id})'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedPartnerId = v),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _selectedPartnerId == null
              ? const EmptyState(
                  title: 'Select a Partner Studio',
                  message: 'Choose a studio from the dropdown above to view its allowance plans.',
                  icon: Icons.storefront_outlined,
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('partners')
                      .doc(_selectedPartnerId)
                      .collection('plans')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;

                    if (docs.isEmpty) {
                      return EmptyState(
                        title: 'No Plans Defined for this Studio',
                        message: 'This studio does not have any Phoenix allowance plans created yet.',
                        icon: Icons.card_membership_outlined,
                        actionLabel: 'Create First Plan',
                        onAction: _openCreatePlanDialog,
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final d = doc.data();
                        final terms = (d['terms'] as Map<String, dynamic>?) ?? {};
                        final name = terms['name'] ?? doc.id;
                        final allowance = terms['allowance'];
                        final isUnlimited = allowance == 'unlimited';
                        final rollover = (terms['rollover'] as Map<String, dynamic>?) ?? {};
                        final rolloverEnabled = rollover['enabled'] == true;
                        final maxCarry = rollover['maxCarry'] ?? 0;
                        final allClassTypes = terms['allClassTypes'] == true;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.confirmation_number_outlined, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(width: 10),
                                          StatusBadge(d['status'] ?? 'active'),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'ID: ${doc.id}  •  Period: Monthly  •  Scope: ${allClassTypes ? "All Class Types" : "Specific Classes"}',
                                        style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text(isUnlimited ? 'Unlimited Visits' : '$allowance Visits / Month'),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          const SizedBox(width: 8),
                                          Chip(
                                            label: Text(rolloverEnabled ? 'Rollover: up to $maxCarry visits' : 'No Rollover'),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEnrollmentsTab() {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('planEnrollments').limit(100).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const EmptyState(
            title: 'No Plan Enrollments',
            message: 'No members have been enrolled into studio recurring plans yet.',
            icon: Icons.group_off_outlined,
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
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              final planId = d['planId'] ?? 'N/A';
              final partnerId = d['partnerId'] ?? 'N/A';
              final attendeeId = d['attendeeId'] ?? 'N/A';
              final anchorDay = d['anchorDay'] ?? 1;
              final status = d['status'] ?? 'active';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: const Icon(Icons.person, size: 20),
                ),
                title: Row(
                  children: [
                    Text('Enrollment: ${doc.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    StatusBadge(status),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Plan: $planId  •  Studio: $partnerId  •  Attendee: $attendeeId  •  Anchor Day: $anchorDay of month',
                    style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_task, size: 16),
                      label: const Text('Issue Period'),
                      onPressed: _busy ? null : () => _issuePeriod(doc.id),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.sync_alt, size: 16),
                      label: const Text('Rollover'),
                      onPressed: _busy ? null : () => _settleRollover(doc.id),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlatformSubsTab() {
    final theme = Theme.of(context);
    final users = FirebaseFirestore.instance.collection('users');

    return ListView(
      children: [
        // Comparison Cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Free Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Chip(label: Text('Standard')),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text('• Basic workout generator (1/month)'),
                      SizedBox(height: 6),
                      Text('• Standard nearby studio searches'),
                      SizedBox(height: 6),
                      Text('• Community challenge participation'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('FitGen Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Chip(
                            label: const Text('PREMIUM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('• Unlimited AI Living Plan adjustments'),
                      const SizedBox(height: 6),
                      const Text('• Full FG Coach voice & vision integration'),
                      const SizedBox(height: 6),
                      const Text('• Priority class booking & zero booking fees'),
                      const SizedBox(height: 6),
                      const Text('• Exclusive Future-You studio projections'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text('Active Pro Subscribers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: users.where('subscriptionType', isEqualTo: 'pro').limit(50).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;

            if (docs.isEmpty) {
              return const EmptyState(
                title: 'No Pro Subscribers Yet',
                message: 'No users have an active Pro subscription assigned.',
                icon: Icons.workspace_premium_outlined,
              );
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final d = docs[index].data();
                  final name = d['name'] ?? '(unnamed)';
                  final email = d['email'] ?? docs[index].id;
                  final expires = d['subscriptionExpiresAt'] is Timestamp
                      ? DateFormat.yMMMd().format((d['subscriptionExpiresAt'] as Timestamp).toDate())
                      : 'Recurring (Active)';

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.star, color: Colors.amber)),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$email  •  Expires: $expires'),
                    trailing: const StatusBadge('active', customLabel: 'PRO'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAiLivingPlansTab() {
    return ListView(
      children: [
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 250,
              child: MetricCard(
                title: 'Plan Generation Model',
                value: Text('Gemini 2.5 Flash'),
                icon: Icons.memory,
                subtitle: 'Low-latency structured plan outputs',
              ),
            ),
            SizedBox(
              width: 250,
              child: MetricCard(
                title: 'Living Plan Cadence',
                value: Text('Weekly Rebalance'),
                icon: Icons.update,
                subtitle: 'Adapts to missed or extra workouts',
              ),
            ),
            SizedBox(
              width: 250,
              child: MetricCard(
                title: 'Coin Cost per Regen',
                value: Text('25 Coins'),
                icon: Icons.monetization_on_outlined,
                subtitle: 'Standard member generation fee',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
                Text('AI Living Plan Architecture', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                const Text(
                  'FitGen Living Plans are server-generated via the coachRequestPlan and coachConfirmPlan callables. '
                  'Plans adhere to the user\'s weekly schedule, target split, and available equipment, with dynamic rebalancing.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
