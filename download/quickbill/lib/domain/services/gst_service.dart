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
///
/// v3: optional [discount] is applied to the subtotal BEFORE tax. This is
/// the GST-compliant ordering — tax is always computed on the post-discount
/// taxable amount. When [discount] is null or empty, behavior is identical
/// to the original v1/v2 calculation (backward compatible).
GstCalculation calculateInvoiceGst({
  required List<InvoiceItemInput> items,
  required String sellerStateCode,
  required String placeOfSupplyStateCode,
  DiscountInput? discount,
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

  // v3: apply discount BEFORE tax. The discount reduces the taxable base.
  // We re-compute tax on the discounted amount so CGST/SGST/IGST are
  // correct per GST rules.
  double discountAmount = 0;
  double taxableAmount = subtotal;

  if (discount != null && !discount.isEmpty) {
    if (discount.type == DiscountType.flat) {
      discountAmount = discount.value;
    } else {
      // percent
      discountAmount = subtotal * (discount.value / 100);
    }
    // Never allow negative taxable amount.
    if (discountAmount > subtotal) discountAmount = subtotal;
    taxableAmount = subtotal - discountAmount;

    // Re-compute tax on the taxable amount. We scale the original totalTax
    // by the ratio (taxable / subtotal) so per-line GST rates are preserved
    // proportionally. This matches how GST actually works on discounted
    // invoices.
    if (subtotal > 0) {
      totalTax = totalTax * (taxableAmount / subtotal);
    } else {
      totalTax = 0;
    }
  }

  final cgst = isIntrastate ? totalTax / 2 : 0.0;
  final sgst = isIntrastate ? totalTax / 2 : 0.0;
  final igst = isIntrastate ? 0.0 : totalTax;

  return GstCalculation(
    subtotal: subtotal,
    discountAmount: discountAmount,
    taxableAmount: taxableAmount,
    cgst: cgst,
    sgst: sgst,
    igst: igst,
    total: taxableAmount + totalTax,
  );
}
