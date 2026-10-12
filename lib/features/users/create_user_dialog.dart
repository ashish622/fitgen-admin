import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/admin_api.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key, required this.api});
  final AdminApi api;
  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _coins = TextEditingController(text: '0');
  bool _busy = false;
  String? _error;
  String? _inviteLink;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _coins.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await widget.api.createUser(
        email: _email.text.trim(),
        name: _name.text.trim(),
        initialCoins: int.tryParse(_coins.text) ?? 0,
      );
      setState(() => _inviteLink = link);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _inviteLink;
    return AlertDialog(
      title: Text(link == null ? 'Add user' : 'User created'),
      content: SizedBox(
        width: 420,
        child: link != null
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Share this one-time link so the user can set a password:'),
                const SizedBox(height: 8),
                SelectableText(link),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                  controller: _coins,
                  decoration: const InputDecoration(labelText: 'Initial coins'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
              ]),
      ),
      actions: [
        if (link != null)
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: link)),
            child: const Text('Copy link'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(link == null ? 'Cancel' : 'Done'),
        ),
        if (link == null)
          FilledButton(onPressed: _busy ? null : _create, child: const Text('Create')),
      ],
    );
  }
}
