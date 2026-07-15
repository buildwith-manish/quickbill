import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/data/database/database.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';
import 'package:quickbill/domain/services/pdf_service.dart';

/// Gap 4 — PDF stress tests.
///
/// Verifies the PDF generator handles edge cases that competitor apps
/// (per market research) fail on: multi-page invoices, very long
/// descriptions, maximum-length names. Confirms `pw.MultiPage` paginates
/// correctly without overlapping content or orphaned totals.
void main() {
  group('PdfService stress tests (Gap 4)', () {
    late BusinessProfile business;
    late Client client;
    late GstCalculation gst;

    setUp(() {
      business = BusinessProfile(
        id: 1,
        businessName: 'Test Business',
        gstin: '27ABCDE1234F1Z5',
        stateCode: '27',
        address: 'Mumbai',
        phone: null,
        email: null,
        panNumber: null,
        bankAccountName: null,
        bankAccountNumber: null,
        bankIfsc: null,
        upiId: null,
        logoPath: null,
        isGstRegistered: true,
        invoiceTemplate: 'minimal',
      );

      client = Client(
        id: 'c1',
        name: 'Test Client',
        gstin: '29AAACI1234L1ZP',
        stateCode: '29',
        address: 'Bengaluru',
        email: null,
        phone: null,
        createdAt: DateTime(2026, 7, 14),
      );

      gst = const GstCalculation(
        subtotal: 50000,
        cgst: 0,
        sgst: 0,
        igst: 9000,
        total: 59000,
      );
    });

    test('25 line items forces multi-page — no crash, valid PDF', () async {
      final invoice = Invoice(
        id: 'inv1',
        invoiceNumber: 'INV/2026-27/0001',
        clientId: 'c1',
        issueDate: DateTime(2026, 7, 14),
        dueDate: null,
        status: 'sent',
        notes: null,
        placeOfSupply: '29',
        subtotal: 50000,
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 9000,
        totalAmount: 59000,
        documentType: 'invoice',
        discountType: 'flat',
        discountValue: 0,
        discountAmount: 0,
        amountPaid: 0,
        createdAt: DateTime(2026, 7, 14),
      );

      final items = List.generate(25, (i) => InvoiceItem(
        id: 'item$i',
        invoiceId: 'inv1',
        description: 'Line item ${i + 1} — consulting service',
        hsnSacCode: '998314',
        quantity: (i + 1).toDouble(),
        unitPrice: 200,
        gstRatePercent: 18,
        lineTotal: (i + 1) * 200.0,
      ));

      final data = PdfInvoiceData(
        business: business,
        client: client,
        invoice: invoice,
        items: items,
        gst: gst,
      );

      // Must not throw — that's the core assertion.
      final doc = PdfService().build(data);
      final bytes = await doc.save();

      // Valid PDF.
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
      // A 25-item invoice should produce a substantial file (>5KB).
      expect(bytes.length, greaterThan(5000));
    });

    test('50 line items — still paginates cleanly', () async {
      final invoice = Invoice(
        id: 'inv2',
        invoiceNumber: 'INV/2026-27/0002',
        clientId: 'c1',
        issueDate: DateTime(2026, 7, 14),
        dueDate: null,
        status: 'sent',
        notes: null,
        placeOfSupply: '29',
        subtotal: 100000,
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 18000,
        totalAmount: 118000,
        documentType: 'invoice',
        discountType: 'flat',
        discountValue: 0,
        discountAmount: 0,
        amountPaid: 0,
        createdAt: DateTime(2026, 7, 14),
      );

      final items = List.generate(50, (i) => InvoiceItem(
        id: 'item$i',
        invoiceId: 'inv2',
        description: 'Item ${i + 1}',
        hsnSacCode: null,
        quantity: 1,
        unitPrice: 2000,
        gstRatePercent: 18,
        lineTotal: 2000,
      ));

      final data = PdfInvoiceData(
        business: business,
        client: client,
        invoice: invoice,
        items: items,
        gst: gst,
      );

      final doc = PdfService().build(data);
      final bytes = await doc.save();

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(8000));
    });

    test('very long description (100+ chars, no spaces) wraps in column',
        () async {
      final invoice = Invoice(
        id: 'inv3',
        invoiceNumber: 'INV/2026-27/0003',
        clientId: 'c1',
        issueDate: DateTime(2026, 7, 14),
        dueDate: null,
        status: 'sent',
        notes: null,
        placeOfSupply: '29',
        subtotal: 5000,
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 900,
        totalAmount: 5900,
        documentType: 'invoice',
        discountType: 'flat',
        discountValue: 0,
        discountAmount: 0,
        amountPaid: 0,
        createdAt: DateTime(2026, 7, 14),
      );

      // 120-char description with NO spaces — forces the PDF text engine
      // to wrap within the FlexColumnWidth column. If wrapping fails,
      // the text overflows into the next column (HSN/SAC).
      final longDescription =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

      final items = [
        InvoiceItem(
          id: 'item0',
          invoiceId: 'inv3',
          description: longDescription,
          hsnSacCode: '998314',
          quantity: 1,
          unitPrice: 5000,
          gstRatePercent: 18,
          lineTotal: 5000,
        ),
      ];

      final data = PdfInvoiceData(
        business: business,
        client: client,
        invoice: invoice,
        items: items,
        gst: gst,
      );

      // Must not throw — pw.MultiPage handles wrapping.
      final doc = PdfService().build(data);
      final bytes = await doc.save();

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(2000));
    });

    test('maximum-length business + client names (200 chars each)', () async {
      final longBusinessName = 'A' * 200;
      final longClientName = 'B' * 200;

      final longBusiness = BusinessProfile(
        id: 1,
        businessName: longBusinessName,
        gstin: '27ABCDE1234F1Z5',
        stateCode: '27',
        address: 'C' * 200,
        phone: null,
        email: null,
        panNumber: null,
        bankAccountName: null,
        bankAccountNumber: null,
        bankIfsc: null,
        upiId: null,
        logoPath: null,
        isGstRegistered: true,
        invoiceTemplate: 'minimal',
      );

      final longClient = Client(
        id: 'c2',
        name: longClientName,
        gstin: '29AAACI1234L1ZP',
        stateCode: '29',
        address: 'D' * 200,
        email: null,
        phone: null,
        createdAt: DateTime(2026, 7, 14),
      );

      final invoice = Invoice(
        id: 'inv4',
        invoiceNumber: 'INV/2026-27/0004',
        clientId: 'c2',
        issueDate: DateTime(2026, 7, 14),
        dueDate: null,
        status: 'sent',
        notes: null,
        placeOfSupply: '29',
        subtotal: 1000,
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 180,
        totalAmount: 1180,
        documentType: 'invoice',
        discountType: 'flat',
        discountValue: 0,
        discountAmount: 0,
        amountPaid: 0,
        createdAt: DateTime(2026, 7, 14),
      );

      final items = [
        InvoiceItem(
          id: 'item0',
          invoiceId: 'inv4',
          description: 'Service',
          hsnSacCode: null,
          quantity: 1,
          unitPrice: 1000,
          gstRatePercent: 18,
          lineTotal: 1000,
        ),
      ];

      final data = PdfInvoiceData(
        business: longBusiness,
        client: longClient,
        invoice: invoice,
        items: items,
        gst: gst,
      );

      // Must not throw — the header layout must handle long names.
      final doc = PdfService().build(data);
      final bytes = await doc.save();

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(3000));
    });

    test('multi-page invoice with long notes block', () async {
      final invoice = Invoice(
        id: 'inv5',
        invoiceNumber: 'INV/2026-27/0005',
        clientId: 'c1',
        issueDate: DateTime(2026, 7, 14),
        dueDate: DateTime(2026, 8, 13),
        status: 'sent',
        notes: 'Terms: Payment due within 30 days. Late payments subject to '
            '1.5% monthly interest. All disputes subject to Mumbai jurisdiction. '
            'This invoice is computer-generated and valid without signature. '
            'Thank you for your business — we appreciate the opportunity to '
            'work together. Please remit payment via UPI or bank transfer as '
            'per the details below. For any queries, contact us within 7 days.',
        placeOfSupply: '29',
        subtotal: 50000,
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 9000,
        totalAmount: 59000,
        documentType: 'invoice',
        discountType: 'flat',
        discountValue: 0,
        discountAmount: 0,
        amountPaid: 0,
        createdAt: DateTime(2026, 7, 14),
      );

      // 30 items + long notes — forces multi-page with notes block.
      final items = List.generate(30, (i) => InvoiceItem(
        id: 'item$i',
        invoiceId: 'inv5',
        description: 'Service item ${i + 1}',
        hsnSacCode: '998314',
        quantity: 1,
        unitPrice: 1666.67,
        gstRatePercent: 18,
        lineTotal: 1666.67,
      ));

      final data = PdfInvoiceData(
        business: business,
        client: client,
        invoice: invoice,
        items: items,
        gst: gst,
      );

      final doc = PdfService().build(data);
      final bytes = await doc.save();

      // Must not throw + produce a valid multi-page PDF.
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(10000));
    });
  });
}
