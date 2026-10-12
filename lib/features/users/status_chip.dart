import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'blocked' => Colors.red,
      'suspended' => Colors.orange,
      _ => Colors.green,
    };
    return Chip(
      label: Text(status),
      labelStyle: TextStyle(color: color.shade800),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
