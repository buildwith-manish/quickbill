import 'package:drift/drift.dart';

/// Clients (buyers) for whom invoices are raised.
///
/// A client may or may not be GST-registered. The `stateCode` is required
/// because it determines whether an invoice for this client is intra- or
/// inter-state (and therefore CGST/SGST vs IGST).
///
/// Index (v2.1): `name` is indexed because the client list screen orders
/// by name and the v2.1 search uses a SQL LIKE query on it.
@TableIndex(name: 'idx_clients_name', columns: {#name})
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get gstin => text().nullable()();
  TextColumn get stateCode => text()();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
