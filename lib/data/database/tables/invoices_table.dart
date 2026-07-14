import 'package:drift/drift.dart';

import 'clients_table.dart';

/// Invoices raised against a client.
///
/// `placeOfSupply` defaults to the client's stateCode but can be overridden
/// per-invoice (rare, but supported). Tax amounts are stored denormalised so
/// the PDF can be regenerated deterministically without re-running the GST
/// service.
///
/// v3 additions:
///   - `discountType` ('flat' | 'percent') + `discountValue` — applied to
///     the subtotal BEFORE tax. Freelancers frequently offer 5% or ₹500 off.
///   - `amountPaid` — supports partial payments. When > 0 and < totalAmount,
///     the invoice is `partially_paid`.
///   - `documentType` ('invoice' | 'quotation') — reuses the same table for
///     quotations. Quotations get a QTN/ prefix and can be converted to
///     invoices via a clone-with-new-number action.
///
/// Indexes (v2.1): `clientId`, `issueDate`, `status` are indexed because
/// they're used in WHERE clauses by the repository. `clientId` + `issueDate`
/// were added in v2's migration; `status` is new — the invoice list screen
/// filters on it heavily.
@TableIndex(name: 'idx_invoices_status', columns: {#status})
@TableIndex(name: 'idx_invoices_client_id', columns: {#clientId})
@TableIndex(name: 'idx_invoices_issue_date', columns: {#issueDate})
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get clientId => text().references(Clients, #id)();
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get notes => text().nullable()();
  TextColumn get placeOfSupply => text()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get cgstAmount => real().withDefault(const Constant(0))();
  RealColumn get sgstAmount => real().withDefault(const Constant(0))();
  RealColumn get igstAmount => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();

  /// v3: discount applied before tax. `discountType` is 'flat' or 'percent'.
  /// `discountValue` is the flat amount in ₹ or the percentage (0-100).
  TextColumn get discountType =>
      text().withDefault(const Constant('flat'))();
  RealColumn get discountValue => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();

  /// v3: partial payment tracking. When `amountPaid` > 0 and < `totalAmount`,
  /// the invoice is `partially_paid`. When == `totalAmount`, it's `paid`.
  RealColumn get amountPaid => real().withDefault(const Constant(0))();

  /// v3: distinguishes invoices from quotations. Quotations use a QTN/
  /// prefix and can be converted to invoices via clone.
  TextColumn get documentType =>
      text().withDefault(const Constant('invoice'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
