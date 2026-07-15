import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/database/database.dart';
import 'invoice_providers.dart';

part 'invoice_list_provider.g.dart';

/// Page size for the invoice list — 30 is enough for most phone screens to
/// fill the viewport, but small enough that the first page loads in <50ms
/// even on a slow device with thousands of invoices.
const _pageSize = 30;

/// State for the paginated invoice list.
class InvoiceListState {
  final List<Invoice> items;
  final bool hasMore;
  final bool isLoading;
  final String? filter; // null = all, else draft/sent/paid
  final String? error;

  const InvoiceListState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.filter,
    this.error,
  });

  InvoiceListState copyWith({
    List<Invoice>? items,
    bool? hasMore,
    bool? isLoading,
    String? filter,
    String? error,
    bool clearError = false,
  }) {
    return InvoiceListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      filter: filter,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Paginated invoice list with status filter and infinite scroll.
///
/// The list is keyed by `filter` — changing the filter resets to page 1.
/// Call [loadMore] from a ScrollController listener when the user is near
/// the bottom of the list.
@riverpod
class PaginatedInvoiceList extends _$PaginatedInvoiceList {
  @override
  Future<InvoiceListState> build({String? filter}) async {
    final repo = ref.watch(invoiceRepositoryProvider);
    final firstPage = await repo.page(
      limit: _pageSize,
      offset: 0,
      statusFilter: filter,
    );
    final total = await repo.count(statusFilter: filter);
    return InvoiceListState(
      items: firstPage,
      hasMore: firstPage.length < total,
      filter: filter,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoading || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoading: true));
    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final next = await repo.page(
        limit: _pageSize,
        offset: current.items.length,
        statusFilter: current.filter,
      );
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next],
        hasMore: next.length == _pageSize,
        isLoading: false,
        clearError: true,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(invoiceRepositoryProvider);
      final firstPage = await repo.page(
        limit: _pageSize,
        offset: 0,
        statusFilter: filter,
      );
      final total = await repo.count(statusFilter: filter);
      return InvoiceListState(
        items: firstPage,
        hasMore: firstPage.length < total,
        filter: filter,
      );
    });
  }
}
