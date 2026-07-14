import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/data/database/database.dart';
import 'package:quickbill/data/repositories/invoice_repository.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';
import 'package:quickbill/domain/services/invoice_number_service.dart';

/// Tests for [InvoiceNumberService].
///
/// Critical invariant under test: deleting an invoice must NOT cause the
/// next created invoice to reuse its number. Numbers should never collide,
/// even after deletions — the persisted counter in [SeqCounters] guarantees
/// monotonicity within an FY.
void main() {
  late AppDatabase db;
  late InvoiceRepository repo;
  late InvoiceNumberService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = InvoiceRepository(db);
    service = InvoiceNumberService(db, repo);
  });

  tearDown(() async => db.close());

  group('InvoiceNumberService FY helpers', () {
    test('April → current year is the FY start', () {
      expect(InvoiceNumberService.fyStartYear(DateTime(2026, 4, 1)), 2026);
      expect(InvoiceNumberService.fyStartYear(DateTime(2026, 7, 14)), 2026);
    });

    test('March → previous year is the FY start', () {
      // March 2027 belongs to FY 2026-27.
      expect(InvoiceNumberService.fyStartYear(DateTime(2027, 3, 31)), 2026);
      expect(InvoiceNumberService.fyStartYear(DateTime(2027, 1, 1)), 2026);
    });

    test('FY label format: start year 2026 → "2026-27"', () {
      expect(InvoiceNumberService.fyLabel(2026), '2026-27');
      expect(InvoiceNumberService.fyLabel(2025), '2025-26');
      expect(InvoiceNumberService.fyLabel(2030), '2030-31');
    });
  });

  group('InvoiceNumberService.nextNumber', () {
    test('first invoice in a fresh FY returns INV/<fy>/0001', () async {
      final num = await service.nextNumber(at: DateTime(2026, 7, 14));
      expect(num, 'INV/2026-27/0001');
    });

    test('second invoice returns 0002 after first is saved', () async {
      // Save the first invoice to bump the counter.
      // We need a client + business profile for the FK constraints.
      await _seedClientAndProfile(db);

      final first = await repo.create(
        invoiceNumber: await service.nextNumber(at: DateTime(2026, 7, 14)),
        clientId: 'client-1',
        issueDate: DateTime(2026, 7, 14),
        placeOfSupply: '27',
        subtotal: 1000,
        cgstAmount: 90,
        sgstAmount: 90,
        igstAmount: 0,
        totalAmount: 1180,
        items: const [
          InvoiceItemInput(
              description: 'X',
              quantity: 1,
              unitPrice: 1000,
              gstRatePercent: 18),
        ],
      );
      expect(first.invoice.invoiceNumber, 'INV/2026-27/0001');

      final next = await service.nextNumber(at: DateTime(2026, 7, 15));
      expect(next, 'INV/2026-27/0002');
    });

    test('CRITICAL: deleting an invoice does NOT cause number reuse', () async {
      await _seedClientAndProfile(db);

      // Create invoice 0001.
      final inv1 = await repo.create(
        invoiceNumber: 'INV/2026-27/0001',
        clientId: 'client-1',
        issueDate: DateTime(2026, 7, 14),
        placeOfSupply: '27',
        subtotal: 1000,
        cgstAmount: 90,
        sgstAmount: 90,
        igstAmount: 0,
        totalAmount: 1180,
        items: const [
          InvoiceItemInput(
              description: 'A',
              quantity: 1,
              unitPrice: 1000,
              gstRatePercent: 18),
        ],
      );

      // Create invoice 0002.
      final inv2 = await repo.create(
        invoiceNumber: 'INV/2026-27/0002',
        clientId: 'client-1',
        issueDate: DateTime(2026, 7, 15),
        placeOfSupply: '27',
        subtotal: 2000,
        cgstAmount: 180,
        sgstAmount: 180,
        igstAmount: 0,
        totalAmount: 2360,
        items: const [
          InvoiceItemInput(
              description: 'B',
              quantity: 2,
              unitPrice: 1000,
              gstRatePercent: 18),
        ],
      );

      // Delete invoice 0002.
      await repo.delete(inv2.invoice.id);

      // The next suggested number must NOT reuse 0002.
      // It should be 0003 — the counter has moved past 0002 even though
      // 0002 was deleted.
      final next = await service.nextNumber(at: DateTime(2026, 7, 16));
      expect(next, 'INV/2026-27/0003',
          reason:
              'Deleting an invoice must not cause its number to be reused.');

      // Also delete invoice 0001 and verify the counter still doesn't go back.
      await repo.delete(inv1.invoice.id);
      final next2 = await service.nextNumber(at: DateTime(2026, 7, 17));
      expect(next2, 'INV/2026-27/0003',
          reason: 'Counter persists across deletions — no rollback.');
    });

    test('counter resets across FY boundary', () async {
      await _seedClientAndProfile(db);

      // End of FY 2025-26 (March 2026).
      final fy1 = await service.nextNumber(at: DateTime(2026, 3, 31));
      expect(fy1, 'INV/2025-26/0001');

      // Start of FY 2026-27 (April 2026) — counter restarts at 0001.
      final fy2 = await service.nextNumber(at: DateTime(2026, 4, 2));
      expect(fy2, 'INV/2026-27/0001');

      // Save an invoice in FY 2026-27 to bump its counter. Use April 2 to
      // avoid the April-1 boundary ambiguity in the FY query.
      await repo.create(
        invoiceNumber: fy2,
        clientId: 'client-1',
        issueDate: DateTime(2026, 4, 2),
        placeOfSupply: '27',
        subtotal: 1000,
        cgstAmount: 90,
        sgstAmount: 90,
        igstAmount: 0,
        totalAmount: 1180,
        items: const [
          InvoiceItemInput(
              description: 'A',
              quantity: 1,
              unitPrice: 1000,
              gstRatePercent: 18),
        ],
      );

      // Next in FY 2026-27 should be 0002.
      final fy2Next = await service.nextNumber(at: DateTime(2026, 5, 1));
      expect(fy2Next, 'INV/2026-27/0002');

      // FY 2025-26 is still at 0001 (no invoices saved there).
      final fy1Again = await service.nextNumber(at: DateTime(2026, 3, 31));
      expect(fy1Again, 'INV/2025-26/0001');
    });

    test('manual override to a higher number bumps the counter', () async {
      await _seedClientAndProfile(db);

      // User manually overrides invoice number to 0010 instead of 0001.
      await repo.create(
        invoiceNumber: 'INV/2026-27/0010',
        clientId: 'client-1',
        issueDate: DateTime(2026, 7, 14),
        placeOfSupply: '27',
        subtotal: 1000,
        cgstAmount: 90,
        sgstAmount: 90,
        igstAmount: 0,
        totalAmount: 1180,
        items: const [
          InvoiceItemInput(
              description: 'A',
              quantity: 1,
              unitPrice: 1000,
              gstRatePercent: 18),
        ],
      );

      // Next suggestion should be 0011, not 0001 — the counter caught up
      // to the manual override.
      final next = await service.nextNumber(at: DateTime(2026, 7, 15));
      expect(next, 'INV/2026-27/0011');
    });

    test('no number collision across 10 sequential creates', () async {
      await _seedClientAndProfile(db);

      final numbers = <String>{};
      for (var i = 1; i <= 10; i++) {
        final num = await service.nextNumber(at: DateTime(2026, 7, 14));
        // Each must be unique.
        expect(numbers.contains(num), isFalse,
            reason: 'Collision on iteration $i: $num');
        numbers.add(num);

        await repo.create(
          invoiceNumber: num,
          clientId: 'client-1',
          issueDate: DateTime(2026, 7, 14),
          placeOfSupply: '27',
          subtotal: 1000,
          cgstAmount: 90,
          sgstAmount: 90,
          igstAmount: 0,
          totalAmount: 1180,
          items: const [
            InvoiceItemInput(
                description: 'X',
                quantity: 1,
                unitPrice: 1000,
                gstRatePercent: 18),
          ],
        );
      }

      // Final set: 0001 through 0010, all unique.
      expect(numbers.length, 10);
      expect(numbers.contains('INV/2026-27/0001'), isTrue);
      expect(numbers.contains('INV/2026-27/0010'), isTrue);
    });
  });
}

/// Seeds a single client + business profile so FK constraints pass on
/// invoice inserts.
Future<void> _seedClientAndProfile(AppDatabase db) async {
  await db.into(db.businessProfiles).insert(BusinessProfilesCompanion.insert(
        id: const Value(1),
        businessName: 'Test Business',
        stateCode: '27',
        isGstRegistered: const Value(true),
      ));

  await db.into(db.clients).insert(ClientsCompanion.insert(
        id: 'client-1',
        name: 'Test Client',
        stateCode: '27',
      ));
}
