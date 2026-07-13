import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/business_profile_table.dart';
import 'tables/clients_table.dart';
import 'tables/invoice_items_table.dart';
import 'tables/invoices_table.dart';

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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v2+: chain `if (from < 2) await m.addColumn(...)` here.
          // v1 has nothing to do — initial schema is created by onCreate.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'quickbill.sqlite'));
    return NativeDatabase(file);
  });
}
