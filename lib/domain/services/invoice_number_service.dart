import '../../data/repositories/invoice_repository.dart';

/// Generates sequential invoice numbers per Indian financial year (Apr–Mar).
///
/// Format: `INV/<FY>/####`  e.g. `INV/2026-27/0001`
///
/// The counter is derived from existing rows for the current FY — no separate
/// mutable counter column. This avoids drift / corruption if the user deletes
/// or back-dates invoices.
///
/// The user may override the suggested number on the Invoice Create screen.
class InvoiceNumberService {
  InvoiceNumberService(this._repo);

  final InvoiceRepository _repo;

  /// Returns the suggested next invoice number for the FY containing [at].
  ///
  /// If [at] is null, defaults to DateTime.now().
  Future<String> nextNumber({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final fyStart = _fyStartYear(now);
    final fyInvoices = await _repo.forFinancialYear(fyStart);

    int maxSeq = 0;
    for (final inv in fyInvoices) {
      final seq = _seqFromNumber(inv.invoiceNumber);
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }

    final fyLabel = _fyLabel(fyStart);
    return 'INV/$fyLabel/${(maxSeq + 1).toString().padLeft(4, '0')}';
  }

  /// Returns the calendar year in which the FY *starts*.
  /// FY 2026-27 starts on 1 April 2026 → returns 2026.
  static int _fyStartYear(DateTime date) {
    // Indian FY starts April 1. Jan–Mar belong to the previous FY.
    return date.month >= 4 ? date.year : date.year - 1;
  }

  /// Label for the FY starting [startYear]. 2026 → "2026-27".
  static String _fyLabel(int startYear) {
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
