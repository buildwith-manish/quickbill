import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';
import 'package:quickbill/domain/services/gst_service.dart';

void main() {
  group('calculateInvoiceGst', () {
    test('intrastate: 18% on ₹10,000 → CGST ₹900 + SGST ₹900', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Design services',
            quantity: 1,
            unitPrice: 10000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27', // Maharashtra
        placeOfSupplyStateCode: '27', // same → intrastate
      );

      expect(result.subtotal, 10000);
      expect(result.cgst, 900);
      expect(result.sgst, 900);
      expect(result.igst, 0);
      expect(result.totalTax, 1800);
      expect(result.total, 11800);
      expect(result.isIntrastate, isTrue);
    });

    test('interstate: 18% on ₹10,000 → IGST ₹1,800', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Design services',
            quantity: 1,
            unitPrice: 10000,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27', // Maharashtra
        placeOfSupplyStateCode: '29', // Karnataka → interstate
      );

      expect(result.subtotal, 10000);
      expect(result.cgst, 0);
      expect(result.sgst, 0);
      expect(result.igst, 1800);
      expect(result.totalTax, 1800);
      expect(result.total, 11800);
      expect(result.isIntrastate, isFalse);
    });

    test('multiple line items aggregate correctly (intrastate)', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Item A',
            quantity: 2,
            unitPrice: 5000,
            gstRatePercent: 18,
          ),
          InvoiceItemInput(
            description: 'Item B',
            quantity: 1,
            unitPrice: 3000,
            gstRatePercent: 12,
          ),
          InvoiceItemInput(
            description: 'Item C',
            quantity: 5,
            unitPrice: 200,
            gstRatePercent: 0,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      // Subtotal = 2*5000 + 1*3000 + 5*200 = 10000 + 3000 + 1000 = 14000
      expect(result.subtotal, 14000);
      // Tax = 10000*0.18 + 3000*0.12 + 1000*0 = 1800 + 360 = 2160
      expect(result.totalTax, 2160);
      // Intrastate → split: CGST = SGST = 1080
      expect(result.cgst, 1080);
      expect(result.sgst, 1080);
      expect(result.igst, 0);
      expect(result.total, 16160);
    });

    test('multiple line items aggregate correctly (interstate)', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Item A',
            quantity: 2,
            unitPrice: 5000,
            gstRatePercent: 18,
          ),
          InvoiceItemInput(
            description: 'Item B',
            quantity: 1,
            unitPrice: 3000,
            gstRatePercent: 12,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '33',
      );

      expect(result.subtotal, 13000);
      expect(result.totalTax, 2160);
      expect(result.cgst, 0);
      expect(result.sgst, 0);
      expect(result.igst, 2160);
      expect(result.total, 15160);
    });

    test('zero-rate items produce no tax', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Exempt item',
            quantity: 1,
            unitPrice: 5000,
            gstRatePercent: 0,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      expect(result.subtotal, 5000);
      expect(result.cgst, 0);
      expect(result.sgst, 0);
      expect(result.igst, 0);
      expect(result.total, 5000);
    });

    test('empty items list returns zero everything', () {
      final result = calculateInvoiceGst(
        items: const [],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      expect(result.subtotal, 0);
      expect(result.cgst, 0);
      expect(result.sgst, 0);
      expect(result.igst, 0);
      expect(result.total, 0);
    });

    test('28% slab — top rate', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Goods',
            quantity: 1,
            unitPrice: 1000,
            gstRatePercent: 28,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      expect(result.subtotal, 1000);
      expect(result.cgst, 140);
      expect(result.sgst, 140);
      expect(result.total, 1280);
    });

    test('5% slab — low rate (intrastate)', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Goods',
            quantity: 1,
            unitPrice: 1000,
            gstRatePercent: 5,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      expect(result.subtotal, 1000);
      expect(result.cgst, 25);
      expect(result.sgst, 25);
      expect(result.total, 1050);
    });
  });

  group('GST rounding edge cases', () {
    /// Item price ₹99.995 × qty 3 = ₹299.985 line total.
    /// 18% GST on 299.985 = 53.9973 tax.
    /// Intrastate: CGST = SGST = 53.9973 / 2 = 26.99865 each.
    ///
    /// The current [calculateInvoiceGst] implementation does NOT round to
    /// 2 decimals internally — it returns raw doubles. This is deliberate:
    /// rounding is deferred to the presentation layer (PDF / on-screen
    /// currency formatter). These tests document that contract and assert
    /// the values sum correctly with no paise lost vs line-by-line calc.
    test('3-decimal line total (₹99.995 × 3 @ 18%) — intrastate', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 3,
            unitPrice: 99.995,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      // subtotal = 3 * 99.995 = 299.985
      expect(result.subtotal, closeTo(299.985, 1e-9));

      // totalTax = 299.985 * 0.18 = 53.9973
      final expectedTax = 299.985 * 0.18;
      expect(result.totalTax, closeTo(expectedTax, 1e-9));

      // CGST + SGST each = half the tax
      expect(result.cgst, closeTo(expectedTax / 2, 1e-9));
      expect(result.sgst, closeTo(expectedTax / 2, 1e-9));
      expect(result.igst, 0);

      // Total = subtotal + totalTax
      expect(result.total, closeTo(result.subtotal + result.totalTax, 1e-9));

      // CRITICAL INVARIANT: CGST + SGST + IGST must equal totalTax exactly
      // (no paise lost or gained in the split).
      expect(result.cgst + result.sgst + result.igst,
          closeTo(result.totalTax, 1e-9));
    });

    test('3-decimal line total (₹99.995 × 3 @ 18%) — interstate', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 3,
            unitPrice: 99.995,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '27',
        placeOfSupplyStateCode: '29',
      );

      expect(result.subtotal, closeTo(299.985, 1e-9));
      final expectedTax = 299.985 * 0.18;
      expect(result.igst, closeTo(expectedTax, 1e-9));
      expect(result.cgst, 0);
      expect(result.sgst, 0);
      expect(result.total, closeTo(result.subtotal + result.totalTax, 1e-9));
    });

    test('multiple 3-decimal items aggregate with no paise drift', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'A',
            quantity: 3,
            unitPrice: 99.995,
            gstRatePercent: 18,
          ),
          InvoiceItemInput(
            description: 'B',
            quantity: 7,
            unitPrice: 33.333,
            gstRatePercent: 12,
          ),
          InvoiceItemInput(
            description: 'C',
            quantity: 1,
            unitPrice: 0.5,
            gstRatePercent: 28,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      // Recompute line-by-line and compare.
      final lineA = 3 * 99.995;
      final lineB = 7 * 33.333;
      final lineC = 1 * 0.5;
      final expectedSubtotal = lineA + lineB + lineC;
      final expectedTax = lineA * 0.18 + lineB * 0.12 + lineC * 0.28;

      expect(result.subtotal, closeTo(expectedSubtotal, 1e-9));
      expect(result.totalTax, closeTo(expectedTax, 1e-9));
      expect(result.cgst, closeTo(expectedTax / 2, 1e-9));
      expect(result.sgst, closeTo(expectedTax / 2, 1e-9));
      expect(result.igst, 0);

      // Total invariant.
      expect(result.total, closeTo(result.subtotal + result.totalTax, 1e-9));
      expect(result.cgst + result.sgst + result.igst,
          closeTo(result.totalTax, 1e-9));
    });

    test('12% on ₹100 (round number) — intrastate, halves are exact', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 1,
            unitPrice: 100,
            gstRatePercent: 12,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      expect(result.subtotal, 100);
      expect(result.totalTax, 12);
      expect(result.cgst, 6);
      expect(result.sgst, 6);
      expect(result.total, 112);
    });

    test('18% on ₹1000.01 (1 paise edge) — intrastate, halves are exact', () {
      final result = calculateInvoiceGst(
        items: const [
          InvoiceItemInput(
            description: 'Service',
            quantity: 1,
            unitPrice: 1000.01,
            gstRatePercent: 18,
          ),
        ],
        sellerStateCode: '07',
        placeOfSupplyStateCode: '07',
      );

      // 1000.01 * 0.18 = 180.0018 — produces 4 decimals.
      // Halves: 90.0009 each.
      expect(result.subtotal, 1000.01);
      expect(result.totalTax, closeTo(180.0018, 1e-9));
      expect(result.cgst, closeTo(90.0009, 1e-9));
      expect(result.sgst, closeTo(90.0009, 1e-9));
      // The split must be exact: no paise lost in CGST+SGST vs totalTax.
      expect(result.cgst + result.sgst, closeTo(result.totalTax, 1e-9));
    });
  });
}
