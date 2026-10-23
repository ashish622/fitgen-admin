import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/admin_api.dart';
import '../../../core/admin_session.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  String _statusFilter = 'all';
  bool _busy = false;

  Future<void> _openCreateDialog() async {
    final titleCtl = TextEditingController();
    final messageCtl = TextEditingController();
    String type = 'push_announcement';
    String audience = 'all';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Create New Marketing Campaign'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: 'Campaign Title *', hintText: 'e.g. November Sweat Challenge'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Campaign Type'),
                    items: const [
                      DropdownMenuItem(value: 'push_announcement', child: Text('FCM Push Broadcast')),
                      DropdownMenuItem(value: 'promo_coupon', child: Text('Promo Coins / Coupon Drop')),
                      DropdownMenuItem(value: 'challenge', child: Text('Gamified Fitness Challenge')),
                      DropdownMenuItem(value: 'in_app_banner', child: Text('In-App Dashboard Banner')),
                    ],
                    onChanged: (v) => setS(() => type = v ?? 'push_announcement'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    decoration: const InputDecoration(labelText: 'Target Audience'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Registered Users')),
                      DropdownMenuItem(value: 'pro', child: Text('FitGen Pro Members Only')),
                      DropdownMenuItem(value: 'inactive_14d', child: Text('Inactive > 14 Days')),
                      DropdownMenuItem(value: 'trial', child: Text('Free Tier Members')),
                    ],
                    onChanged: (v) => setS(() => audience = v ?? 'all'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtl,
                    decoration: const InputDecoration(labelText: 'Content / Message Body *', hintText: 'Enter campaign copy...'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtl.text.trim().isEmpty || messageCtl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Create Draft'),
            ),
          ],
        ),
      ),
    );

    if (created != true) return;
    setState(() => _busy = true);
    try {
      await widget.api.upsertCampaign(
        title: titleCtl.text.trim(),
        type: type,
        audience: {'target': audience},
        content: {'message': messageCtl.text.trim()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign created in draft status')),
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

  Future<void> _transition(String campaignId, String targetStatus) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Transition Campaign',
      message: 'Change campaign status to ${targetStatus.toUpperCase()}?',
      confirmLabel: 'Confirm',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.transitionCampaign(
        campaignId: campaignId,
        targetStatus: targetStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign is now $targetStatus')),
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
    final canManage = widget.session.can(Cap.campaignsManage);

    Stream<QuerySnapshot<Map<String, dynamic>>> queryStream;
    if (Firebase.apps.isEmpty) {
      queryStream = const Stream.empty();
    } else {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('campaigns');
      if (_statusFilter != 'all') {
        q = q.where('status', isEqualTo: _statusFilter);
      }
      queryStream = q.snapshots();
    }

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
                      Text('Campaigns & Marketing', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Broadcast announcements, manage coupons, and launch fitness engagement challenges.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (canManage)
                  FilledButton.icon(
                    onPressed: _busy ? null : _openCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('New Campaign'),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Filters
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
                    const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _statusFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Campaigns')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'live', child: Text('Live / Active')),
                        DropdownMenuItem(value: 'ended', child: Text('Ended')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _statusFilter = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Campaigns List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: queryStream,
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;

                  if (docs.isEmpty) {
                    return const EmptyState(
                      title: 'No Campaigns Found',
                      message: 'Create a campaign to engage users with push alerts, bonuses, or challenges.',
                      icon: Icons.campaign_outlined,
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
                        final doc = docs[index];
                        final d = doc.data();
                        final title = d['title'] ?? 'Campaign';
                        final status = d['status'] ?? 'draft';
                        final type = d['type'] ?? 'push_announcement';
                        final audience = (d['audience'] as Map<String, dynamic>?)?['target'] ?? 'all';
                        final content = (d['content'] as Map<String, dynamic>?)?['message'] ?? '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: status == 'live' ? Colors.green.shade100 : Colors.indigo.shade100,
                            foregroundColor: status == 'live' ? Colors.green.shade900 : Colors.indigo.shade900,
                            child: Icon(status == 'live' ? Icons.sensors : Icons.campaign),
                          ),
                          title: Row(
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 10),
                              StatusBadge(status),
                              const SizedBox(width: 8),
                              Chip(label: Text(type.replaceAll('_', ' ').toUpperCase()), visualDensity: VisualDensity.compact),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Target: $audience  •  $content',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status == 'draft')
                                FilledButton.tonal(
                                  onPressed: () => _transition(doc.id, 'pending_approval'),
                                  child: const Text('Submit Approval'),
                                )
                              else if (status == 'pending_approval')
                                FilledButton(
                                  onPressed: () => _transition(doc.id, 'approved'),
                                  child: const Text('Approve'),
                                )
                              else if (status == 'approved')
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                  onPressed: () => _transition(doc.id, 'live'),
                                  child: const Text('Launch Live'),
                                )
                              else if (status == 'live')
                                OutlinedButton(
                                  onPressed: () => _transition(doc.id, 'ended'),
                                  child: const Text('End Campaign'),
                                ),
                            ],
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
