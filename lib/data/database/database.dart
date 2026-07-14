import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/business_profile_table.dart';
import 'tables/clients_table.dart';
import 'tables/invoice_items_table.dart';
import 'tables/invoices_table.dart';
import 'tables/seq_counters_table.dart';

part 'database.g.dart';

/// Single Drift database for the entire app.
///
/// The DB file lives in the app's documents directory so it survives app
/// restarts and is backed up with the app. A migration strategy stub is
/// included even though v1 starts at schemaVersion 1 — this avoids painful
/// rewrites when v2 adds columns or tables.
@DriftDatabase(tables: [
  BusinessProfiles,
  Clients,
  Invoices,
  InvoiceItems,
  SeqCounters,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Also create indexes on fresh installs — onCreate only runs
          // createAll() which doesn't include custom indexes defined in
          // onUpgrade. We want fresh installs to have the same indexes
          // as upgraded ones.
          await _createIndexes(m);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: add indexes for FK columns and the seq_counters table.
            await m.createTable(seqCounters);
            await _createIndexes(m);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Creates all v2 indexes. Called from both onCreate (fresh install)
  /// and onUpgrade (v1→v2 upgrade).
  Future<void> _createIndexes(Migrator m) async {
    await m.createIndex(Index(
      'idx_invoices_client_id',
      'CREATE INDEX idx_invoices_client_id ON invoices (client_id)',
    ));
    await m.createIndex(Index(
      'idx_invoices_issue_date',
      'CREATE INDEX idx_invoices_issue_date ON invoices (issue_date)',
    ));
    await m.createIndex(Index(
      'idx_invoice_items_invoice_id',
      'CREATE INDEX idx_invoice_items_invoice_id ON invoice_items (invoice_id)',
    ));
  }

  /// Wipe all data — used by Settings → "Reset all data". Cascades through
  /// all 4 tables in the correct FK order.
  Future<void> wipeAll() async {
    await transaction(() async {
      await customStatement('DELETE FROM invoice_items');
      await customStatement('DELETE FROM invoices');
      await customStatement('DELETE FROM clients');
      await customStatement('DELETE FROM business_profiles');
      await customStatement('DELETE FROM seq_counters');
    });
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'quickbill.sqlite'));
    return NativeDatabase(file);
  });
}
