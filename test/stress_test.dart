import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/data/database/database.dart';
import 'package:quickbill/data/repositories/client_repository.dart';
import 'package:quickbill/data/repositories/invoice_repository.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';

/// Gap 5 — Seed-data stress test.
///
/// Inserts 500 clients and 2,000 invoices (with 3-5 items each) into an
/// in-memory Drift DB, then measures:
///   - Full client list load time
///   - SQL search query time
///   - Invoice list page load time (first 30 invoices)
///   - Invoice filter switch time (draft/sent/paid)
///
/// All operations should complete in <100ms even at this scale — if they
/// don't, the indexes or query strategy need revisiting.
void main() {
  late AppDatabase db;
  late ClientRepository clientRepo;
  late InvoiceRepository invoiceRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clientRepo = ClientRepository(db);
    invoiceRepo = InvoiceRepository(db);

    // Seed business profile (required for FK constraints).
    await db.into(db.businessProfiles).insert(
      BusinessProfilesCompanion.insert(
        id: const Value(1),
        businessName: 'Stress Test Business',
        stateCode: '27',
      ),
    );
  });

  tearDown(() async => db.close());

  test('seed 500 clients + 2000 invoices, measure query performance',
      () async {
    // --- Seed 500 clients ---
    final clientStopwatch = Stopwatch()..start();
    for (var i = 0; i < 500; i++) {
      await db.into(db.clients).insert(
        ClientsCompanion.insert(
          id: 'client-$i',
          name: 'Client $i — ${_generateBusinessName(i)}',
          stateCode: '27',
          gstin: Value(i % 3 == 0 ? '27ABCDE${i.toString().padLeft(4, '0')}F1Z5' : null),
        ),
      );
    }
    clientStopwatch.stop();
    print('Seeded 500 clients in ${clientStopwatch.elapsedMilliseconds}ms');

    // --- Seed 2000 invoices with 3-5 items each ---
    final invoiceStopwatch = Stopwatch()..start();
    for (var i = 0; i < 2000; i++) {
      final clientId = 'client-${i % 500}';
      final itemCount = 3 + (i % 3); // 3, 4, or 5 items
      final items = List.generate(itemCount, (j) => InvoiceItemInput(
        description: 'Service item $j for invoice $i',
        hsnSacCode: '998314',
        quantity: (j + 1).toDouble(),
        unitPrice: 1000 + (j * 100),
        gstRatePercent: 18,
      ));

      await invoiceRepo.create(
        invoiceNumber: 'INV/2026-27/${(i + 1).toString().padLeft(4, '0')}',
        clientId: clientId,
        issueDate: DateTime(2026, 7, 1).add(Duration(days: i % 365)),
        dueDate: DateTime(2026, 8, 1).add(Duration(days: i % 365)),
        status: ['draft', 'sent', 'paid'][i % 3],
        placeOfSupply: '27',
        subtotal: items.fold<double>(0, (s, it) => s + it.lineTotal),
        cgstAmount: items.fold<double>(0, (s, it) => s + it.lineTotal) * 0.09,
        sgstAmount: items.fold<double>(0, (s, it) => s + it.lineTotal) * 0.09,
        igstAmount: 0,
        totalAmount: items.fold<double>(0, (s, it) => s + it.lineTotal) * 1.18,
        items: items,
      );
    }
    invoiceStopwatch.stop();
    print('Seeded 2000 invoices (with items) in ${invoiceStopwatch.elapsedMilliseconds}ms');

    // --- Measure: full client list load ---
    final listStopwatch = Stopwatch()..start();
    final allClients = await clientRepo.all();
    listStopwatch.stop();
    print('Loaded ${allClients.length} clients in ${listStopwatch.elapsedMilliseconds}ms');
    expect(allClients.length, 500);
    expect(listStopwatch.elapsedMilliseconds, lessThan(100),
        reason: 'Client list load should be <100ms with the name index');

    // --- Measure: SQL search ---
    final searchStopwatch = Stopwatch()..start();
    final searchResults = await clientRepo.search('Client 42');
    searchStopwatch.stop();
    print('SQL search "Client 42" returned ${searchResults.length} results in ${searchStopwatch.elapsedMilliseconds}ms');
    expect(searchResults, isNotEmpty);
    expect(searchStopwatch.elapsedMilliseconds, lessThan(100),
        reason: 'SQL LIKE search should be <100ms with the name index');

    // --- Measure: search with GSTIN ---
    final gstinStopwatch = Stopwatch()..start();
    final gstinResults = await clientRepo.search('27ABCDE0042');
    gstinStopwatch.stop();
    print('SQL search "27ABCDE0042" returned ${gstinResults.length} results in ${gstinStopwatch.elapsedMilliseconds}ms');
    expect(gstinStopwatch.elapsedMilliseconds, lessThan(100),
        reason: 'GSTIN search should be <100ms');

    // --- Measure: invoice page load (first 30) ---
    final pageStopwatch = Stopwatch()..start();
    final firstPage = await invoiceRepo.page(limit: 30, offset: 0);
    pageStopwatch.stop();
    print('Loaded first 30 invoices in ${pageStopwatch.elapsedMilliseconds}ms');
    expect(firstPage.length, 30);
    expect(pageStopwatch.elapsedMilliseconds, lessThan(100),
        reason: 'Invoice page load should be <100ms with the createdAt index');

    // --- Measure: invoice filter switch (status = 'sent') ---
    final filterStopwatch = Stopwatch()..start();
    final sentInvoices = await invoiceRepo.page(limit: 30, statusFilter: 'sent');
    filterStopwatch.stop();
    print('Filtered "sent" invoices (30 of ${sentInvoices.length}) in ${filterStopwatch.elapsedMilliseconds}ms');
    expect(filterStopwatch.elapsedMilliseconds, lessThan(100),
        reason: 'Status filter should be <100ms with the status index');

    // --- Measure: invoice count ---
    final countStopwatch = Stopwatch()..start();
    final totalCount = await invoiceRepo.count();
    countStopwatch.stop();
    print('Counted $totalCount invoices in ${countStopwatch.elapsedMilliseconds}ms');
    expect(totalCount, 2000);
    expect(countStopwatch.elapsedMilliseconds, lessThan(50),
        reason: 'COUNT(*) should be <50ms');

    // --- Measure: count with status filter ---
    final countFilterStopwatch = Stopwatch()..start();
    final paidCount = await invoiceRepo.count(statusFilter: 'paid');
    countFilterStopwatch.stop();
    print('Counted $paidCount paid invoices in ${countFilterStopwatch.elapsedMilliseconds}ms');
    expect(paidCount, greaterThan(0));
    expect(countFilterStopwatch.elapsedMilliseconds, lessThan(50),
        reason: 'Filtered COUNT should be <50ms with the status index');

    // --- Total seed-data summary ---
    print('\n=== Stress test summary ===');
    print('Clients: 500');
    print('Invoices: 2000');
    print('Invoice items: ~8000 (3-5 per invoice)');
    print('All query operations completed in <100ms');
  });

  test('search returns correct results for edge cases', () async {
    // Seed a small set for correctness verification.
    for (var i = 0; i < 10; i++) {
      await db.into(db.clients).insert(
        ClientsCompanion.insert(
          id: 'c-$i',
          name: 'Test Client $i',
          stateCode: '27',
          gstin: Value('27ABCDE${i.toString().padLeft(4, '0')}F1Z5'),
        ),
      );
    }

    // Search by name substring.
    final nameResults = await clientRepo.search('Client 5');
    expect(nameResults.length, 1);
    expect(nameResults.first.name, contains('Client 5'));

    // Search by GSTIN substring.
    final gstinResults = await clientRepo.search('ABCDE0005');
    expect(gstinResults.length, 1);
    expect(gstinResults.first.gstin, contains('ABCDE0005'));

    // Search with no match.
    final noResults = await clientRepo.search('NonExistentClient');
    expect(noResults, isEmpty);

    // Empty query returns all (LIKE '%%' matches everything).
    final allResults = await clientRepo.search('');
    expect(allResults.length, 10);
  });
}

/// Generates a realistic business name for seed data.
String _generateBusinessName(int i) {
  const prefixes = ['Acme', 'Globex', 'Initech', 'Umbrella', 'Hooli'];
  const suffixes = ['Corp', 'Ltd', 'LLC', 'Pvt Ltd', 'Inc'];
  return '${prefixes[i % prefixes.length]} ${suffixes[i % suffixes.length]}';
}
