import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../utils/gst_state_codes.dart';
import '../../../utils/validators.dart';
import '../../providers/client_providers.dart';

/// Add or edit a client. [clientId] is null for "create", non-null for "edit".
class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, required this.clientId});

  final String? clientId;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  String? _stateCode;
  bool _loading = true;
  bool _saving = false;
  Client? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.clientId == null) {
      _loading = false;
    } else {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final c = await ref.read(clientRepositoryProvider).byId(widget.clientId!);
    if (c != null) {
      _existing = c;
      _name.text = c.name;
      _gstin.text = c.gstin ?? '';
      _address.text = c.address ?? '';
      _email.text = c.email ?? '';
      _phone.text = c.phone ?? '';
      _stateCode = c.stateCode;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _gstin, _address, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onGstinChanged(String value) {
    final upper = value.toUpperCase();
    _gstin.value = TextEditingValue(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
    final derived = stateCodeFromGstin(upper);
    if (derived != null) setState(() => _stateCode = derived);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(clientRepositoryProvider);
    if (_existing == null) {
      await repo.create(
        name: _name.text.trim(),
        stateCode: _stateCode!,
        gstin: _gstin.text.trim().isEmpty ? null : _gstin.text.trim().toUpperCase(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );
    } else {
      await repo.update(_existing!.copyWith(
        name: _name.text.trim(),
        stateCode: _stateCode!,
        gstin: Value(_gstin.text.trim().isEmpty ? null : _gstin.text.trim().toUpperCase()),
        address: Value(_address.text.trim().isEmpty ? null : _address.text.trim()),
        email: Value(_email.text.trim().isEmpty ? null : _email.text.trim()),
        phone: Value(_phone.text.trim().isEmpty ? null : _phone.text.trim()),
      ));
    }

    ref.invalidate(clientListProvider);

    if (mounted) {
      setState(() => _saving = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Add client' : 'Edit client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => validateRequired(v, 'Name'),
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _stateCode,
              decoration: const InputDecoration(labelText: 'State *'),
              items: gstStateCodes.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text('${e.value} (${e.key})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _stateCode = v),
              validator: validateStateCode,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _gstin,
              textCapitalization: TextCapitalization.characters,
              onChanged: _onGstinChanged,
              validator: (v) => validateGstin(v, allowEmpty: true),
              decoration: const InputDecoration(
                labelText: 'GSTIN (optional)',
                helperText: 'State auto-derived from GSTIN',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Address (optional)'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    validator: validatePhone,
                    decoration: const InputDecoration(labelText: 'Phone (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: validateEmail,
                    decoration: const InputDecoration(labelText: 'Email (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_existing == null ? 'Add client' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
