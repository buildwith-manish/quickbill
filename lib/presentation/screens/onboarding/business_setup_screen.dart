import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../domain/services/reminder_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/gst_state_codes.dart';
import '../../../utils/validators.dart';
import '../../providers/business_profile_providers.dart';
import '../../widgets/logo_picker.dart';

/// First-launch onboarding screen. Captures the freelancer's own business
/// profile and persists it as the single row in [BusinessProfiles].
///
/// Required: business name, state. Everything else is optional.
/// A "Not registered under GST" toggle explicitly marks unregistered
/// freelancers — this drives the GST-omission behaviour throughout the app.
class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
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
  bool _disclaimerDismissed = false;
  bool _saving = false;

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
    if (derived != null) {
      setState(() => _stateCode = derived);
    }
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

    // Request notification permission now that onboarding is complete.
    // Fire-and-forget — denial is non-fatal and never blocks the user.
    // We ask here (not on cold start) so the user has context for the
    // request: they've just set up their business and understand why
    // Invory wants to send due-date reminders.
    unawaited(ReminderService.requestPermissions());

    if (mounted) {
      setState(() => _saving = false);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColors(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your business'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Hero / intro
            Icon(Icons.receipt_long,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Tell Invory about your business so invoices carry your details automatically.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Non-blocking disclaimer banner — dismissible, shown once during
            // onboarding. The full disclaimer lives in Settings.
            if (!_disclaimerDismissed)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DisclaimerBanner(
                  onDismiss: () => setState(() => _disclaimerDismissed = true),
                ),
              ),
            const SizedBox(height: 8),

            // Required: business name
            _SectionLabel('Business name *'),
            TextFormField(
              controller: _businessName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => validateRequired(v, 'Business name'),
              decoration: const InputDecoration(
                  hintText: 'e.g. Anjali Sharma Design Studio'),
            ),
            const SizedBox(height: 16),

            // GST registration toggle
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
                        Text(
                          'GST registered?',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Toggle off if you are below the ₹20L threshold or under the composition scheme.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
                textInputAction: TextInputAction.next,
                onChanged: _onGstinChanged,
                validator: (v) => validateGstin(v, allowEmpty: false),
                decoration:
                    const InputDecoration(hintText: '15-character GSTIN'),
              ),
              const SizedBox(height: 16),
              _SectionLabel('PAN (optional)'),
              TextFormField(
                controller: _pan,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                validator: validatePan,
                decoration: const InputDecoration(hintText: 'AAAAA9999A'),
              ),
              const SizedBox(height: 16),
            ],

            // State — required
            _SectionLabel('State *'),
            DropdownButtonFormField<String>(
              value: _stateCode,
              decoration:
                  const InputDecoration(hintText: 'Select your state / UT'),
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
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  hintText: 'Billing address shown on invoices'),
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
                    textInputAction: TextInputAction.next,
                    validator: validatePhone,
                    decoration: const InputDecoration(hintText: '10-digit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: validateEmail,
                    decoration:
                        const InputDecoration(hintText: 'you@example.com'),
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
            TextFormField(
              controller: _bankAccountName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration:
                  const InputDecoration(hintText: 'Name as per bank record'),
            ),
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
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'XXXX1234'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bankIfsc,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    validator: validateIfsc,
                    decoration: const InputDecoration(hintText: 'HDFC0001234'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionLabel('UPI ID'),
            TextFormField(
              controller: _upiId,
              textInputAction: TextInputAction.done,
              validator: validateUpi,
              decoration: const InputDecoration(hintText: 'name@oksbi'),
            ),

            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save & start invoicing'),
            ),

            const SizedBox(height: 28),
            LogoPicker(
              currentPath: _logoPath,
              onChanged: (p) => setState(() => _logoPath = p),
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
              Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dismissible, non-blocking disclaimer banner shown once during onboarding.
/// Tapping the "Got it" button hides it for the rest of the onboarding flow.
/// The full disclaimer text is always available in Settings → About.
class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColors(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.disclaimerTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.disclaimerShort,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.gotIt),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
