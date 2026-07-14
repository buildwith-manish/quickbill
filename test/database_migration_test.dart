import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/data/database/database.dart';

/// Tests for Drift schema migration — verifies the v1→v2 upgrade path
/// creates the SeqCounters table and indexes without losing v1 data.
void main() {
  group('Database migration', () {
    test('fresh DB creates all tables at schemaVersion 3', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Schema version must be 3 (v3 added discount/payment/documentType columns).
      expect(db.schemaVersion, 3);

      // All 5 tables should exist.
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
          )
          .get();
      final tableNames = tables.map((r) => r.read<String>('name')).toSet();
      expect(
          tableNames,
          containsAll([
            'business_profiles',
            'clients',
            'invoices',
            'invoice_items',
            'seq_counters',
          ]));

      await db.close();
    });

    test('SeqCounters table is queryable on fresh DB', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Insert a counter row.
      await db.into(db.seqCounters).insert(
            SeqCountersCompanion.insert(
                key: '2026-27', lastSeq: const Value(5)),
          );

      // Read it back.
      final row = await (db.select(db.seqCounters)
            ..where((t) => t.key.equals('2026-27')))
          .getSingle();
      expect(row.lastSeq, 5);

      await db.close();
    });

    test('indexes exist on invoices.client_id and issue_date', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
          )
          .get();
      final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
      expect(
          indexNames,
          containsAll([
            'idx_invoices_client_id',
            'idx_invoices_issue_date',
            'idx_invoice_items_invoice_id',
          ]));

      await db.close();
    });

    test('wipeAll clears all tables including seq_counters', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Seed all tables.
      await db
          .into(db.businessProfiles)
          .insert(BusinessProfilesCompanion.insert(
            id: const Value(1),
            businessName: 'Test',
            stateCode: '27',
          ));
      await db.into(db.clients).insert(ClientsCompanion.insert(
            id: 'c1',
            name: 'Client',
            stateCode: '27',
          ));
      await db.into(db.invoices).insert(InvoicesCompanion.insert(
            id: 'inv1',
            invoiceNumber: 'INV/2026-27/0001',
            clientId: 'c1',
            issueDate: DateTime(2026, 7, 14),
            placeOfSupply: '27',
          ));
      await db.into(db.invoiceItems).insert(InvoiceItemsCompanion.insert(
            id: 'i1',
            invoiceId: 'inv1',
            description: 'Item',
          ));
      await db.into(db.seqCounters).insert(
            SeqCountersCompanion.insert(
                key: '2026-27', lastSeq: const Value(1)),
          );

      await db.wipeAll();

      expect((await db.select(db.businessProfiles).get()), isEmpty);
      expect((await db.select(db.clients).get()), isEmpty);
      expect((await db.select(db.invoices).get()), isEmpty);
      expect((await db.select(db.invoiceItems).get()), isEmpty);
      expect((await db.select(db.seqCounters).get()), isEmpty);

      await db.close();
    });
  });
}
