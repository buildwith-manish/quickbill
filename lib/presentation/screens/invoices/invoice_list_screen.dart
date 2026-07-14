import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/database/database.dart';
import '../../providers/client_providers.dart';
import '../../providers/invoice_list_provider.dart';
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

  String? get wireValue {
    switch (this) {
      case _InvoiceFilter.all:
        return null;
      case _InvoiceFilter.draft:
        return 'draft';
      case _InvoiceFilter.sent:
        return 'sent';
      case _InvoiceFilter.paid:
        return 'paid';
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
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Trigger the next page load when within 200px of the bottom.
      final filter = _filter.wireValue;
      ref
          .read(paginatedInvoiceListProvider(filter: filter).notifier)
          .loadMore();
    }
  }

  void _changeFilter(_InvoiceFilter f) {
    setState(() => _filter = f);
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter.wireValue;
    final listAsync = ref.watch(paginatedInvoiceListProvider(filter: filter));
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
                      onSelected: (_) => _changeFilter(f),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (listState) => clientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Failed to load clients: $e')),
                data: (clients) {
                  final byId = {for (final c in clients) c.id: c};
                  final invoices = listState.items;

                  if (invoices.isEmpty && !listState.isLoading) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No invoices yet',
                      message: _filter == _InvoiceFilter.all
                          ? 'Tap the + button below to create your first invoice. '
                              'Invory handles CGST/SGST vs IGST automatically based on '
                              'your state and the client\'s state.'
                          : 'No ${_filter.label.toLowerCase()} invoices right now.',
                      actionLabel:
                          _filter == _InvoiceFilter.all ? 'New invoice' : null,
                      onAction: _filter == _InvoiceFilter.all
                          ? () => context.push('/invoices/new')
                          : null,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(paginatedInvoiceListProvider(filter: filter)
                            .notifier)
                        .refresh(),
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                      itemCount: invoices.length + 1, // +1 for trailing loader
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        if (i == invoices.length) {
                          // Trailing loader / end-of-list marker.
                          if (listState.isLoading) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          if (!listState.hasMore) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  '${invoices.length} invoices',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        final inv = invoices[i];
                        final client = byId[inv.clientId];
                        return _InvoiceRow(
                          invoice: inv,
                          clientName: client?.name ?? 'Unknown client',
                          fmt: fmt,
                          dateFmt: dateFmt,
                        );
                      },
                    ),
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
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
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
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
