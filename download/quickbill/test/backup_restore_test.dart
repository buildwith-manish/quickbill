import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/data/database/database.dart';
import 'package:quickbill/data/repositories/business_profile_repository.dart';
import 'package:quickbill/data/repositories/client_repository.dart';
import 'package:quickbill/data/repositories/invoice_repository.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';

/// Integration-style round-trip test for backup / restore.
///
/// Strategy: we can't test the file-export + share-sheet path in a unit test
/// (share_plus needs a real platform), but we CAN test the data-layer
/// invariant that matters: after `wipeAll()` + re-inserting from a captured
/// snapshot, all records match the pre-wipe state field-by-field.
///
/// This mirrors what `BackupService.import` does at the file level — it
/// replaces the DB file, which is logically equivalent to wipe + reinsert.
void main() {
  late AppDatabase db;
  late BusinessProfileRepository profileRepo;
  late ClientRepository clientRepo;
  late InvoiceRepository invoiceRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profileRepo = BusinessProfileRepository(db);
    clientRepo = ClientRepository(db);
    invoiceRepo = InvoiceRepository(db);
  });

  tearDown(() async => db.close());

  // Captures the full DB state into a plain map structure so we can compare
  // field-by-field after the wipe+restore cycle.
  Future<
      ({
        BusinessProfile? profile,
        List<Client> clients,
        List<Invoice> invoices,
        List<InvoiceItem> items
      })> snapshot() async {
    final profile = await profileRepo.get();
    final clients = await clientRepo.all();
    final invoices = await invoiceRepo.all();
    final allItems = <InvoiceItem>[];
    for (final inv in invoices) {
      allItems.addAll(await invoiceRepo.itemsFor(inv.id));
    }
    return (
      profile: profile,
      clients: clients,
      invoices: invoices,
      items: allItems
    );
  }

  test('backup/restore round trip preserves all records field-by-field',
      () async {
    // --- Seed initial state ---
    await profileRepo.upsert(BusinessProfilesCompanion.insert(
      businessName: 'Anjali Sharma Design Studio',
      stateCode: '27',
      gstin: const Value('27ABCDE1234F1Z5'),
      isGstRegistered: const Value(true),
      address: const Value('Mumbai'),
      panNumber: const Value('ABCDE1234F'),
      upiId: const Value('anjali@oksbi'),
    ));

    final c1 = await clientRepo.create(
      name: 'Acme Corp',
      stateCode: '29',
      gstin: '29AAACI1234L1ZP',
      address: 'Bengaluru',
      email: 'ap@acme.com',
      phone: '9876543210',
    );
    final c2 = await clientRepo.create(
      name: 'Beta LLC',
      stateCode: '07',
      gstin: null,
      address: null,
      email: null,
      phone: null,
    );

    // 3 invoices with items. Return values are unused — the snapshot below
    // re-reads everything from the DB.
    await invoiceRepo.create(
      invoiceNumber: 'INV/2026-27/0001',
      clientId: c1.id,
      issueDate: DateTime(2026, 7, 14),
      dueDate: DateTime(2026, 8, 13),
      status: 'sent',
      notes: 'First invoice',
      placeOfSupply: '29',
      subtotal: 10000,
      cgstAmount: 0,
      sgstAmount: 0,
      igstAmount: 1800,
      totalAmount: 11800,
      items: const [
        InvoiceItemInput(
            description: 'Design',
            quantity: 1,
            unitPrice: 10000,
            gstRatePercent: 18),
      ],
    );
    await invoiceRepo.create(
      invoiceNumber: 'INV/2026-27/0002',
      clientId: c2.id,
      issueDate: DateTime(2026, 7, 15),
      dueDate: null,
      status: 'draft',
      notes: null,
      placeOfSupply: '07',
      subtotal: 5000,
      cgstAmount: 450,
      sgstAmount: 450,
      igstAmount: 0,
      totalAmount: 5900,
      items: const [
        InvoiceItemInput(
            description: 'Consulting',
            quantity: 5,
            unitPrice: 1000,
            gstRatePercent: 18),
        InvoiceItemInput(
            description: 'Extra',
            hsnSacCode: '998314',
            quantity: 1,
            unitPrice: 0,
            gstRatePercent: 0),
      ],
    );
    await invoiceRepo.create(
      invoiceNumber: 'INV/2026-27/0003',
      clientId: c1.id,
      issueDate: DateTime(2026, 8, 1),
      dueDate: DateTime(2026, 8, 31),
      status: 'paid',
      notes: 'Paid in full',
      placeOfSupply: '29',
      subtotal: 2000,
      cgstAmount: 0,
      sgstAmount: 0,
      igstAmount: 360,
      totalAmount: 2360,
      items: const [
        InvoiceItemInput(
            description: 'Service',
            quantity: 2,
            unitPrice: 1000,
            gstRatePercent: 18),
      ],
    );

    // --- Capture pre-wipe state ---
    final before = await snapshot();
    expect(before.clients.length, 2);
    expect(before.invoices.length, 3);
    expect(before.items.length, 4); // 1 + 2 + 1
    expect(before.profile, isNotNull);

    // --- Wipe (simulates what import does at the file level) ---
    await db.wipeAll();

    // Verify wipe was complete.
    final afterWipe = await snapshot();
    expect(afterWipe.profile, isNull);
    expect(afterWipe.clients, isEmpty);
    expect(afterWipe.invoices, isEmpty);
    expect(afterWipe.items, isEmpty);

    // --- Restore: re-insert from the captured snapshot ---
    // (In production, BackupService.import replaces the DB file. Here we
    // simulate the data-level result: same records in a fresh DB.)
    final p = before.profile!;
    await profileRepo.upsert(BusinessProfilesCompanion.insert(
      businessName: p.businessName,
      stateCode: p.stateCode,
      gstin: Value(p.gstin),
      isGstRegistered: Value(p.isGstRegistered),
      address: Value(p.address),
      panNumber: Value(p.panNumber),
      upiId: Value(p.upiId),
    ));

    // Re-insert clients. Original IDs are preserved by passing them back via
    // a raw insert (the repo's create() generates new UUIDs, so we go direct).
    for (final c in before.clients) {
      await db.into(db.clients).insert(ClientsCompanion.insert(
            id: c.id,
            name: c.name,
            stateCode: c.stateCode,
            gstin: Value(c.gstin),
            address: Value(c.address),
            email: Value(c.email),
            phone: Value(c.phone),
          ));
    }

    for (final inv in before.invoices) {
      await db.into(db.invoices).insert(InvoicesCompanion.insert(
            id: inv.id,
            invoiceNumber: inv.invoiceNumber,
            clientId: inv.clientId,
            issueDate: inv.issueDate,
            dueDate: Value(inv.dueDate),
            status: Value(inv.status),
            notes: Value(inv.notes),
            placeOfSupply: inv.placeOfSupply,
            subtotal: Value(inv.subtotal),
            cgstAmount: Value(inv.cgstAmount),
            sgstAmount: Value(inv.sgstAmount),
            igstAmount: Value(inv.igstAmount),
            totalAmount: Value(inv.totalAmount),
            createdAt: Value(inv.createdAt),
          ));
    }

    for (final it in before.items) {
      await db.into(db.invoiceItems).insert(InvoiceItemsCompanion.insert(
            id: it.id,
            invoiceId: it.invoiceId,
            description: it.description,
            hsnSacCode: Value(it.hsnSacCode),
            quantity: Value(it.quantity),
            unitPrice: Value(it.unitPrice),
            gstRatePercent: Value(it.gstRatePercent),
            lineTotal: Value(it.lineTotal),
          ));
    }

    // --- Assert all records match the pre-export state field-by-field ---
    final after = await snapshot();

    // Profile
    expect(after.profile, isNotNull);
    expect(after.profile!.businessName, before.profile!.businessName);
    expect(after.profile!.gstin, before.profile!.gstin);
    expect(after.profile!.stateCode, before.profile!.stateCode);
    expect(after.profile!.isGstRegistered, before.profile!.isGstRegistered);
    expect(after.profile!.address, before.profile!.address);
    expect(after.profile!.panNumber, before.profile!.panNumber);
    expect(after.profile!.upiId, before.profile!.upiId);

    // Clients
    expect(after.clients.length, before.clients.length);
    for (var i = 0; i < before.clients.length; i++) {
      final a = after.clients[i];
      final b = before.clients[i];
      expect(a.id, b.id);
      expect(a.name, b.name);
      expect(a.gstin, b.gstin);
      expect(a.stateCode, b.stateCode);
      expect(a.address, b.address);
      expect(a.email, b.email);
      expect(a.phone, b.phone);
    }

    // Invoices
    expect(after.invoices.length, before.invoices.length);
    // Sort by invoiceNumber for stable comparison (all() returns by createdAt desc).
    final sortedBefore = [...before.invoices]
      ..sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
    final sortedAfter = [...after.invoices]
      ..sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
    for (var i = 0; i < sortedBefore.length; i++) {
      final a = sortedAfter[i];
      final b = sortedBefore[i];
      expect(a.id, b.id);
      expect(a.invoiceNumber, b.invoiceNumber);
      expect(a.clientId, b.clientId);
      expect(a.issueDate, b.issueDate);
      expect(a.dueDate, b.dueDate);
      expect(a.status, b.status);
      expect(a.notes, b.notes);
      expect(a.placeOfSupply, b.placeOfSupply);
      expect(a.subtotal, b.subtotal);
      expect(a.cgstAmount, b.cgstAmount);
      expect(a.sgstAmount, b.sgstAmount);
      expect(a.igstAmount, b.igstAmount);
      expect(a.totalAmount, b.totalAmount);
    }

    // Items
    expect(after.items.length, before.items.length);
    final sortedItemsBefore = [...before.items]
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedItemsAfter = [...after.items]
      ..sort((a, b) => a.id.compareTo(b.id));
    for (var i = 0; i < sortedItemsBefore.length; i++) {
      final a = sortedItemsAfter[i];
      final b = sortedItemsBefore[i];
      expect(a.id, b.id);
      expect(a.invoiceId, b.invoiceId);
      expect(a.description, b.description);
      expect(a.hsnSacCode, b.hsnSacCode);
      expect(a.quantity, b.quantity);
      expect(a.unitPrice, b.unitPrice);
      expect(a.gstRatePercent, b.gstRatePercent);
      expect(a.lineTotal, b.lineTotal);
    }
  });
}
