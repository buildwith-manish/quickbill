import 'package:drift/drift.dart';

import 'clients_table.dart';

/// Invoices raised against a client.
///
/// `placeOfSupply` defaults to the client's stateCode but can be overridden
/// per-invoice (rare, but supported). Tax amounts are stored denormalised so
/// the PDF can be regenerated deterministically without re-running the GST
/// service.
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
