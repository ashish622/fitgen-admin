import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
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
  late final TabController _tabController = TabController(length: 5, vsync: this);
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

  Future<void> _seedCatalogDefaults() async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Seed Default Store Products',
      message:
          'Populate default subscription plans (fitmate_lite, flex, basic_annual) and coin packs (50, 100, 200 credits) in Firestore? Existing customized fields will be preserved.',
      confirmLabel: 'Seed Catalog',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      final out = await widget.api.seedDefaultCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Default catalog seeded: ${out["subscriptionPlansCount"]} sub plans, ${out["coinPlansCount"]} coin packs')),
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

  Future<void> _openUpsertSubPlanDialog([Map<String, dynamic>? initial]) async {
    final idCtl = TextEditingController(text: initial?['planId'] ?? '');
    final titleCtl = TextEditingController(text: initial?['title'] ?? '');
    final subCtl = TextEditingController(text: initial?['subtitle'] ?? '');
    final descCtl = TextEditingController(text: initial?['description'] ?? '');
    final iosCtl = TextEditingController(text: initial?['iosProductId'] ?? '');
    final androidCtl =
        TextEditingController(text: initial?['androidProductId'] ?? '');
    final priceCtl =
        TextEditingController(text: initial?['fallbackPriceDisplay'] ?? '');
    final badgeCtl = TextEditingController(text: initial?['badgeText'] ?? '');
    final featuresCtl = TextEditingController(
        text: (initial?['features'] as List?)?.join('\n') ?? '');
    String billingPeriod = initial?['billingPeriod'] ?? 'monthly';
    bool isHighlighted = initial?['isHighlighted'] ?? false;
    bool active = initial?['active'] ?? true;
    final isEdit = initial != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit
              ? 'Edit Subscription Plan'
              : 'New Subscription Plan'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: idCtl,
                    readOnly: isEdit,
                    decoration: const InputDecoration(
                      labelText: 'Plan ID (Unique Key) *',
                      hintText: 'e.g. flex or pro_annual',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Display Title *',
                      hintText: 'e.g. FitGen Pro Annual',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: billingPeriod,
                          decoration:
                              const InputDecoration(labelText: 'Billing Cadence'),
                          items: const [
                            DropdownMenuItem(
                                value: 'monthly', child: Text('Monthly')),
                            DropdownMenuItem(
                                value: 'annual', child: Text('Annual')),
                            DropdownMenuItem(
                                value: 'quarterly', child: Text('Quarterly')),
                          ],
                          onChanged: (v) =>
                              setS(() => billingPeriod = v ?? 'monthly'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priceCtl,
                          decoration: const InputDecoration(
                            labelText: 'Display Price (Fallback)',
                            hintText: 'e.g. \$19.99/mo',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: iosCtl,
                          decoration: const InputDecoration(
                            labelText: 'Apple IAP Product ID *',
                            hintText: 'e.g. basic_annual',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: androidCtl,
                          decoration: const InputDecoration(
                            labelText: 'Google Play Product ID *',
                            hintText: 'e.g. basic_annual',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: badgeCtl,
                    decoration: const InputDecoration(
                      labelText: 'Highlight Badge (Optional)',
                      hintText: 'e.g. BEST VALUE or MOST POPULAR',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(
                      labelText: 'Short Description',
                      hintText: 'Year-round access to AI Living Plan & Coach',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: featuresCtl,
                    decoration: const InputDecoration(
                      labelText: 'Feature Bullets (One per line)',
                      hintText:
                          'Unlimited AI Living Plan\nFG Coach Voice & Vision\nPriority Mentor Matching',
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Highlight as Recommended / Popular'),
                    value: isHighlighted,
                    onChanged: (v) => setS(() => isHighlighted = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Visible in App (Active)'),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (idCtl.text.trim().isEmpty ||
                    titleCtl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Plan'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    setState(() => _busy = true);
    try {
      final features = featuresCtl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await widget.api.upsertSubscriptionPlan(
        planId: idCtl.text.trim(),
        title: titleCtl.text.trim(),
        subtitle: subCtl.text.trim(),
        description: descCtl.text.trim(),
        billingPeriod: billingPeriod,
        iosProductId: iosCtl.text.trim().isEmpty
            ? idCtl.text.trim()
            : iosCtl.text.trim(),
        androidProductId: androidCtl.text.trim().isEmpty
            ? idCtl.text.trim()
            : androidCtl.text.trim(),
        fallbackPriceDisplay: priceCtl.text.trim(),
        features: features,
        badgeText: badgeCtl.text.trim().isEmpty ? null : badgeCtl.text.trim(),
        isHighlighted: isHighlighted,
        active: active,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription plan ${idCtl.text} saved')),
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

  Future<void> _deleteSubPlan(String planId) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Delete Subscription Plan',
      message: 'Remove subscription plan "$planId"? Store subscriptions will not be deleted.',
      confirmLabel: 'Delete',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteSubscriptionPlan(planId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan $planId deleted')),
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

  Future<void> _openUpsertCoinPlanDialog([Map<String, dynamic>? initial]) async {
    final idCtl = TextEditingController(text: initial?['planId'] ?? '');
    final titleCtl = TextEditingController(text: initial?['title'] ?? '');
    final descCtl = TextEditingController(text: initial?['description'] ?? '');
    final coinsCtl =
        TextEditingController(text: (initial?['coins'] ?? 100).toString());
    final bonusCtl =
        TextEditingController(text: (initial?['bonusCoins'] ?? 0).toString());
    final iosCtl = TextEditingController(text: initial?['iosProductId'] ?? '');
    final androidCtl =
        TextEditingController(text: initial?['androidProductId'] ?? '');
    final priceCtl =
        TextEditingController(text: initial?['fallbackPriceDisplay'] ?? '');
    final badgeCtl = TextEditingController(text: initial?['badgeText'] ?? '');
    bool isPopular = initial?['isPopular'] ?? false;
    bool active = initial?['active'] ?? true;
    final isEdit = initial != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? 'Edit Coin Pack' : 'New Coin Pack (Credit Pack)'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: idCtl,
                    readOnly: isEdit,
                    decoration: const InputDecoration(
                      labelText: 'Pack ID (Unique Key) *',
                      hintText: 'e.g. 100_credits',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Display Title *',
                      hintText: 'e.g. 100 Credits Pack',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: coinsCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Base Coins *',
                            hintText: '100',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: bonusCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Bonus Coins (Promo)',
                            hintText: '20',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: iosCtl,
                          decoration: const InputDecoration(
                            labelText: 'Apple IAP Product ID *',
                            hintText: '100_credits',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: androidCtl,
                          decoration: const InputDecoration(
                            labelText: 'Google Play Product ID *',
                            hintText: '100_credits',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtl,
                          decoration: const InputDecoration(
                            labelText: 'Display Price (Fallback)',
                            hintText: '\$9.99',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: badgeCtl,
                          decoration: const InputDecoration(
                            labelText: 'Badge (e.g. POPULAR)',
                            hintText: 'POPULAR',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'For extra mentor sessions & AI coach runs',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Highlight as Popular Pack'),
                    value: isPopular,
                    onChanged: (v) => setS(() => isPopular = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Visible in Store (Active)'),
                    value: active,
                    onChanged: (v) => setS(() => active = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (idCtl.text.trim().isEmpty ||
                    titleCtl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Coin Pack'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    setState(() => _busy = true);
    try {
      final coins = int.tryParse(coinsCtl.text.trim()) ?? 100;
      final bonus = int.tryParse(bonusCtl.text.trim()) ?? 0;

      await widget.api.upsertCoinPlan(
        planId: idCtl.text.trim(),
        title: titleCtl.text.trim(),
        description: descCtl.text.trim(),
        coins: coins,
        bonusCoins: bonus,
        iosProductId: iosCtl.text.trim().isEmpty
            ? idCtl.text.trim()
            : iosCtl.text.trim(),
        androidProductId: androidCtl.text.trim().isEmpty
            ? idCtl.text.trim()
            : androidCtl.text.trim(),
        fallbackPriceDisplay: priceCtl.text.trim(),
        badgeText: badgeCtl.text.trim().isEmpty ? null : badgeCtl.text.trim(),
        isPopular: isPopular,
        active: active,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coin pack ${idCtl.text} saved')),
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

  Future<void> _deleteCoinPlan(String planId) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Delete Coin Pack',
      message: 'Remove coin pack "$planId"? Existing user balances will not be affected.',
      confirmLabel: 'Delete',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteCoinPlan(planId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coin pack $planId deleted')),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plans & Subscriptions', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Manage studio visit allowances, member enrollments, store subscription tiers, and coin packs.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (canManage) ...[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _seedCatalogDefaults,
                    icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                    label: const Text('Seed Default SKUs'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_tabController.index == 0) {
                              // Studio plans
                              showDialog<bool>(
                                context: context,
                                builder: (_) => CreatePlanDialog(
                                  api: widget.api,
                                  initialPartnerId: _selectedPartnerId,
                                ),
                              );
                            } else if (_tabController.index == 2) {
                              _openUpsertSubPlanDialog();
                            } else if (_tabController.index == 3) {
                              _openUpsertCoinPlanDialog();
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: Text(_tabController.index == 0
                        ? 'Create Studio Plan'
                        : (_tabController.index == 2
                            ? 'New Subscription Plan'
                            : (_tabController.index == 3
                                ? 'New Coin Pack'
                                : 'Add Item'))),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(icon: Icon(Icons.fitness_center), text: 'Studio Pass Plans'),
                Tab(icon: Icon(Icons.group_outlined), text: 'Member Enrollments'),
                Tab(icon: Icon(Icons.workspace_premium), text: 'Subscription Plans'),
                Tab(icon: Icon(Icons.monetization_on_outlined), text: 'Coin Plans (Credit Packs)'),
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
                  _buildCoinPlansTab(),
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
    final canManage = widget.session.canAny([Cap.plansManage, Cap.studioActivation]);
    if (Firebase.apps.isEmpty) {
      return const SizedBox.shrink();
    }
    final users = FirebaseFirestore.instance.collection('users');

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Store Subscription Catalog',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  'These plans dynamically populate the mobile subscription screen with live App Store & Google Play billing.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (canManage)
              FilledButton.tonalIcon(
                onPressed: _openUpsertSubPlanDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Subscription Plan'),
              ),
          ],
        ),
        const SizedBox(height: 16),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('subscriptionPlans')
              .orderBy('sortOrder')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;

            if (docs.isEmpty) {
              return EmptyState(
                title: 'No Subscription Plans Defined',
                message:
                    'Click "Seed Default SKUs" above or "Add Subscription Plan" to configure plans.',
                icon: Icons.workspace_premium_outlined,
                actionLabel: canManage ? 'Seed Default Store SKUs' : null,
                onAction: canManage ? _seedCatalogDefaults : null,
              );
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data();
                  final planId = d['planId'] ?? doc.id;
                  final title = d['title'] ?? planId;
                  final period = d['billingPeriod'] ?? 'monthly';
                  final price = d['fallbackPriceDisplay'] ?? '';
                  final active = d['active'] != false;
                  final badge = d['badgeText'];
                  final features = (d['features'] as List?)?.cast<String>() ?? [];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor:
                          active ? Colors.purple.shade100 : Colors.grey.shade200,
                      foregroundColor:
                          active ? Colors.purple.shade900 : Colors.grey.shade600,
                      child: const Icon(Icons.workspace_premium),
                    ),
                    title: Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        StatusBadge(active ? 'active' : 'inactive'),
                        if (badge != null && badge.toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(badge.toString()),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: $planId  •  Cadence: ${period.toString().toUpperCase()}  •  Fallback Price: $price',
                            style: TextStyle(
                                color: theme.colorScheme.outline, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Apple: ${d["iosProductId"]}  •  Google: ${d["androidProductId"]}',
                            style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontSize: 12,
                                fontFamily: 'RobotoMono'),
                          ),
                          if (features.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Features: ${features.join(" • ")}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    trailing: canManage
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit Plan',
                                onPressed: () => _openUpsertSubPlanDialog({
                                  'planId': planId,
                                  ...d,
                                }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                tooltip: 'Delete Plan',
                                onPressed: () => _deleteSubPlan(planId),
                              ),
                            ],
                          )
                        : null,
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        Text('Active Pro Subscribers in Database',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: users
              .where('subscriptionType', isEqualTo: 'pro')
              .limit(50)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;

            if (docs.isEmpty) {
              return const EmptyState(
                title: 'No Pro Subscribers Yet',
                message: 'No users currently have an active Pro subscription.',
                icon: Icons.person_off_outlined,
              );
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                      ? DateFormat.yMMMd().format(
                          (d['subscriptionExpiresAt'] as Timestamp).toDate())
                      : 'Recurring (Active)';

                  return ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.star, color: Colors.amber)),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$email  •  Expires: $expires'),
                    trailing:
                        const StatusBadge('active', customLabel: 'PRO'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCoinPlansTab() {
    final theme = Theme.of(context);
    final canManage = widget.session.canAny([Cap.plansManage, Cap.studioActivation]);
    if (Firebase.apps.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Coin Packs (Credit Packs)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  'Credit packs purchased via Apple / Google in-app purchase for mentor sessions & living plans.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (canManage)
              FilledButton.tonalIcon(
                onPressed: _openUpsertCoinPlanDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Coin Pack'),
              ),
          ],
        ),
        const SizedBox(height: 16),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('coinPlans')
              .orderBy('sortOrder')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;

            if (docs.isEmpty) {
              return EmptyState(
                title: 'No Coin Packs Configured',
                message:
                    'Click "Seed Default SKUs" above or "Add Coin Pack" to define packs.',
                icon: Icons.monetization_on_outlined,
                actionLabel: canManage ? 'Seed Default Store SKUs' : null,
                onAction: canManage ? _seedCatalogDefaults : null,
              );
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data();
                  final planId = d['planId'] ?? doc.id;
                  final title = d['title'] ?? planId;
                  final coins = d['coins'] ?? 0;
                  final bonus = d['bonusCoins'] ?? 0;
                  final price = d['fallbackPriceDisplay'] ?? '';
                  final active = d['active'] != false;
                  final isPopular = d['isPopular'] == true;
                  final badge = d['badgeText'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor:
                          active ? Colors.amber.shade100 : Colors.grey.shade200,
                      foregroundColor:
                          active ? Colors.amber.shade900 : Colors.grey.shade600,
                      child: const Icon(Icons.toll),
                    ),
                    title: Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        StatusBadge(active ? 'active' : 'inactive'),
                        if (isPopular) ...[
                          const SizedBox(width: 8),
                          Chip(
                            backgroundColor: Colors.orange.shade50,
                            label: const Text('POPULAR',
                                style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        if (badge != null &&
                            badge.toString().isNotEmpty &&
                            !isPopular) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(badge.toString()),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coins: $coins ${bonus > 0 ? "+ $bonus BONUS" : ""}  •  Fallback: $price',
                            style: TextStyle(
                                color: theme.colorScheme.outline, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Apple: ${d["iosProductId"]}  •  Google: ${d["androidProductId"]}',
                            style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontSize: 12,
                                fontFamily: 'RobotoMono'),
                          ),
                        ],
                      ),
                    ),
                    trailing: canManage
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit Pack',
                                onPressed: () => _openUpsertCoinPlanDialog({
                                  'planId': planId,
                                  ...d,
                                }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                tooltip: 'Delete Pack',
                                onPressed: () => _deleteCoinPlan(planId),
                              ),
                            ],
                          )
                        : null,
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
