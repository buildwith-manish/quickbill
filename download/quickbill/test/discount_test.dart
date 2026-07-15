import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';
import 'package:quickbill/domain/services/gst_service.dart';

/// Tests for v3 discount support in [calculateInvoiceGst].
///
/// Discount is applied to the subtotal BEFORE tax. Tax is then recomputed
/// on the post-discount taxable amount. This is the GST-compliant ordering.
void main() {
  group('calculateInvoiceGst with discount', () {
    test('flat discount reduces taxable amount and tax proportionally', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 1,
            unitPrice: 10000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '27',
        discount: const DiscountInput(type: DiscountType.flat, value: 1000),
      );

      // Subtotal = 10000 (unchanged)
      expect(result.subtotal, 10000);
      // Discount = 1000
      expect(result.discountAmount, 1000);
      // Taxable = 9000
      expect(result.taxableAmount, 9000);
      // Tax = 9000 * 0.18 = 1620 (was 1800 without discount)
      expect(result.totalTax, closeTo(1620, 1e-9));
      // Intrastate split
      expect(result.cgst, closeTo(810, 1e-9));
      expect(result.sgst, closeTo(810, 1e-9));
      expect(result.igst, 0);
      // Total = taxable + tax = 9000 + 1620 = 10620
      expect(result.total, closeTo(10620, 1e-9));
    });

    test('percent discount (10% on ₹10000) reduces taxable to ₹9000', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 1,
            unitPrice: 10000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '27',
        discount: const DiscountInput(type: DiscountType.percent, value: 10),
      );

      expect(result.subtotal, 10000);
      expect(result.discountAmount, closeTo(1000, 1e-9));
      expect(result.taxableAmount, closeTo(9000, 1e-9));
      expect(result.totalTax, closeTo(1620, 1e-9));
      expect(result.total, closeTo(10620, 1e-9));
    });

    test('no discount returns identical results to v1/v2 calculation', () {
      final withoutDiscount = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 2,
            unitPrice: 5000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '27',
      );

      final withNullDiscount = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 2,
            unitPrice: 5000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '27',
        discount: null,
      );

      // Both should produce identical results — backward compatible.
      expect(withoutDiscount.subtotal, withNullDiscount.subtotal);
      expect(withoutDiscount.totalTax, withNullDiscount.totalTax);
      expect(withoutDiscount.total, withNullDiscount.total);
      // No discount → discountAmount = 0, taxableAmount = subtotal
      expect(withNullDiscount.discountAmount, 0);
      expect(withNullDiscount.taxableAmount, withNullDiscount.subtotal);
    });

    test('discount with value 0 is treated as no discount', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 1,
            unitPrice: 10000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '27',
        discount: const DiscountInput(type: DiscountType.flat, value: 0),
      );

      expect(result.discountAmount, 0);
      expect(result.taxableAmount, 10000);
      expect(result.totalTax, closeTo(1800, 1e-9));
      expect(result.total, closeTo(11800, 1e-9));
    });

    test('flat discount larger than subtotal is clamped to subtotal', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 1,
            unitPrice: 1000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '27',
        discount: const DiscountInput(type: DiscountType.flat, value: 5000),
      );

      // Discount clamped to subtotal — taxable can't go negative.
      expect(result.discountAmount, 1000);
      expect(result.taxableAmount, 0);
      expect(result.totalTax, 0);
      expect(result.total, 0);
    });

    test('interstate discount (IGST case)', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 1,
            unitPrice: 10000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '29',
        discount: const DiscountInput(type: DiscountType.percent, value: 5),
      );

      expect(result.subtotal, 10000);
      expect(result.discountAmount, closeTo(500, 1e-9));
      expect(result.taxableAmount, closeTo(9500, 1e-9));
      // IGST = 9500 * 0.18 = 1710
      expect(result.igst, closeTo(1710, 1e-9));
      expect(result.cgst, 0);
      expect(result.sgst, 0);
      expect(result.total, closeTo(11210, 1e-9));
    });

    test('discount on multi-item invoice preserves per-line GST proportions', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'A',
            quantity: 1,
            unitPrice: 6000,
            gstRatePercent: 18,
          ),
          InvoiceItemInput(
            description: 'B',
            quantity: 1,
            unitPrice: 4000,
            gstRatePercent: 5,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '27',
        discount: const DiscountInput(type: DiscountType.percent, value: 10),
      );

      // Subtotal = 10000
      expect(result.subtotal, 10000);
      // Discount = 1000 (10% of 10000)
      expect(result.discountAmount, closeTo(1000, 1e-9));
      // Taxable = 9000
      expect(result.taxableAmount, closeTo(9000, 1e-9));
      // Original tax = 6000*0.18 + 4000*0.05 = 1080 + 200 = 1280
      // Scaled tax = 1280 * (9000/10000) = 1152
      expect(result.totalTax, closeTo(1152, 1e-9));
      // Intrastate split
      expect(result.cgst, closeTo(576, 1e-9));
      expect(result.sgst, closeTo(576, 1e-9));
      // Total = 9000 + 1152 = 10152
      expect(result.total, closeTo(10152, 1e-9));
    });
  });

  group('DiscountInput', () {
    test('isEmpty returns true for zero value', () {
      const d = DiscountInput(type: DiscountType.flat, value: 0);
      expect(d.isEmpty, isTrue);
    });

    test('isEmpty returns true for negative value', () {
      const d = DiscountInput(type: DiscountType.percent, value: -5);
      expect(d.isEmpty, isTrue);
    });

    test('isEmpty returns false for positive value', () {
      const d = DiscountInput(type: DiscountType.flat, value: 100);
      expect(d.isEmpty, isFalse);
    });
  });
}
