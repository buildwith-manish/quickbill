import 'package:drift/drift.dart';

import '../../data/database/database.dart';
import '../../data/repositories/invoice_repository.dart';

/// Generates sequential invoice numbers per Indian financial year (Apr–Mar).
///
/// Format: `INV/<FY>/####`  e.g. `INV/2026-27/0001`
///
/// v2 strategy: the counter is persisted in [SeqCounters] keyed by FY label.
/// When the user creates a new invoice:
///   1. We read `lastSeq` for the current FY (default 0 if missing).
///   2. We increment + format.
///   3. On save, [InvoiceRepository] bumps the counter inside the same
///      transaction as the invoice insert — atomic, no drift.
///
/// We also reconcile against existing invoice rows on `nextNumber()` to
/// avoid suggesting a number lower than an existing manual override.
///
/// The user may still override the suggested number on the Invoice Create
/// screen — the counter is bumped to max(suggested, manual) on save.
class InvoiceNumberService {
  InvoiceNumberService(this._db, this._repo);

  final AppDatabase _db;
  final InvoiceRepository _repo;

  /// Returns the suggested next invoice number for the FY containing [at].
  /// If [at] is null, defaults to DateTime.now().
  ///
  /// v3: [prefix] defaults to 'INV' for invoices. Pass 'QTN' for quotations
  /// — they get their own counter sequence (QTN/2026-27/0001).
  Future<String> nextNumber({DateTime? at, String prefix = 'INV'}) async {
    final now = at ?? DateTime.now();
    final fyStart = fyStartYear(now);
    final label = fyLabel(fyStart);
    final counterKey = '$prefix-$label';

    // Counter-based suggestion.
    final counterRow = await (_db.select(_db.seqCounters)
          ..where((t) => t.key.equals(counterKey)))
        .getSingleOrNull();
    final counterSeq = counterRow?.lastSeq ?? 0;

    // Reconcile against existing rows — handles manual overrides and the
    // case where the counter table is empty (fresh install + backup restore).
    final fyInvoices = await _repo.forFinancialYear(fyStart);
    int maxExisting = 0;
    for (final inv in fyInvoices) {
      // Only count invoices matching this prefix (INV vs QTN).
      if (!inv.invoiceNumber.startsWith('$prefix/')) continue;
      final seq = _seqFromNumber(inv.invoiceNumber);
      if (seq != null && seq > maxExisting) maxExisting = seq;
    }

    final next = (counterSeq > maxExisting ? counterSeq : maxExisting) + 1;
    final seqStr = next.toString().padLeft(4, '0');
    return '$prefix/$label/$seqStr';
  }

  /// Bumps the persisted counter for [fyLabel] to at least [seq].
  /// Called by [InvoiceRepository] inside the save transaction.
  Future<void> bumpCounter(String fyLabel, int seq) async {
    final existing = await (_db.select(_db.seqCounters)
          ..where((t) => t.key.equals(fyLabel)))
        .getSingleOrNull();
    final newSeq =
        (existing?.lastSeq ?? 0) > seq ? (existing?.lastSeq ?? 0) : seq;
    await _db.into(_db.seqCounters).insertOnConflictUpdate(
          SeqCountersCompanion.insert(
            key: fyLabel,
            lastSeq: Value(newSeq),
          ),
        );
  }

  /// Returns the calendar year in which the FY *starts*.
  /// FY 2026-27 starts on 1 April 2026 → returns 2026.
  static int fyStartYear(DateTime date) {
    // Indian FY starts April 1. Jan–Mar belong to the previous FY.
    return date.month >= 4 ? date.year : date.year - 1;
  }

  /// Label for the FY starting [startYear]. 2026 → "2026-27".
  static String fyLabel(int startYear) {
    final a = startYear.toString();
    final b = (startYear + 1) % 100;
    return '$a-${b.toString().padLeft(2, '0')}';
  }

  /// Parses the 4-digit sequence out of "INV/2026-27/0042" → 42.
  /// Returns null if the format doesn't match.
  static int? _seqFromNumber(String number) {
    final parts = number.split('/');
    if (parts.length != 3) return null;
    return int.tryParse(parts[2]);
  }
}
