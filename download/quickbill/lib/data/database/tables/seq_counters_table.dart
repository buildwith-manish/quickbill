import 'package:drift/drift.dart';

/// Per-FY sequence counters for invoice numbers.
///
/// v1 derived the next number from existing invoice rows, which breaks if
/// the user reinstalls and restores from a backup that doesn't include
/// historical invoices. v2 persists an explicit counter keyed by FY label
/// (e.g. "2026-27"). Incremented atomically inside a transaction.
class SeqCounters extends Table {
  /// FY label, e.g. "2026-27".
  TextColumn get key => text()();

  /// Last-issued sequence number for this FY.
  IntColumn get lastSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
