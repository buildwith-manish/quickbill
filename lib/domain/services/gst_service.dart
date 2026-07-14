import '../models/gst_calculation.dart';

/// Pure GST calculation logic — the single most important business rule in
/// the app. No Flutter / Drift dependencies so it is trivially unit-testable.
///
/// Rule:
///   seller state == buyer state  →  intrastate  →  CGST + SGST (rate/2 each)
///   seller state != buyer state  →  interstate  →  IGST (full rate)
///
/// Per-line-item calculation, then aggregate. The seller's `isGstRegistered`
/// flag is handled at the call site — if false, callers pass a 0% rate for
/// every item (or simply skip calling this and use a zero-tax GstCalculation).
GstCalculation calculateInvoiceGst({
  required List<InvoiceItemInput> items,
  required String sellerStateCode,
  required String placeOfSupplyStateCode,
}) {
  double subtotal = 0;
  double totalTax = 0;

  final isIntrastate = sellerStateCode == placeOfSupplyStateCode;

  for (final item in items) {
    final lineTotal = item.quantity * item.unitPrice;
    final taxAmount = lineTotal * (item.gstRatePercent / 100);
    subtotal += lineTotal;
    totalTax += taxAmount;
  }

  final cgst = isIntrastate ? totalTax / 2 : 0.0;
  final sgst = isIntrastate ? totalTax / 2 : 0.0;
  final igst = isIntrastate ? 0.0 : totalTax;

  return GstCalculation(
    subtotal: subtotal,
    cgst: cgst,
    sgst: sgst,
    igst: igst,
    total: subtotal + totalTax,
  );
}
