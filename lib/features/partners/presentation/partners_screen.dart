import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/admin_api.dart';
import '../../../core/admin_session.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import 'create_partner_dialog.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreatePartnerDialog(api: widget.api),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Studio onboarded successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = widget.session.can(Cap.studioActivation);

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('partners');
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

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
                    Text('Partners & Studios', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage fitness studios, readiness evaluations, locations, and booking lifecycle.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const Spacer(),
                if (canManage)
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Onboard Studio'),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter bar
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
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search studio by name or ID...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('Status: ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _statusFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'pending_verification', child: Text('Pending Verification')),
                        DropdownMenuItem(value: 'paused', child: Text('Paused')),
                        DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                        DropdownMenuItem(value: 'archived', child: Text('Archived')),
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

            // Data Stream
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error loading partners: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snap.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data();
                      final name = (data['name'] as String? ?? '').toLowerCase();
                      final id = d.id.toLowerCase();
                      return name.contains(_searchQuery) || id.contains(_searchQuery);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const EmptyState(
                      title: 'No Partner Studios Found',
                      message: 'Try adjusting your search criteria or onboard a new studio.',
                      icon: Icons.storefront_outlined,
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
                        final name = (d['name'] as String?) ?? '(unnamed)';
                        final status = (d['status'] as String?) ?? 'pending_verification';
                        final tz = (d['timezone'] as String?) ?? 'Not set';
                        final country = (d['country'] as String?) ?? '';
                        final email = (d['email'] as String?) ?? '';
                        final phone = (d['phone'] as String?) ?? '';

                        String createdDate = '';
                        if (d['createdAt'] is Timestamp) {
                          createdDate = DateFormat.yMMMd().format((d['createdAt'] as Timestamp).toDate());
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.primary,
                            child: const Icon(Icons.storefront, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 10),
                              StatusBadge(status),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'ID: ${doc.id}  •  TZ: $tz  •  Country: $country${email.isNotEmpty ? "  •  $email" : ""}${phone.isNotEmpty ? "  •  $phone" : ""}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (createdDate.isNotEmpty) ...[
                                Text('Created $createdDate', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                                const SizedBox(width: 16),
                              ],
                              FilledButton.tonal(
                                onPressed: () => context.go('/partners/${doc.id}'),
                                child: const Text('Manage'),
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
