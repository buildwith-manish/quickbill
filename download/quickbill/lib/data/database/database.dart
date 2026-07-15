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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // createAll() now handles indexes too — the @TableIndex annotations
          // on Invoices, Clients, and InvoiceItems generate them automatically.
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: add indexes for FK columns and the seq_counters table.
            await m.createTable(seqCounters);
            await _createLegacyIndexes(m);
          }
          if (from < 3) {
            // v3: discount + payment status + documentType + invoiceTemplate.
            // All new columns have defaults so the migration is non-destructive.
            await m.addColumn(invoices, invoices.discountType);
            await m.addColumn(invoices, invoices.discountValue);
            await m.addColumn(invoices, invoices.discountAmount);
            await m.addColumn(invoices, invoices.amountPaid);
            await m.addColumn(invoices, invoices.documentType);
            await m.addColumn(businessProfiles, businessProfiles.invoiceTemplate);
          }
          if (from < 4) {
            // v2.1: add missing indexes for status + clients.name.
            // The @TableIndex annotations handle fresh installs; this block
            // handles upgrading users who already have a v1/v2/v3 DB.
            // Use IF NOT EXISTS because some indexes may already exist from v2.
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices (status)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_clients_name ON clients (name)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items (invoice_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_invoices_client_id ON invoices (client_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_invoices_issue_date ON invoices (issue_date)',
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Legacy v2 indexes — only used when upgrading from v1 directly.
  /// Kept for backward compat with the earliest adopters.
  Future<void> _createLegacyIndexes(Migrator m) async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_invoices_client_id ON invoices (client_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_invoices_issue_date ON invoices (issue_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items (invoice_id)',
    );
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
