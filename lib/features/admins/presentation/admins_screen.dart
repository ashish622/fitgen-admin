import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/admin_api.dart';
import '../../../core/admin_session.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  bool _busy = false;

  static const _availableCapabilities = [
    (Cap.usersRead, 'Read Users & Profiles'),
    (Cap.usersManage, 'Manage Users (Block/Suspend/Coins)'),
    (Cap.studioActivation, 'Partner & Studio Lifecycle (Verify/Activate)'),
    (Cap.plansManage, 'Manage Allowance & Pass Plans'),
    (Cap.featuresManage, 'Feature Flags & Plan Tiers'),
    (Cap.support, 'Support Tickets & Feedback Triage'),
    (Cap.campaignsManage, 'Marketing Campaigns & Challenges'),
    (Cap.analyticsRead, 'Operations Dashboard & KPIs'),
    (Cap.aiConfiguration, 'AI Controls & Quotas'),
    (Cap.adminsManage, 'Super-Admin: Manage Admin Rights'),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openManageAdminDialog([DocumentSnapshot<Map<String, dynamic>>? existing]) async {
    final uidCtl = TextEditingController(text: existing?.id ?? '');
    final reasonCtl = TextEditingController();
    final existingCaps = (existing?.data()?['capabilities'] as List?)?.cast<String>() ?? [];
    final selectedCaps = Set<String>.from(existingCaps);
    String status = existing?.data()?['status'] ?? 'active';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Grant Admin Privileges' : 'Edit Admin Capabilities'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existing == null) ...[
                    TextField(
                      controller: uidCtl,
                      decoration: const InputDecoration(labelText: 'Admin Firebase UID *', hintText: 'Enter user UID'),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Text('Managing UID: ${existing.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Admin Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                      DropdownMenuItem(value: 'revoked', child: Text('Revoked')),
                    ],
                    onChanged: (v) => setS(() => status = v ?? 'active'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Assigned Capabilities:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ..._availableCapabilities.map((cap) {
                    final (id, name) = cap;
                    final has = selectedCaps.contains(id);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(name, style: const TextStyle(fontSize: 13)),
                      value: has,
                      onChanged: (val) {
                        setS(() {
                          if (val == true) {
                            selectedCaps.add(id);
                          } else {
                            selectedCaps.remove(id);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtl,
                    decoration: const InputDecoration(labelText: 'Change Justification / Reason *'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (uidCtl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Save Privileges'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.api.manageAdmin(
        uid: uidCtl.text.trim(),
        capabilities: selectedCaps.toList(),
        status: status,
        reason: reasonCtl.text.trim().isEmpty ? null : reasonCtl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin capabilities updated successfully')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManageAdmins = widget.session.can(Cap.adminsManage);

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
                      Text('Admins & Immutable Audit Log', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Platform authority model, operator capability assignments, and cryptographic audit records.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (canManageAdmins)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _openManageAdminDialog(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Provision Admin'),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.security), text: 'Platform Admins'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Audit Trail (adminAuditLog)'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAdminsTab(canManageAdmins),
                  _buildAuditLogTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsTab(bool canManageAdmins) {
    final stream = Firebase.apps.isEmpty
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance.collection('platformAdmins').snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const EmptyState(
            title: 'No Platform Admins Recorded',
            message: 'Use managePlatformAdmin script to provision the root super-admin.',
            icon: Icons.shield_outlined,
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
              final doc = docs[index];
              final d = doc.data();
              final status = d['status'] ?? 'active';
              final caps = (d['capabilities'] as List?)?.cast<String>() ?? [];
              final isCurrent = doc.id == widget.session.user?.uid;

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.person),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('UID: ${doc.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  const Chip(label: Text('YOU'), visualDensity: VisualDensity.compact),
                                ],
                              ],
                            ),
                            Text('Status: ${status.toUpperCase()}  •  SchemaVersion: ${d['schemaVersion'] ?? 1}'),
                          ],
                        ),
                        const Spacer(),
                        StatusBadge(status),
                        if (canManageAdmins && !isCurrent) ...[
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: () => _openManageAdminDialog(doc),
                            child: const Text('Edit Rights'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: caps.map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      )).toList(),
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

  Widget _buildAuditLogTab() {
    final theme = Theme.of(context);
    final stream = Firebase.apps.isEmpty
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
            .collection('adminAuditLog')
            .orderBy('at', descending: true)
            .limit(100)
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const EmptyState(
            title: 'Audit Log Empty',
            message: 'Administrative operations executed through Cloud Functions will appear here.',
            icon: Icons.history,
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
              final action = d['action'] ?? 'action';
              final actorUid = d['actorUid'] ?? 'unknown';
              final targetType = d['targetType'] ?? 'item';
              final targetId = d['targetId'] ?? '';
              final reason = d['reason'];
              final at = _formatDate(d['at']);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Text('Target: $targetType #$targetId', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(at, style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Actor: $actorUid${reason != null ? "  •  Reason: $reason" : ""}', style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(ts.toDate());
    }
    return ts?.toString() ?? 'N/A';
  }
}
