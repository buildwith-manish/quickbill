import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/gst_calculation.dart';
import '../database/database.dart';

/// Result of saving an invoice — the persisted invoice plus its line items.
class SavedInvoice {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final Client client;

  SavedInvoice({
    required this.invoice,
    required this.items,
    required this.client,
  });
}

/// CRUD for Invoices + their line items (saved together in a transaction).
class InvoiceRepository {
  InvoiceRepository(this._db);

  final AppDatabase _db;

  /// All invoices, newest first.
  Future<List<Invoice>> all() async {
    return (_db.select(_db.invoices)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Paginated query for the invoice list screen.
  ///
  /// [limit] is the page size; [offset] is the number of rows already loaded.
  /// [statusFilter] is null for "all", or one of draft/sent/paid.
  Future<List<Invoice>> page({
    int limit = 30,
    int offset = 0,
    String? statusFilter,
  }) async {
    final query = _db.select(_db.invoices)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit, offset: offset);
    if (statusFilter != null) {
      query.where((t) => t.status.equals(statusFilter));
    }
    return query.get();
  }

  /// Total invoice count, optionally filtered by status. Used by the list
  /// screen to know when to stop fetching more pages.
  Future<int> count({String? statusFilter}) async {
    final countExpr = _db.invoices.id.count();
    final query = _db.selectOnly(_db.invoices)..addColumns([countExpr]);
    if (statusFilter != null) {
      query.where(_db.invoices.status.equals(statusFilter));
    }
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<Invoice?> byId(String id) async {
    return (_db.select(_db.invoices)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<InvoiceItem>> itemsFor(String invoiceId) async {
    return (_db.select(_db.invoiceItems)
          ..where((t) => t.invoiceId.equals(invoiceId)))
        .get();
  }

  /// All invoices issued in the FY starting [startYear] (Apr 1 → Mar 31).
  Future<List<Invoice>> forFinancialYear(int startYear) async {
    final start = DateTime(startYear, 4, 1);
    final end = DateTime(startYear + 1, 4, 1);
    return (_db.select(_db.invoices)
          ..where((t) => t.issueDate.isBetweenValues(start, end)))
        .get();
  }

  /// Creates a new invoice + its items in a single transaction.
  Future<SavedInvoice> create({
    required String invoiceNumber,
    required String clientId,
    required DateTime issueDate,
    DateTime? dueDate,
    String status = 'draft',
    String? notes,
    required String placeOfSupply,
    required double subtotal,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
    required double totalAmount,
    required List<InvoiceItemInput> items,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    return _db.transaction(() async {
      await _db.into(_db.invoices).insert(InvoicesCompanion.insert(
            id: id,
            invoiceNumber: invoiceNumber,
            clientId: clientId,
            issueDate: issueDate,
            dueDate: Value(dueDate),
            status: Value(status),
            notes: Value(notes),
            placeOfSupply: placeOfSupply,
            subtotal: Value(subtotal),
            cgstAmount: Value(cgstAmount),
            sgstAmount: Value(sgstAmount),
            igstAmount: Value(igstAmount),
            totalAmount: Value(totalAmount),
            createdAt: Value(now),
          ));

      for (final item in items) {
        await _db.into(_db.invoiceItems).insert(InvoiceItemsCompanion.insert(
              id: const Uuid().v4(),
              invoiceId: id,
              description: item.description,
              hsnSacCode: Value(item.hsnSacCode),
              quantity: Value(item.quantity),
              unitPrice: Value(item.unitPrice),
              gstRatePercent: Value(item.gstRatePercent),
              lineTotal: Value(item.lineTotal),
            ));
      }

      // Bump the FY counter atomically with the invoice insert so a crash
      // between the two can't leave the counter stale.
      await _bumpCounterFor(invoiceNumber);

      final invoice = (await byId(id))!;
      final savedItems = await itemsFor(id);
      final client = await (_db.select(_db.clients)
            ..where((t) => t.id.equals(clientId)))
          .getSingle();
      return SavedInvoice(
        invoice: invoice,
        items: savedItems,
        client: client,
      );
    });
  }

  /// Parses the seq out of an "INV/FY/####" number and bumps the FY counter
  /// to at least that value. Safe to call with manually-overridden numbers.
  Future<void> _bumpCounterFor(String invoiceNumber) async {
    final parts = invoiceNumber.split('/');
    if (parts.length != 3) return;
    final fyLabel = parts[1];
    final seq = int.tryParse(parts[2]);
    if (seq == null) return;

    final existing = await (_db.select(_db.seqCounters)
          ..where((t) => t.key.equals(fyLabel)))
        .getSingleOrNull();
    final newSeq =
        (existing?.lastSeq ?? 0) > seq ? (existing?.lastSeq ?? 0) : seq;
    await _db.into(_db.seqCounters).insertOnConflictUpdate(
          SeqCountersCompanion.insert(
            key: fyLabel,
            lastSeq: Value(newSeq),
          ),
        );
  }

  /// Replaces an existing invoice + items (full rewrite).
  Future<SavedInvoice> update({
    required String id,
    required String invoiceNumber,
    required String clientId,
    required DateTime issueDate,
    DateTime? dueDate,
    required String status,
    String? notes,
    required String placeOfSupply,
    required double subtotal,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
    required double totalAmount,
    required List<InvoiceItemInput> items,
  }) async {
    return _db.transaction(() async {
      await (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
        InvoicesCompanion(
          invoiceNumber: Value(invoiceNumber),
          clientId: Value(clientId),
          issueDate: Value(issueDate),
          dueDate: Value(dueDate),
          status: Value(status),
          notes: Value(notes),
          placeOfSupply: Value(placeOfSupply),
          subtotal: Value(subtotal),
          cgstAmount: Value(cgstAmount),
          sgstAmount: Value(sgstAmount),
          igstAmount: Value(igstAmount),
          totalAmount: Value(totalAmount),
        ),
      );

      // Replace all items: simplest correct strategy for v1.
      await (_db.delete(_db.invoiceItems)..where((t) => t.invoiceId.equals(id)))
          .go();
      for (final item in items) {
        await _db.into(_db.invoiceItems).insert(InvoiceItemsCompanion.insert(
              id: item.id ?? const Uuid().v4(),
              invoiceId: id,
              description: item.description,
              hsnSacCode: Value(item.hsnSacCode),
              quantity: Value(item.quantity),
              unitPrice: Value(item.unitPrice),
              gstRatePercent: Value(item.gstRatePercent),
              lineTotal: Value(item.lineTotal),
            ));
      }

      // Keep the FY counter in sync if the user changed the invoice number.
      await _bumpCounterFor(invoiceNumber);

      final invoice = (await byId(id))!;
      final savedItems = await itemsFor(id);
      final client = await (_db.select(_db.clients)
            ..where((t) => t.id.equals(clientId)))
          .getSingle();
      return SavedInvoice(
        invoice: invoice,
        items: savedItems,
        client: client,
      );
    });
  }

  Future<void> setStatus(String id, String status) async {
    await (_db.update(_db.invoices)..where((t) => t.id.equals(id)))
        .write(InvoicesCompanion(status: Value(status)));
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.invoiceItems)..where((t) => t.invoiceId.equals(id)))
          .go();
      await (_db.delete(_db.invoices)..where((t) => t.id.equals(id))).go();
    });
  }
}
