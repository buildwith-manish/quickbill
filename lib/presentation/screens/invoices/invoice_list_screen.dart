import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/database/database.dart';
import '../../providers/client_providers.dart';
import '../../providers/invoice_providers.dart';
import '../../widgets/empty_state.dart';

/// Filter chips shown above the invoice list.
enum _InvoiceFilter { all, draft, sent, paid }

extension _InvoiceFilterLabel on _InvoiceFilter {
  String get label {
    switch (this) {
      case _InvoiceFilter.all:
        return 'All';
      case _InvoiceFilter.draft:
        return 'Draft';
      case _InvoiceFilter.sent:
        return 'Sent';
      case _InvoiceFilter.paid:
        return 'Paid';
    }
  }
}

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  _InvoiceFilter _filter = _InvoiceFilter.all;

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceListProvider);
    final clientsAsync = ref.watch(clientListProvider);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _InvoiceFilter.values.map((f) {
                  final selected = f == _filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: invoicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (invoices) => clientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load clients: $e')),
                data: (clients) {
                  final byId = {for (final c in clients) c.id: c};
                  final filtered = _filter == _InvoiceFilter.all
                      ? invoices
                      : invoices.where((i) => i.status == _filter.name).toList();

                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No invoices yet',
                      message: _filter == _InvoiceFilter.all
                          ? 'Tap the + button below to create your first invoice. '
                            'QuickBill handles CGST/SGST vs IGST automatically based on '
                            'your state and the client\'s state.'
                          : 'No ${_filter.label.toLowerCase()} invoices right now.',
                      actionLabel: _filter == _InvoiceFilter.all ? 'New invoice' : null,
                      onAction: _filter == _InvoiceFilter.all
                          ? () => context.push('/invoices/new')
                          : null,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final inv = filtered[i];
                      final client = byId[inv.clientId];
                      return _InvoiceRow(
                        invoice: inv,
                        clientName: client?.name ?? 'Unknown client',
                        fmt: fmt,
                        dateFmt: dateFmt,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/invoices/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.clientName,
    required this.fmt,
    required this.dateFmt,
  });

  final Invoice invoice;
  final String clientName;
  final NumberFormat fmt;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    switch (invoice.status) {
      case 'paid':
        statusColor = Colors.green;
        break;
      case 'sent':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => context.push('/invoices/${invoice.id}/preview'),
        title: Row(
          children: [
            Expanded(
              child: Text(
                invoice.invoiceNumber,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                invoice.status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                dateFmt.format(invoice.issueDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            fmt.format(invoice.totalAmount),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
