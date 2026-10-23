import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/admin_api.dart';
import '../../../core/admin_session.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class PartnerDetailScreen extends StatefulWidget {
  const PartnerDetailScreen({
    super.key,
    required this.partnerId,
    required this.session,
    required this.api,
  });

  final String partnerId;
  final AdminSession session;
  final AdminApi api;

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 5, vsync: this);
  bool _busy = false;
  Map<String, dynamic>? _readinessData;
  bool _loadingReadiness = false;
  String? _readinessError;

  @override
  void initState() {
    super.initState();
    _fetchReadiness();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReadiness() async {
    setState(() {
      _loadingReadiness = true;
      _readinessError = null;
    });
    try {
      final res = await widget.api.getStudioReadiness(partnerId: widget.partnerId);
      setState(() => _readinessData = res);
    } catch (e) {
      setState(() => _readinessError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingReadiness = false);
    }
  }

  Future<void> _transitionStatus(String targetStatus, {String? defaultReason}) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Transition to ${targetStatus.toUpperCase()}',
      message: 'Are you sure you want to change this studio\'s status to $targetStatus?',
      confirmLabel: 'Confirm Change',
      requireReason: targetStatus != 'active',
      isDestructive: targetStatus == 'suspended' || targetStatus == 'archived',
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.setStudioLifecycleStatus(
        partnerId: widget.partnerId,
        targetStatus: targetStatus,
        reason: res.reason.isNotEmpty ? res.reason : defaultReason,
        attestations: targetStatus == 'active'
            ? {
                'verifiedAccessProtectionAcknowledged': true,
                'noRollbackPolicyAcknowledged': true,
              }
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status transitioned to $targetStatus')),
        );
        _fetchReadiness();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Action Refused'),
            content: Text(e.message ?? e.code),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
            ],
          ),
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

  Future<void> _recordVerification() async {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final notesCtl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Identity Verification'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Record official verification of the studio operator credentials:'),
              const SizedBox(height: 12),
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Operator Name *')),
              TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Operator Email')),
              TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'Operator Phone')),
              TextField(controller: notesCtl, decoration: const InputDecoration(labelText: 'Verification Notes / ID Reference'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Confirm Verification'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.api.recordStudioIdentityVerification(
        partnerId: widget.partnerId,
        verified: true,
        operatorName: nameCtl.text.trim(),
        operatorEmail: emailCtl.text.trim().isEmpty ? null : emailCtl.text.trim(),
        operatorPhone: phoneCtl.text.trim().isEmpty ? null : phoneCtl.text.trim(),
        notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identity verification recorded successfully')),
        );
        _fetchReadiness();
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
    final canManage = widget.session.can(Cap.studioActivation);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('partners').doc(widget.partnerId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const EmptyState(title: 'Studio Not Found', message: 'The requested partner does not exist.'),
          );
        }

        final name = (data['name'] as String?) ?? '(unnamed)';
        final status = (data['status'] as String?) ?? 'pending_verification';

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation and Actions Bar
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/partners'),
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
                        Text('Studio ID: ${widget.partnerId}', style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    if (canManage && !_busy) ..._buildActionButtons(status),
                    if (_busy) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 20),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.info_outline), text: 'Overview & Location'),
                    Tab(icon: Icon(Icons.fact_check_outlined), text: 'Readiness & Verification'),
                    Tab(icon: Icon(Icons.fitness_center), text: 'Class Types & Schedule'),
                    Tab(icon: Icon(Icons.badge_outlined), text: 'Instructors & Staff'),
                    Tab(icon: Icon(Icons.policy_outlined), text: 'Policy & Access Config'),
                  ],
                ),
                const SizedBox(height: 16),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(data),
                      _buildReadinessTab(status),
                      _buildClassesTab(),
                      _buildInstructorsTab(),
                      _buildPolicyTab(),
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

  List<Widget> _buildActionButtons(String status) {
    return [
      if (status == 'pending_verification') ...[
        OutlinedButton.icon(
          icon: const Icon(Icons.verified_user),
          label: const Text('Verify Identity'),
          onPressed: _recordVerification,
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text('Activate Studio'),
          onPressed: () => _transitionStatus('active', defaultReason: 'Identity and terms verified.'),
        ),
      ] else if (status == 'active') ...[
        OutlinedButton.icon(
          icon: const Icon(Icons.pause),
          label: const Text('Pause Bookings'),
          onPressed: () => _transitionStatus('paused'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          icon: const Icon(Icons.block),
          label: const Text('Suspend'),
          onPressed: () => _transitionStatus('suspended'),
        ),
      ] else if (status == 'paused') ...[
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume Studio'),
          onPressed: () => _transitionStatus('active', defaultReason: 'Operator resumed bookings.'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          icon: const Icon(Icons.block),
          label: const Text('Suspend'),
          onPressed: () => _transitionStatus('suspended'),
        ),
      ] else if (status == 'suspended') ...[
        FilledButton.icon(
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reinstate Studio'),
          onPressed: () => _transitionStatus('active', defaultReason: 'Suspension lifted by platform admin.'),
        ),
      ],
    ];
  }

  Widget _buildOverviewTab(Map<String, dynamic> data) {
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
                Text('Studio Profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                _infoRow('Studio Name', data['name']),
                _infoRow('Slug', data['slug'] ?? 'N/A'),
                _infoRow('Timezone', data['timezone']),
                _infoRow('Country', data['country']),
                _infoRow('Contact Phone', data['phone'] ?? 'None'),
                _infoRow('Contact Email', data['email'] ?? 'None'),
                _infoRow('Owner UID', data['ownerUid'] ?? 'None'),
                _infoRow('Created At', _formatDate(data['createdAt'])),
                _infoRow('Last Updated', _formatDate(data['updatedAt'])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Primary Location
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('partners')
              .doc(widget.partnerId)
              .collection('locations')
              .doc('primary')
              .snapshots(),
          builder: (context, snap) {
            final loc = snap.data?.data();
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
                    Text('Primary Location', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    if (loc == null)
                      const Text('No primary location document registered.')
                    else ...[
                      _infoRow('Address', loc['address'] ?? 'N/A'),
                      _infoRow('City', loc['city'] ?? 'N/A'),
                      _infoRow('State / Postal', '${loc['state'] ?? ''} ${loc['postalCode'] ?? ''}'.trim()),
                      _infoRow('Geohash', loc['geohash'] ?? 'N/A'),
                      _infoRow('Coordinates', '${loc['latitude'] ?? 'N/A'}, ${loc['longitude'] ?? 'N/A'}'),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReadinessTab(String status) {
    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Server Readiness Evaluation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            FilledButton.tonalIcon(
              onPressed: _loadingReadiness ? null : _fetchReadiness,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Re-evaluate'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingReadiness)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (_readinessError != null)
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Readiness Check Error: $_readinessError', style: TextStyle(color: Colors.red.shade800)),
            ),
          )
        else if (_readinessData != null)
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
                  Row(
                    children: [
                      Icon(
                        _readinessData!['ready'] == true ? Icons.check_circle : Icons.warning_amber,
                        color: _readinessData!['ready'] == true ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _readinessData!['ready'] == true ? 'Studio is Activation Ready' : 'Activation Blockers Detected',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text('Status: $status', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  if (_readinessData!['checklist'] is Map)
                    ...(_readinessData!['checklist'] as Map).entries.map((e) {
                      final ok = e.value == true;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(ok ? Icons.check : Icons.close, color: ok ? Colors.green : Colors.red, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(e.key.toString())),
                            Text(ok ? 'PASS' : 'FAIL', style: TextStyle(color: ok ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClassesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class Types', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('partners')
                .doc(widget.partnerId)
                .collection('classTypes')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const EmptyState(
                  title: 'No Class Types',
                  message: 'This studio has not configured any class types yet.',
                  icon: Icons.fitness_center,
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final ct = docs[index].data();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(ct['name'] ?? '(unnamed)'),
                      subtitle: Text('Capacity: ${ct['capacity'] ?? 'N/A'}  •  Duration: ${ct['durationMinutes'] ?? 'N/A'} min'),
                      trailing: Text('ID: ${docs[index].id}', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
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

  Widget _buildInstructorsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructors & Staff Memberships', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('partners')
                .doc(widget.partnerId)
                .collection('instructors')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const EmptyState(
                  title: 'No Instructors Listed',
                  message: 'No instructors found in partners/{id}/instructors.',
                  icon: Icons.badge_outlined,
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final inst = docs[index].data();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(inst['name'] ?? '(unnamed)'),
                      subtitle: Text('${inst['email'] ?? ''}  •  Role: ${inst['role'] ?? 'instructor'}'),
                      trailing: StatusBadge(inst['active'] == false ? 'suspended' : 'active'),
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

  Widget _buildPolicyTab() {
    return ListView(
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('partners')
              .doc(widget.partnerId)
              .collection('policy')
              .doc('default')
              .snapshots(),
          builder: (context, snap) {
            final pol = snap.data?.data();
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
                    Text('Cancellation & Booking Policy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    if (pol == null)
                      const Text('Default policy doc not configured.')
                    else ...[
                      _infoRow('Cancellation Cutoff', '${pol['cancellationCutoffMinutes'] ?? 'N/A'} minutes'),
                      _infoRow('Max Advance Booking Days', '${pol['maxAdvanceBookingDays'] ?? 'N/A'} days'),
                      _infoRow('Late Cancellation Fee', '\$${pol['lateCancellationFeeCents'] != null ? (pol['lateCancellationFeeCents'] / 100).toStringAsFixed(2) : '0.00'}'),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('partners')
              .doc(widget.partnerId)
              .collection('accessConfig')
              .doc('default')
              .snapshots(),
          builder: (context, snap) {
            final acc = snap.data?.data();
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
                    Text('Access Configuration', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    if (acc == null)
                      const Text('Access config doc not present.')
                    else ...[
                      _infoRow('Lifecycle Status', acc['lifecycleStatus'] ?? 'N/A'),
                      _infoRow('Verified Access Enforced', acc['verifiedAccessEnforced']?.toString() ?? 'false'),
                      _infoRow('Booking Paused', acc['bookingPaused']?.toString() ?? 'false'),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'None',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
    }
    return timestamp?.toString() ?? 'N/A';
  }
}
