/// Immutable result of an invoice GST calculation.
///
/// Pure value type — no Flutter or Drift dependencies. Unit-testable.
///
/// v3: includes discount fields. Discount is applied to the subtotal BEFORE
/// tax is calculated — the standard GST-compliant ordering. `taxableAmount`
/// is subtotal minus discount; tax is computed on that; total is taxable +
/// tax.
class GstCalculation {
  final double subtotal;
  final double discountAmount;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  const GstCalculation({
    required this.subtotal,
    this.discountAmount = 0,
    this.taxableAmount = 0,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });

  /// Total tax = CGST + SGST + IGST (whichever are non-zero).
  double get totalTax => cgst + sgst + igst;

  /// True if the seller and buyer are in the same state (intrastate).
  bool get isIntrastate => cgst > 0 || sgst > 0;

  @override
  String toString() =>
      'GstCalculation(subtotal=$subtotal, discount=$discountAmount, '
      'taxable=$taxableAmount, cgst=$cgst, sgst=$sgst, igst=$igst, total=$total)';
}

/// Discount type — flat amount in ₹ or percentage of subtotal.
enum DiscountType { flat, percent }

/// Input for a single line item, used by:
///   - the GST service ([calculateInvoiceGst])
///   - the invoice repository (create/update)
///   - the Invoice Create screen's form state
///
/// [id] is null for newly-added items and present when editing an existing
/// persisted invoice (so the repo can preserve item identity on update).
class InvoiceItemInput {
  final String? id;
  final String description;
  final String? hsnSacCode;
  final double quantity;
  final double unitPrice;
  final double gstRatePercent;

  const InvoiceItemInput({
    this.id,
    required this.description,
    this.hsnSacCode,
    this.quantity = 1,
    this.unitPrice = 0,
    this.gstRatePercent = 0,
  });

  double get lineTotal => quantity * unitPrice;

  InvoiceItemInput copyWith({
    String? id,
    String? description,
    String? hsnSacCode,
    double? quantity,
    double? unitPrice,
    double? gstRatePercent,
  }) {
    return InvoiceItemInput(
      id: id ?? this.id,
      description: description ?? this.description,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRatePercent: gstRatePercent ?? this.gstRatePercent,
    );
  }
}

/// Discount input passed into [calculateInvoiceGst].
class DiscountInput {
  final DiscountType type;
  final double value;

  const DiscountInput({required this.type, required this.value});

  /// Returns 0 for no discount (value <= 0).
  bool get isEmpty => value <= 0;
}
