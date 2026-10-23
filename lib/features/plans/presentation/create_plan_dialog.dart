import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/admin_api.dart';

class CreatePlanDialog extends StatefulWidget {
  const CreatePlanDialog({
    super.key,
    required this.api,
    this.initialPartnerId,
    this.firestore,
  });

  final AdminApi api;
  final String? initialPartnerId;
  final FirebaseFirestore? firestore;

  @override
  State<CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends State<CreatePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _planIdController = TextEditingController();
  final _customAllowanceController = TextEditingController(text: '8');
  final _maxCarryController = TextEditingController(text: '4');

  String? _selectedPartnerId;
  String _allowanceType = '8'; // '4', '8', '12', 'custom', 'unlimited'
  bool _rolloverEnabled = false;
  bool _allClassTypes = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPartnerId = widget.initialPartnerId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _planIdController.dispose();
    _customAllowanceController.dispose();
    _maxCarryController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_planIdController.text.isEmpty ||
        _planIdController.text == _generateSlug(_nameController.text)) {
      _planIdController.text = _generateSlug(val);
    }
  }

  String _generateSlug(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartnerId == null) {
      setState(() => _error = 'Please select a Partner Studio.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    dynamic allowance;
    if (_allowanceType == 'unlimited') {
      allowance = 'unlimited';
    } else if (_allowanceType == 'custom') {
      allowance = int.tryParse(_customAllowanceController.text.trim()) ?? 8;
    } else {
      allowance = int.parse(_allowanceType);
    }

    try {
      await widget.api.createPartnerPlan(
        partnerId: _selectedPartnerId!,
        planId: _planIdController.text.trim(),
        name: _nameController.text.trim(),
        allowance: allowance,
        allClassTypes: _allClassTypes,
        rolloverEnabled: _allowanceType != 'unlimited' && _rolloverEnabled,
        maxCarry: _rolloverEnabled
            ? (int.tryParse(_maxCarryController.text.trim()) ?? 4)
            : 0,
      );

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _partnersStream {
    if (Firebase.apps.isEmpty) {
      return const Stream.empty();
    }
    return (widget.firestore ?? FirebaseFirestore.instance)
        .collection('partners')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create Studio Allowance Plan'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // Studio Selector
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _partnersStream,
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedPartnerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Partner Studio *',
                        hintText: 'Select studio',
                      ),
                      items: docs.map((d) {
                        final data = d.data();
                        final name = data['name'] ?? d.id;
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text('$name (${d.id})'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedPartnerId = v),
                      validator: (v) => v == null ? 'Studio is required' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Plan Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Plan Name *',
                    hintText: 'e.g. Monthly 8-Class Allowance',
                  ),
                  onChanged: _onNameChanged,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Plan name is required' : null,
                ),
                const SizedBox(height: 12),

                // Plan ID
                TextFormField(
                  controller: _planIdController,
                  decoration: const InputDecoration(
                    labelText: 'Plan ID (slug) *',
                    hintText: 'monthly-8-pass',
                    helperText: 'Unique, lowercase letters, numbers, and dashes.',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Plan ID is required';
                    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,39}$').hasMatch(v.trim())) {
                      return 'Must be 1-40 lowercase letters, numbers, -, or _';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Allowance
                Text('Monthly Visit Allowance', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('4 Visits'),
                      selected: _allowanceType == '4',
                      onSelected: (_) => setState(() => _allowanceType = '4'),
                    ),
                    ChoiceChip(
                      label: const Text('8 Visits'),
                      selected: _allowanceType == '8',
                      onSelected: (_) => setState(() => _allowanceType = '8'),
                    ),
                    ChoiceChip(
                      label: const Text('12 Visits'),
                      selected: _allowanceType == '12',
                      onSelected: (_) => setState(() => _allowanceType = '12'),
                    ),
                    ChoiceChip(
                      label: const Text('Unlimited'),
                      selected: _allowanceType == 'unlimited',
                      onSelected: (_) => setState(() {
                        _allowanceType = 'unlimited';
                        _rolloverEnabled = false;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Custom'),
                      selected: _allowanceType == 'custom',
                      onSelected: (_) => setState(() => _allowanceType = 'custom'),
                    ),
                  ],
                ),
                if (_allowanceType == 'custom') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customAllowanceController,
                    decoration: const InputDecoration(labelText: 'Custom Visit Count'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 100) return 'Must be between 1 and 100';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Rollover Setting
                if (_allowanceType != 'unlimited') ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow Rollover to Next Period'),
                    subtitle: const Text('Unused visits carry over up to a maximum cap.'),
                    value: _rolloverEnabled,
                    onChanged: (v) => setState(() => _rolloverEnabled = v),
                  ),
                  if (_rolloverEnabled) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _maxCarryController,
                      decoration: const InputDecoration(
                        labelText: 'Max Carryover Visits',
                        hintText: 'e.g. 4',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 100) return 'Must be between 1 and 100';
                        return null;
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 12),

                // Scope
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Eligible for All Class Types'),
                  subtitle: const Text('Applies to all current and future classes at this studio.'),
                  value: _allClassTypes,
                  onChanged: (v) => setState(() => _allClassTypes = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create Plan'),
        ),
      ],
    );
  }
}
