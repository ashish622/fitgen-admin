import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.status, {
    super.key,
    this.customLabel,
  });

  final String status;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().trim();
    final (Color color, String label) = switch (s) {
      'active' || 'live' || 'resolved' || 'verified' || 'approved' => (
        Colors.green,
        customLabel ?? status.toUpperCase()
      ),
      'pending' ||
      'pending_approval' ||
      'pending_verification' ||
      'waiting' ||
      'in_progress' ||
      'open' => (
        Colors.amber.shade800,
        customLabel ?? status.replaceAll('_', ' ').toUpperCase()
      ),
      'suspended' || 'paused' || 'draft' => (
        Colors.orange.shade800,
        customLabel ?? status.toUpperCase()
      ),
      'blocked' || 'rejected' || 'closed' || 'revoked' || 'failed' => (
        Colors.red.shade700,
        customLabel ?? status.toUpperCase()
      ),
      _ => (Colors.grey.shade700, customLabel ?? status.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
