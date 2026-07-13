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
}
