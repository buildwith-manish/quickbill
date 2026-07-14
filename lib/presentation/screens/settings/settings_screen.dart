import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/gst_state_codes.dart';
import '../../../utils/validators.dart';
import '../../providers/business_profile_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/invoice_providers.dart';
import '../../widgets/logo_picker.dart';
import 'backup_section.dart';

/// Settings — edit business profile (same fields as onboarding), app info.
/// No login / account section (there is no account).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pan = TextEditingController();
  final _bankAccountName = TextEditingController();
  final _bankAccountNumber = TextEditingController();
  final _bankIfsc = TextEditingController();
  final _upiId = TextEditingController();

  String? _stateCode;
  String? _logoPath;
  bool _isGstRegistered = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await ref.read(businessProfileControllerProvider.future);
    if (p != null) {
      _businessName.text = p.businessName;
      _gstin.text = p.gstin ?? '';
      _address.text = p.address;
      _phone.text = p.phone ?? '';
      _email.text = p.email ?? '';
      _pan.text = p.panNumber ?? '';
      _bankAccountName.text = p.bankAccountName ?? '';
      _bankAccountNumber.text = p.bankAccountNumber ?? '';
      _bankIfsc.text = p.bankIfsc ?? '';
      _upiId.text = p.upiId ?? '';
      _logoPath = p.logoPath;
      _stateCode = p.stateCode;
      _isGstRegistered = p.isGstRegistered;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _businessName,
      _gstin,
      _address,
      _phone,
      _email,
      _pan,
      _bankAccountName,
      _bankAccountNumber,
      _bankIfsc,
      _upiId,
    ]) {
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

    final companion = BusinessProfilesCompanion(
      businessName: Value(_businessName.text.trim()),
      gstin: Value(_isGstRegistered ? _gstin.text.trim().toUpperCase() : null),
      stateCode: Value(_stateCode!),
      address: Value(_address.text.trim()),
      phone: Value(_phone.text.trim().isEmpty ? null : _phone.text.trim()),
      email: Value(_email.text.trim().isEmpty ? null : _email.text.trim()),
      panNumber: Value(
          _pan.text.trim().isEmpty ? null : _pan.text.trim().toUpperCase()),
      bankAccountName: Value(_bankAccountName.text.trim().isEmpty
          ? null
          : _bankAccountName.text.trim()),
      bankAccountNumber: Value(_bankAccountNumber.text.trim().isEmpty
          ? null
          : _bankAccountNumber.text.trim()),
      bankIfsc: Value(_bankIfsc.text.trim().isEmpty
          ? null
          : _bankIfsc.text.trim().toUpperCase()),
      upiId: Value(_upiId.text.trim().isEmpty ? null : _upiId.text.trim()),
      logoPath: Value(_logoPath),
      isGstRegistered: Value(_isGstRegistered),
    );

    await ref
        .read(businessProfileControllerProvider.notifier)
        .saveProfile(companion);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
            'This deletes your business profile, all clients, and all invoices '
            'from this device. Cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Cascade wipe across all 4 tables + seq counters, then refresh
    // providers so the router redirects to onboarding.
    await ref.read(businessProfileRepositoryProvider).wipeAll();
    ref.invalidate(businessProfileControllerProvider);
    ref.invalidate(clientListProvider);
    ref.invalidate(invoiceListProvider);

    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final colors = appColors(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            LogoPicker(
              currentPath: _logoPath,
              onChanged: (p) => setState(() => _logoPath = p),
            ),
            const SizedBox(height: 16),
            _SectionLabel('Business name *'),
            TextFormField(
              controller: _businessName,
              textCapitalization: TextCapitalization.words,
              validator: (v) => validateRequired(v, 'Business name'),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.subtleContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GST registered?',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Toggle off if you are below the ₹20L threshold or under the composition scheme.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isGstRegistered,
                    onChanged: (v) => setState(() => _isGstRegistered = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isGstRegistered) ...[
              _SectionLabel('GSTIN'),
              TextFormField(
                controller: _gstin,
                textCapitalization: TextCapitalization.characters,
                onChanged: _onGstinChanged,
                validator: (v) => validateGstin(v, allowEmpty: false),
              ),
              const SizedBox(height: 16),
              _SectionLabel('PAN (optional)'),
              TextFormField(
                controller: _pan,
                textCapitalization: TextCapitalization.characters,
                validator: validatePan,
              ),
              const SizedBox(height: 16),
            ],

            _SectionLabel('State *'),
            DropdownButtonFormField<String>(
              value: _stateCode,
              items: gstStateCodes.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text('${e.value} (${e.key})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _stateCode = v),
              validator: validateStateCode,
            ),
            const SizedBox(height: 16),

            _SectionLabel('Address'),
            TextFormField(
              controller: _address,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _SectionLabel('Phone')),
                const SizedBox(width: 12),
                Expanded(child: _SectionLabel('Email')),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    validator: validatePhone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: validateEmail,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Payment details
            _SectionHeader(
              icon: Icons.account_balance_outlined,
              title: 'Payment details (optional)',
              subtitle: 'Shown at the bottom of every invoice.',
              colors: colors,
            ),
            const SizedBox(height: 12),
            _SectionLabel('Bank account name'),
            TextFormField(controller: _bankAccountName),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _SectionLabel('Account number')),
                const SizedBox(width: 12),
                Expanded(child: _SectionLabel('IFSC')),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                        controller: _bankAccountNumber,
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bankIfsc,
                    textCapitalization: TextCapitalization.characters,
                    validator: validateIfsc,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionLabel('UPI ID'),
            TextFormField(
              controller: _upiId,
              validator: validateUpi,
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes'),
            ),

            const SizedBox(height: 32),
            const BackupSection(),
            const SizedBox(height: 32),
            _SectionHeader(
              icon: Icons.info_outline,
              title: 'About Invory',
              subtitle:
                  'Invory v1.2.0 • Offline-first • No login, no cloud sync. '
                  'All data is stored on this device only.',
              colors: colors,
            ),
            const SizedBox(height: 16),
            // Disclaimer — required because the app performs GST calculations
            // that affect users' legal/tax compliance. Surfaced in settings
            // (always visible) and once during onboarding (non-blocking banner).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel_outlined,
                          size: 16, color: colors.warning),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.disclaimerTitle,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.disclaimerFull,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _confirmReset,
              icon: Icon(Icons.refresh, color: colors.danger),
              label: Text('Reset all data',
                  style: TextStyle(color: colors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
