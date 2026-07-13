import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/database/database.dart';
import '../../../domain/models/gst_calculation.dart';
import '../../../domain/services/pdf_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/gst_state_codes.dart';
import '../../providers/business_profile_providers.dart';
import '../../providers/client_providers.dart';
import '../../providers/invoice_providers.dart';

/// Invoice preview / PDF actions.
///
/// Renders an on-screen preview that matches the [PdfService] output, with
/// buttons for Share, Mark as Paid, Edit, and Delete.
class InvoicePreviewScreen extends ConsumerStatefulWidget {
  const InvoicePreviewScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoicePreviewScreen> createState() =>
      _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceByIdProvider(widget.invoiceId));
    final itemsAsync = ref.watch(invoiceItemsProvider(widget.invoiceId));
    final profileAsync = ref.watch(businessProfileControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('/invoices/${widget.invoiceId}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Load error: $e')),
        data: (invoice) {
          if (invoice == null) {
            return const Center(child: Text('Invoice not found'));
          }
          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Items load error: $e')),
            data: (items) => profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Profile load error: $e')),
              data: (profile) {
                if (profile == null) {
                  return const Center(child: Text('No business profile'));
                }
                final gst = GstCalculation(
                  subtotal: invoice.subtotal,
                  cgst: invoice.cgstAmount,
                  sgst: invoice.sgstAmount,
                  igst: invoice.igstAmount,
                  total: invoice.totalAmount,
                );
                // Client is fetched inside [_ClientLoader] to keep the
                // preview reactive when either side mutates.
                return _ClientLoader(
                  invoice: invoice,
                  items: items,
                  gst: gst,
                  business: profile,
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: invoiceAsync.maybeWhen(
        data: (inv) => inv == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _share(inv),
                          icon: const Icon(Icons.share),
                          label: const Text('Share PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: inv.status == 'paid' || _busy
                              ? null
                              : () => _markPaid(inv),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(inv.status == 'paid'
                              ? 'Paid'
                              : 'Mark as paid'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        orElse: () => null,
      ),
    );
  }

  // The client is fetched inside [_ClientLoader] to keep the preview
  // reactive without coupling the invoice provider to the client provider.

  Future<void> _share(Invoice invoice) async {
    setState(() => _busy = true);
    try {
      final items = await ref.read(invoiceItemsProvider(invoice.id).future);
      final profile = await ref.read(businessProfileControllerProvider.future);
      if (profile == null) return;
      final client = await ref.read(clientByIdProvider(invoice.clientId).future);
      if (client == null) return;

      final data = PdfInvoiceData(
        business: profile,
        client: client,
        invoice: invoice,
        items: items,
        gst: GstCalculation(
          subtotal: invoice.subtotal,
          cgst: invoice.cgstAmount,
          sgst: invoice.sgstAmount,
          igst: invoice.igstAmount,
          total: invoice.totalAmount,
        ),
      );

      final bytes = await PdfService().build(data).save();

      // Save to a temp file in the cache dir, then share via the native sheet.
      final tmpDir = await getTemporaryDirectory();
      final filename = '${invoice.invoiceNumber.replaceAll('/', '_')}.pdf';
      final file = File(p.join(tmpDir.path, filename));
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice ${invoice.invoiceNumber} from ${profile.businessName}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markPaid(Invoice invoice) async {
    await ref.read(invoiceRepositoryProvider).setStatus(invoice.id, 'paid');
    // Cancel any pending reminder — invoice is settled.
    try {
      await ref.read(reminderServiceProvider).cancelFor(invoice);
    } catch (_) {}
    ref.invalidate(invoiceByIdProvider(invoice.id));
    ref.invalidate(invoiceListProvider);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: const Text(
            'This permanently deletes the invoice and its line items. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(invoiceRepositoryProvider).delete(widget.invoiceId);
    ref.invalidate(invoiceListProvider);
    if (mounted) context.go('/invoices');
  }
}

/// Loads the client for the given invoice and renders the preview body.
class _ClientLoader extends ConsumerWidget {
  const _ClientLoader({
    required this.invoice,
    required this.items,
    required this.gst,
    required this.business,
  });

  final Invoice invoice;
  final List<InvoiceItem> items;
  final GstCalculation gst;
  final BusinessProfile business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientByIdProvider(invoice.clientId));
    return clientAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Client load error: $e')),
      data: (client) {
        if (client == null) {
          return const Center(child: Text('Client not found'));
        }
        final data = PdfInvoiceData(
          business: business,
          client: client,
          invoice: invoice,
          items: items,
          gst: gst,
        );
        return _PdfPreviewBody(data: data);
      },
    );
  }
}

class _PdfPreviewBody extends StatelessWidget {
  const _PdfPreviewBody({required this.data});

  final PdfInvoiceData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFmt = DateFormat('dd MMM yyyy');
    final isUnregistered = !data.business.isGstRegistered;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.business.businessName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (data.business.address.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                data.business.address,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          if (isUnregistered)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Not registered under GST',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.red),
                              ),
                            )
                          else ...[
                            if ((data.business.gstin ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'GSTIN: ${data.business.gstin}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            if ((data.business.panNumber ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'PAN: ${data.business.panNumber}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isUnregistered ? 'INVOICE' : 'TAX INVOICE',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(data.invoice.invoiceNumber,
                            style: theme.textTheme.bodySmall),
                        Text('Issued: ${dateFmt.format(data.invoice.issueDate)}',
                            style: theme.textTheme.bodySmall),
                        if (data.invoice.dueDate != null)
                          Text('Due: ${dateFmt.format(data.invoice.dueDate!)}',
                              style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text('Bill To',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(
                  data.client.name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if ((data.client.gstin ?? '').isNotEmpty)
                  Text('GSTIN: ${data.client.gstin}',
                      style: theme.textTheme.bodySmall),
                if ((data.client.address ?? '').isNotEmpty)
                  Text(data.client.address!,
                      style: theme.textTheme.bodySmall),
                Text(
                  'State: ${stateNameForCode(data.client.stateCode) ?? data.client.stateCode} (${data.client.stateCode})',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Place of Supply: ${stateNameForCode(data.invoice.placeOfSupply) ?? data.invoice.placeOfSupply} (Code: ${data.invoice.placeOfSupply})',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _ItemsTable(
              items: data.items,
              isUnregistered: isUnregistered,
              fmt: fmt,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _summaryRow('Subtotal', fmt.format(data.gst.subtotal), theme),
                if (isUnregistered)
                  _summaryRow(
                    'Tax',
                    'Not applicable',
                    theme,
                    color: Colors.orange,
                    italic: true,
                  )
                else ...[
                  if (data.gst.cgst > 0)
                    _summaryRow('CGST', fmt.format(data.gst.cgst), theme),
                  if (data.gst.sgst > 0)
                    _summaryRow('SGST', fmt.format(data.gst.sgst), theme),
                  if (data.gst.igst > 0)
                    _summaryRow('IGST', fmt.format(data.gst.igst), theme),
                ],
                const Divider(),
                _summaryRow(
                  'Total Amount',
                  fmt.format(data.gst.total),
                  theme,
                  bold: true,
                  large: true,
                ),
              ],
            ),
          ),
        ),
        if ((data.invoice.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.subtleContainer.withOpacity(0.4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(data.invoice.notes!,
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value, ThemeData theme,
      {bool bold = false, bool large = false, bool italic = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : null,
              color: color,
              fontSize: large ? 16 : null,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : null,
              color: color ?? (bold ? theme.colorScheme.primary : null),
              fontSize: large ? 16 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.items,
    required this.isUnregistered,
    required this.fmt,
  });

  final List<InvoiceItem> items;
  final bool isUnregistered;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium
        ?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FlexColumnWidth(1.3),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1.5),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: theme.dividerColor, width: 0.5),
      ),
      children: [
        TableRow(
          children: [
            _cell('Description', headerStyle, align: Alignment.centerLeft),
            _cell('HSN/SAC', headerStyle, align: Alignment.centerLeft),
            _cell('Qty', headerStyle, align: Alignment.centerRight),
            _cell('Unit Price', headerStyle, align: Alignment.centerRight),
            if (!isUnregistered)
              _cell('GST%', headerStyle, align: Alignment.centerRight),
            _cell('Amount', headerStyle, align: Alignment.centerRight),
          ],
        ),
        ...items.map((i) => TableRow(
              children: [
                _cell(i.description, theme.textTheme.bodyMedium, align: Alignment.centerLeft),
                _cell(i.hsnSacCode ?? '—', theme.textTheme.bodyMedium, align: Alignment.centerLeft),
                _cell(_fmtQty(i.quantity), theme.textTheme.bodyMedium, align: Alignment.centerRight),
                _cell(fmt.format(i.unitPrice), theme.textTheme.bodyMedium, align: Alignment.centerRight),
                if (!isUnregistered)
                  _cell('${i.gstRatePercent.toStringAsFixed(0)}%', theme.textTheme.bodyMedium, align: Alignment.centerRight),
                _cell(fmt.format(i.lineTotal), theme.textTheme.bodyMedium, align: Alignment.centerRight),
              ],
            )),
      ],
    );
  }

  Widget _cell(String text, TextStyle? style, {required Alignment align}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Align(alignment: align, child: Text(text, style: style)),
    );
  }

  String _fmtQty(double q) {
    if (q == q.toInt()) return q.toInt().toString();
    return q.toStringAsFixed(2);
  }
}
