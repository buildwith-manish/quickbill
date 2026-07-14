import 'package:drift/drift.dart';

import 'invoices_table.dart';

/// Line items belonging to an invoice.
///
/// `gstRatePercent` is constrained by the UI to one of {0, 5, 12, 18, 28}.
/// `lineTotal` = quantity × unitPrice (pre-tax), persisted for history.
class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(Invoices, #id)();
  TextColumn get description => text()();
  TextColumn get hsnSacCode => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  RealColumn get gstRatePercent => real().withDefault(const Constant(0))();
  RealColumn get lineTotal => real().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
