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

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.session,
    required this.api,
  });

  final AdminSession session;
  final AdminApi api;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  bool _busy = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openTicketThread(DocumentSnapshot<Map<String, dynamic>> doc) {
    showDialog(
      context: context,
      builder: (_) => _TicketThreadDialog(doc: doc, api: widget.api, session: widget.session),
    );
  }

  Future<void> _banReportedUser(String reportedUid) async {
    final res = await ConfirmDialog.show(
      context,
      title: 'Block Reported User',
      message: 'Take immediate moderation action and block account $reportedUid?',
      confirmLabel: 'Block User',
      requireReason: true,
      reasonHint: 'e.g. Hate speech and harassment reported in ticket',
      isDestructive: true,
    );
    if (res == null || !res.confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.api.setUserStatus(
        uid: reportedUid,
        status: 'blocked',
        reason: res.reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $reportedUid has been blocked')),
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
                    Text('Support & Moderation Hub', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage member support tickets, user abuse reports, and app feedback.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.inbox_outlined), text: 'Support Tickets'),
                Tab(icon: Icon(Icons.report_problem_outlined), text: 'User Abuse Reports'),
                Tab(icon: Icon(Icons.rate_review_outlined), text: 'Feedback & Ratings'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTicketsTab(),
                  _buildReportsTab(),
                  _buildFeedbackTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsTab() {
    final theme = Theme.of(context);
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('supportTickets');
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar
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
                Text('Status: ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Tickets')),
                    DropdownMenuItem(value: 'open', child: Text('Open Only')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _statusFilter = v);
                  },
                ),
                const SizedBox(width: 24),
                Text('Category: ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _typeFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(value: 'bug', child: Text('Bug')),
                    DropdownMenuItem(value: 'account', child: Text('Account')),
                    DropdownMenuItem(value: 'payment', child: Text('Payment')),
                    DropdownMenuItem(value: 'report_user', child: Text('User Abuse Report')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _typeFilter = v);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs.where((d) {
                final type = d.data()['type'] ?? '';
                return _typeFilter == 'all' || type == _typeFilter;
              }).toList();

              if (docs.isEmpty) {
                return const EmptyState(
                  title: 'No Tickets In Queue',
                  message: 'No support requests match the current filters.',
                  icon: Icons.mark_email_read_outlined,
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
                    final subject = d['subject'] ?? 'No Subject';
                    final type = d['type'] ?? 'support';
                    final status = d['status'] ?? 'open';
                    final priority = d['priority'] ?? 'normal';
                    final uid = d['uid'] ?? 'N/A';
                    final created = _formatDate(d['createdAt']);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: status == 'open' ? Colors.amber.shade100 : Colors.grey.shade200,
                        child: Icon(
                          type == 'report_user' ? Icons.report_problem : Icons.help_outline,
                          color: status == 'open' ? Colors.amber.shade900 : Colors.grey.shade700,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          StatusBadge(status),
                          const SizedBox(width: 8),
                          Chip(label: Text(type.toUpperCase()), visualDensity: VisualDensity.compact),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'ID: ${doc.id}  •  User: $uid  •  Priority: $priority  •  $created',
                          style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                        ),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => _openTicketThread(doc),
                        child: const Text('View & Reply'),
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

  Widget _buildReportsTab() {
    final theme = Theme.of(context);
    final reportsQuery = FirebaseFirestore.instance
        .collection('supportTickets')
        .where('type', isEqualTo: 'report_user');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: reportsQuery.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const EmptyState(
            title: 'No User Abuse Reports',
            message: 'All community behavior reports are cleared.',
            icon: Icons.verified_user_outlined,
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
              final reporterUid = d['uid'] ?? 'N/A';
              final reportedUid = d['reportedUid'] ?? 'N/A';
              final subject = d['subject'] ?? 'User Report';
              final body = d['body'] ?? '';
              final status = d['status'] ?? 'open';

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 10),
                        Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 12),
                        StatusBadge(status),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.person),
                          label: const Text('View Profile'),
                          onPressed: () => context.go('/users/$reportedUid'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                          icon: const Icon(Icons.block),
                          label: const Text('Block Reported User'),
                          onPressed: _busy ? null : () => _banReportedUser(reportedUid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reported User UID: $reportedUid  •  Filed by: $reporterUid  •  Date: ${_formatDate(d['createdAt'])}',
                      style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(body, style: const TextStyle(fontSize: 14, height: 1.4)),
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

  Widget _buildFeedbackTab() {
    final theme = Theme.of(context);
    final feedbackQuery = FirebaseFirestore.instance.collection('feedback').limit(100);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: feedbackQuery.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const EmptyState(
            title: 'No Feedback Received',
            message: 'Feedback submissions will appear here.',
            icon: Icons.reviews_outlined,
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
              final rating = (d['rating'] as num?)?.toInt() ?? 5;
              final msg = d['message'] ?? '(no comments)';
              final screen = d['screen'] ?? 'General';
              final status = d['status'] ?? 'new';
              final uid = d['uid'] ?? 'N/A';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$rating', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                  ],
                ),
                title: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('User: $uid  •  Screen: $screen  •  Status: $status'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(status),
                    const SizedBox(width: 12),
                    if (status != 'actioned')
                      FilledButton.tonal(
                        onPressed: () => widget.api.updateFeedback(feedbackId: doc.id, status: 'actioned'),
                        child: const Text('Mark Actioned'),
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

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMd().format(ts.toDate());
    }
    return ts?.toString() ?? 'N/A';
  }
}

class _TicketThreadDialog extends StatefulWidget {
  const _TicketThreadDialog({
    required this.doc,
    required this.api,
    required this.session,
  });

  final DocumentSnapshot<Map<String, dynamic>> doc;
  final AdminApi api;
  final AdminSession session;

  @override
  State<_TicketThreadDialog> createState() => _TicketThreadDialogState();
}

class _TicketThreadDialogState extends State<_TicketThreadDialog> {
  final _replyCtl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _replyCtl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtl.text.trim();
    if (text.isEmpty) return;

    setState(() => _busy = true);
    try {
      await widget.api.replyTicket(ticketId: widget.doc.id, body: text);
      _replyCtl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply posted successfully')),
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
    final d = widget.doc.data() ?? {};
    final subject = d['subject'] ?? 'Support Ticket';
    final status = d['status'] ?? 'open';
    final priority = d['priority'] ?? 'normal';
    final messagesRef = widget.doc.reference.collection('messages').orderBy('createdAt');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('Ticket #${widget.doc.id}  •  Priority: $priority'),
                      ],
                    ),
                  ),
                  StatusBadge(status),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),
              // Original ticket body
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(d['body'] ?? 'No description supplied', style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 16),
              const Text('Discussion Thread', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),

              // Messages Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: messagesRef.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final msgs = snap.data!.docs;

                    if (msgs.isEmpty) {
                      return const Center(
                        child: Text('No replies posted yet. Send the first response below.', style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      itemCount: msgs.length,
                      itemBuilder: (context, index) {
                        final m = msgs[index].data();
                        final isAdmin = m['senderRole'] == 'admin';
                        return Align(
                          alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isAdmin ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(isAdmin ? 'Admin' : 'User', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(m['body'] ?? ''),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 24),
              // Reply Box
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtl,
                      decoration: const InputDecoration(
                        hintText: 'Type reply to user...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _sendReply,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Reply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
