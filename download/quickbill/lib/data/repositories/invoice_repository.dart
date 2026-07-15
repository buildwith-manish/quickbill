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
    String discountType = 'flat',
    double discountValue = 0,
    double discountAmount = 0,
    double amountPaid = 0,
    String documentType = 'invoice',
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
            discountType: Value(discountType),
            discountValue: Value(discountValue),
            discountAmount: Value(discountAmount),
            amountPaid: Value(amountPaid),
            documentType: Value(documentType),
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

  /// Parses the seq out of an "INV/FY/####" or "QTN/FY/####" number and
  /// bumps the corresponding counter (keyed by 'PREFIX-FY') to at least
  /// that value. Safe to call with manually-overridden numbers.
  Future<void> _bumpCounterFor(String invoiceNumber) async {
    final parts = invoiceNumber.split('/');
    if (parts.length != 3) return;
    final prefix = parts[0];
    final fyLabel = parts[1];
    final seq = int.tryParse(parts[2]);
    if (seq == null) return;

    final counterKey = '$prefix-$fyLabel';
    final existing = await (_db.select(_db.seqCounters)
          ..where((t) => t.key.equals(counterKey)))
        .getSingleOrNull();
    final newSeq =
        (existing?.lastSeq ?? 0) > seq ? (existing?.lastSeq ?? 0) : seq;
    await _db.into(_db.seqCounters).insertOnConflictUpdate(
          SeqCountersCompanion.insert(
            key: counterKey,
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
    String discountType = 'flat',
    double discountValue = 0,
    double discountAmount = 0,
    double amountPaid = 0,
    String documentType = 'invoice',
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
          discountType: Value(discountType),
          discountValue: Value(discountValue),
          discountAmount: Value(discountAmount),
          amountPaid: Value(amountPaid),
          documentType: Value(documentType),
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

  /// Records a partial or full payment against an invoice.
  /// Automatically updates the status to 'paid' when amountPaid >= total.
  Future<void> recordPayment(String id, double amountPaid) async {
    final invoice = await byId(id);
    if (invoice == null) return;
    final newStatus = amountPaid >= invoice.totalAmount ? 'paid' : 'partially_paid';
    await (_db.update(_db.invoices)..where((t) => t.id.equals(id))).write(
      InvoicesCompanion(
        amountPaid: Value(amountPaid),
        status: Value(newStatus),
      ),
    );
  }

  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.invoiceItems)..where((t) => t.invoiceId.equals(id)))
          .go();
      await (_db.delete(_db.invoices)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Clones a quotation into a new invoice with a fresh invoice number.
  /// The original quotation is preserved (not deleted). Returns the new
  /// invoice's id so the caller can navigate to its preview.
  ///
  /// The caller must supply the new invoice number (generated by
  /// [InvoiceNumberService] with the 'INV/' prefix).
  Future<String> convertQuotationToInvoice({
    required String quotationId,
    required String newInvoiceNumber,
  }) async {
    final quotation = await byId(quotationId);
    if (quotation == null) {
      throw ArgumentError('Quotation $quotationId not found');
    }
    final items = await itemsFor(quotationId);
    final newId = const Uuid().v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.invoices).insert(InvoicesCompanion.insert(
            id: newId,
            invoiceNumber: newInvoiceNumber,
            clientId: quotation.clientId,
            issueDate: now,
            dueDate: Value(quotation.dueDate),
            status: const Value('draft'),
            notes: Value(quotation.notes),
            placeOfSupply: quotation.placeOfSupply,
            subtotal: Value(quotation.subtotal),
            cgstAmount: Value(quotation.cgstAmount),
            sgstAmount: Value(quotation.sgstAmount),
            igstAmount: Value(quotation.igstAmount),
            totalAmount: Value(quotation.totalAmount),
            discountType: Value(quotation.discountType),
            discountValue: Value(quotation.discountValue),
            discountAmount: Value(quotation.discountAmount),
            amountPaid: const Value(0),
            documentType: const Value('invoice'),
            createdAt: Value(now),
          ));

      for (final item in items) {
        await _db.into(_db.invoiceItems).insert(InvoiceItemsCompanion.insert(
              id: const Uuid().v4(),
              invoiceId: newId,
              description: item.description,
              hsnSacCode: Value(item.hsnSacCode),
              quantity: Value(item.quantity),
              unitPrice: Value(item.unitPrice),
              gstRatePercent: Value(item.gstRatePercent),
              lineTotal: Value(item.lineTotal),
            ));
      }

      await _bumpCounterFor(newInvoiceNumber);
    });

    return newId;
  }
}
