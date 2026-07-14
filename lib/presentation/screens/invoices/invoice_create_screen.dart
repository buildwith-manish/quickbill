import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../domain/models/gst_calculation.dart';
import '../../../domain/services/gst_service.dart';
import '../../../utils/gst_state_codes.dart';
import '../../providers/business_profile_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/invoice_providers.dart';
import '../../widgets/gst_summary_card.dart';

/// Create or edit an invoice. [invoiceId] is null for "create", non-null
/// for "edit".
class InvoiceCreateScreen extends ConsumerStatefulWidget {
  const InvoiceCreateScreen({super.key, required this.invoiceId});

  final String? invoiceId;

  @override
  ConsumerState<InvoiceCreateScreen> createState() =>
      _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _clientId;
  Client? _selectedClient;
  List<Client> _clients = const [];

  late DateTime _issueDate;
  DateTime? _dueDate;

  final _invoiceNumber = TextEditingController();
  final _notes = TextEditingController();
  final _discountController = TextEditingController();
  final _amountPaidController = TextEditingController();

  final List<_ItemRow> _items = [];
  String? _placeOfSupplyOverride;

  /// v3: discount state — 'flat' (₹) or 'percent' (%).
  String _discountType = 'flat';

  /// v3: quotation toggle. When true, saves with documentType='quotation'
  /// and uses the QTN/ number prefix.
  bool _isQuotation = false;

  bool _loading = true;
  bool _saving = false;
  bool _isEdit = false;
  BusinessProfile? _business;

  static const List<double> _gstRates = [0, 5, 12, 18, 28];

  @override
  void initState() {
    super.initState();
    _issueDate = DateTime.now();
    if (widget.invoiceId == null) {
      _loading = false;
      _items.add(_ItemRow());
    } else {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(invoiceRepositoryProvider);
    final inv = await repo.byId(widget.invoiceId!);
    if (inv == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _isEdit = true;
    _invoiceNumber.text = inv.invoiceNumber;
    _issueDate = inv.issueDate;
    _dueDate = inv.dueDate;
    _notes.text = inv.notes ?? '';
    _placeOfSupplyOverride = inv.placeOfSupply;
    _clientId = inv.clientId;
    _discountType = inv.discountType;
    if (inv.discountValue > 0) {
      _discountController.text = inv.discountValue.toStringAsFixed(
          inv.discountType == 'percent' ? 0 : 2);
    }
    if (inv.amountPaid > 0) {
      _amountPaidController.text = inv.amountPaid.toStringAsFixed(2);
    }
    _isQuotation = inv.documentType == 'quotation';
    final items = await repo.itemsFor(inv.id);
    _items
      ..clear()
      ..addAll(items.map((i) => _ItemRow.fromItem(i)));

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _notes.dispose();
    _discountController.dispose();
    _amountPaidController.dispose();
    for (final r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  /// Removes a line item with an undo snackbar. Doesn't dispose the row's
  /// controllers until the snackbar dismisses without being tapped — that
  /// way an undo reuses the same controllers and the user's input survives.
  void _removeItem(int index, _ItemRow row) {
    setState(() => _items.removeAt(index));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Line item removed'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _items.insert(index.clamp(0, _items.length), row);
            });
          },
        ),
      ));
  }

  Future<void> _pickIssueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _issueDate = d);
  }

  Future<void> _pickDueDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _issueDate.add(const Duration(days: 15)),
      firstDate: _issueDate,
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<void> _save({required String status}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }
    if (_items.every((r) =>
        r.description.text.trim().isEmpty && r.unitPrice.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Pre-fill invoice number if empty — use QTN/ prefix for quotations.
      if (_invoiceNumber.text.trim().isEmpty) {
        final prefix = _isQuotation ? 'QTN' : 'INV';
        final next = await ref.read(invoiceNumberServiceProvider).nextNumber(prefix: prefix);
        _invoiceNumber.text = next;
      }

      final inputs = _items
          .where((r) => r.description.text.trim().isNotEmpty)
          .map((r) => InvoiceItemInput(
                id: r.id,
                description: r.description.text.trim(),
                hsnSacCode:
                    r.hsn.text.trim().isEmpty ? null : r.hsn.text.trim(),
                quantity: double.tryParse(r.qty.text) ?? 1,
                unitPrice: double.tryParse(r.unitPrice.text) ?? 0,
                gstRatePercent: r.gstRate,
              ))
          .toList();

      final sellerState = _business!.stateCode;
      final placeOfSupply =
          _placeOfSupplyOverride ?? _selectedClient!.stateCode;
      final isUnregistered = !_business!.isGstRegistered;

      // For unregistered sellers, force 0% GST per item.
      final effectiveInputs = isUnregistered
          ? inputs
              .map((i) => InvoiceItemInput(
                    id: i.id,
                    description: i.description,
                    hsnSacCode: i.hsnSacCode,
                    quantity: i.quantity,
                    unitPrice: i.unitPrice,
                    gstRatePercent: 0,
                  ))
              .toList()
          : inputs;

      // v3: build discount input from the form state.
      final discountValue = double.tryParse(_discountController.text) ?? 0;
      final discount = discountValue > 0
          ? DiscountInput(
              type: _discountType == 'percent'
                  ? DiscountType.percent
                  : DiscountType.flat,
              value: discountValue,
            )
          : null;

      final calc = calculateInvoiceGst(
        items: effectiveInputs,
        sellerStateCode: sellerState,
        placeOfSupplyStateCode: placeOfSupply,
        discount: discount,
      );

      // v3: amount paid — supports partial payment tracking.
      final amountPaid = double.tryParse(_amountPaidController.text) ?? 0;
      // Auto-derive status from payment: if fully paid, override to 'paid'.
      final effectiveStatus = amountPaid >= calc.total && amountPaid > 0
          ? 'paid'
          : (amountPaid > 0 ? 'partially_paid' : status);

      final documentType = _isQuotation ? 'quotation' : 'invoice';

      final repo = ref.read(invoiceRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          id: widget.invoiceId!,
          invoiceNumber: _invoiceNumber.text.trim(),
          clientId: _clientId!,
          issueDate: _issueDate,
          dueDate: _dueDate,
          status: effectiveStatus,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          placeOfSupply: placeOfSupply,
          subtotal: calc.subtotal,
          cgstAmount: calc.cgst,
          sgstAmount: calc.sgst,
          igstAmount: calc.igst,
          totalAmount: calc.total,
          items: effectiveInputs,
          discountType: _discountType,
          discountValue: discountValue,
          discountAmount: calc.discountAmount,
          amountPaid: amountPaid,
          documentType: documentType,
        );
      } else {
        final saved = await repo.create(
          invoiceNumber: _invoiceNumber.text.trim(),
          clientId: _clientId!,
          issueDate: _issueDate,
          dueDate: _dueDate,
          status: effectiveStatus,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          placeOfSupply: placeOfSupply,
          subtotal: calc.subtotal,
          cgstAmount: calc.cgst,
          sgstAmount: calc.sgst,
          igstAmount: calc.igst,
          totalAmount: calc.total,
          items: effectiveInputs,
          discountType: _discountType,
          discountValue: discountValue,
          discountAmount: calc.discountAmount,
          amountPaid: amountPaid,
          documentType: documentType,
        );
        // After create, jump to the preview.
        if (mounted) {
          ref.invalidate(invoiceListProvider);
          // Schedule a reminder 1 day before due date (if set, invoices only).
          if (saved.invoice.dueDate != null && !_isQuotation) {
            try {
              await ref
                  .read(reminderServiceProvider)
                  .scheduleFor(saved.invoice);
            } catch (_) {}
          }
          setState(() => _saving = false);
          context.go('/invoices/${saved.invoice.id}/preview');
          return;
        }
      }

      ref.invalidate(invoiceListProvider);
      if (mounted) {
        setState(() => _saving = false);
        context.pop();
      }
    } catch (e) {
      // Never leave the loading spinner on after a failure.
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(businessProfileControllerProvider);
    final clientsAsync = ref.watch(clientListProvider);
    final nextNumberAsync = ref.watch(nextInvoiceNumberProvider);

    // Pre-fill invoice number on first create.
    if (!_isEdit && _invoiceNumber.text.isEmpty) {
      final next = nextNumberAsync.valueOrNull;
      if (next != null && next.isNotEmpty) {
        _invoiceNumber.text = next;
      }
    }

    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Profile load error: $e'))),
      data: (profile) {
        _business = profile;
        return clientsAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              Scaffold(body: Center(child: Text('Clients load error: $e'))),
          data: (clients) {
            _clients = clients;
            if (_clientId != null && _selectedClient == null) {
              _selectedClient =
                  _clients.where((c) => c.id == _clientId).firstOrNull;
            }
            return _buildScaffold(context, profile!, clients);
          },
        );
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, BusinessProfile business, List<Client> clients) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isUnregistered = !business.isGstRegistered;
    final sellerState = business.stateCode;
    final placeOfSupply =
        _placeOfSupplyOverride ?? _selectedClient?.stateCode ?? sellerState;
    final calc = _recalculate(
      sellerState: sellerState,
      placeOfSupply: placeOfSupply,
      isUnregistered: isUnregistered,
    );
    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? (_isQuotation ? 'Edit quotation' : 'Edit invoice')
            : (_isQuotation ? 'New quotation' : 'New invoice')),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(status: 'draft'),
            child: const Text('Save draft'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            // ---- Quotation / Invoice toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isQuotation = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isQuotation
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Invoice',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !_isQuotation
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isQuotation = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isQuotation
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Quotation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isQuotation
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isQuotation)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(
                  'Quotations use a QTN/ number prefix. Convert to an invoice '
                  'later from the preview screen.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // ---- Client + dates block
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _clientId,
                      decoration: const InputDecoration(labelText: 'Client *'),
                      items: clients
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.name}'
                                  '${c.gstin != null && c.gstin!.isNotEmpty ? '  •  ${c.gstin}' : ''}',
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _clientId = v;
                          _selectedClient =
                              clients.where((c) => c.id == v).firstOrNull;
                          // Reset override — client changed.
                          _placeOfSupplyOverride = null;
                        });
                      },
                      validator: (v) => v == null ? 'Select a client' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => context.push('/clients/new'),
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text('Quick add client'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedClient != null) ...[
                      // Place of supply override
                      DropdownButtonFormField<String>(
                        value: placeOfSupply,
                        decoration: const InputDecoration(
                          labelText: 'Place of supply',
                          helperText: 'Defaults to client\'s state',
                        ),
                        items: gstStateCodes.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text('${e.value} (${e.key})'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _placeOfSupplyOverride = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Issue date',
                            value: _issueDate,
                            onTap: _pickIssueDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Due date (optional)',
                            value: _dueDate,
                            onTap: _pickDueDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _invoiceNumber,
                      decoration: const InputDecoration(
                        labelText: 'Invoice number',
                        helperText: 'Auto-suggested; editable',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Line items
            Text('Line items',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return _ItemCard(
                key: row.key,
                index: i,
                row: row,
                isUnregistered: isUnregistered,
                gstRates: _gstRates,
                onChanged: () => setState(() {}),
                onRemove: _items.length > 1 ? () => _removeItem(i, row) : null,
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _items.add(_ItemRow())),
                icon: const Icon(Icons.add),
                label: const Text('Add line item'),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Discount + Payment card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Discount (optional)',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _discountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Value',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _discountType,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'flat', child: Text('Flat ₹')),
                              DropdownMenuItem(
                                  value: 'percent', child: Text('Percent %')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _discountType = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (calc.discountAmount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Discount amount: ₹${calc.discountAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Payment tracking — only for invoices, not quotations.
                    if (!_isQuotation) ...[
                      Text('Payment received (optional)',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountPaidController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Amount paid',
                          prefixText: '₹ ',
                          isDense: true,
                          helperText: 'Leave empty if not yet paid',
                        ),
                      ),
                      if (amountPaid > 0 && amountPaid < calc.total) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Balance due: ₹${(calc.total - amountPaid).toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Notes
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                alignLabelWithHint: true,
                hintText: 'Shown at the bottom of the PDF, e.g. payment terms.',
              ),
            ),
            const SizedBox(height: 16),

            // ---- Live GST summary
            GstSummaryCard(
              calculation: calc,
              isUnregistered: isUnregistered,
            ),
            if (!isUnregistered) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    calc.isIntrastate ? Icons.check_circle : Icons.swap_horiz,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      calc.isIntrastate
                          ? 'Intrastate — split into CGST + SGST'
                          : 'Interstate — full rate as IGST',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _save(status: 'draft'),
                  child: Text(_isQuotation ? 'Save draft' : 'Save as draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : () => _save(status: 'sent'),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isQuotation ? 'Save & send' : 'Save & mark sent'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GstCalculation _recalculate({
    required String sellerState,
    required String placeOfSupply,
    required bool isUnregistered,
  }) {
    final inputs = _items
        .where((r) => r.description.text.trim().isNotEmpty)
        .map((r) => InvoiceItemInput(
              description: r.description.text.trim(),
              quantity: double.tryParse(r.qty.text) ?? 1,
              unitPrice: double.tryParse(r.unitPrice.text) ?? 0,
              gstRatePercent: isUnregistered ? 0 : r.gstRate,
            ))
        .toList();

    // v3: build discount from form state for live preview.
    final discountValue = double.tryParse(_discountController.text) ?? 0;
    final discount = discountValue > 0
        ? DiscountInput(
            type: _discountType == 'percent'
                ? DiscountType.percent
                : DiscountType.flat,
            value: discountValue,
          )
        : null;

    return calculateInvoiceGst(
      items: inputs,
      sellerStateCode: sellerState,
      placeOfSupplyStateCode: placeOfSupply,
      discount: discount,
    );
  }
}

class _ItemRow {
  _ItemRow({this.id}) : key = UniqueKey();

  /// Stable identity for the widget tree — survives removal of sibling rows.
  final Key key;

  /// Persisted id (null for newly-added items, present when editing).
  final String? id;
  final TextEditingController description = TextEditingController();
  final TextEditingController hsn = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController unitPrice = TextEditingController(text: '0');
  double gstRate = 18;

  factory _ItemRow.fromItem(InvoiceItem i) {
    return _ItemRow(id: i.id)
      ..description.text = i.description
      ..hsn.text = i.hsnSacCode ?? ''
      ..qty.text =
          i.quantity.toStringAsFixed(i.quantity == i.quantity.toInt() ? 0 : 2)
      ..unitPrice.text = i.unitPrice.toStringAsFixed(2)
      ..gstRate = i.gstRatePercent;
  }

  void dispose() {
    description.dispose();
    hsn.dispose();
    qty.dispose();
    unitPrice.dispose();
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.index,
    required this.row,
    required this.isUnregistered,
    required this.gstRates,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _ItemRow row;
  final bool isUnregistered;
  final List<double> gstRates;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Item ${index + 1}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onRemove,
                    tooltip: 'Remove',
                  ),
              ],
            ),
            TextFormField(
              controller: row.description,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(labelText: 'Description *'),
              validator: (v) {
                // Allow empty rows to be silently filtered out — validation
                // happens at the form level, not per-row.
                return null;
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.hsn,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(labelText: 'HSN/SAC'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: row.qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.unitPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Unit price',
                      prefixText: '₹ ',
                    ),
                  ),
                ),
              ],
            ),
            if (!isUnregistered) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<double>(
                value: row.gstRate,
                decoration: const InputDecoration(labelText: 'GST rate'),
                items: gstRates
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('${r.toStringAsFixed(0)}%'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    row.gstRate = v;
                    onChanged();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value == null
        ? '—'
        : '${value!.day.toString().padLeft(2, '0')} '
            '${[
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ][value!.month - 1]} '
            '${value!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          display,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
