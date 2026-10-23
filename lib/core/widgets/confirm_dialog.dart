import 'package:flutter/material.dart';

class ConfirmDialog extends StatefulWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.requireReason = false,
    this.reasonLabel = 'Reason (required)',
    this.reasonHint = 'Explain why this action is being taken...',
    this.extraFields,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final bool requireReason;
  final String reasonLabel;
  final String reasonHint;
  final List<Widget>? extraFields;

  static Future<({bool confirmed, String reason})?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    bool requireReason = false,
    String reasonLabel = 'Reason (required)',
    String reasonHint = 'Explain why this action is being taken...',
    List<Widget>? extraFields,
  }) {
    return showDialog<({bool confirmed, String reason})>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        requireReason: requireReason,
        reasonLabel: reasonLabel,
        reasonHint: reasonHint,
        extraFields: extraFields,
      ),
    );
  }

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message, style: Theme.of(context).textTheme.bodyMedium),
              if (widget.extraFields != null) ...[
                const SizedBox(height: 16),
                ...widget.extraFields!,
              ],
              if (widget.requireReason) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: widget.reasonLabel,
                    hintText: widget.reasonHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'A reason is required for administrative audit.';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: widget.isDestructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
              : null,
          onPressed: () {
            if (widget.requireReason && !_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop((
              confirmed: true,
              reason: _reasonController.text.trim(),
            ));
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
