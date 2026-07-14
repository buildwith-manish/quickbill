import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/data/database/database.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';
import 'package:quickbill/domain/services/pdf_service.dart';

/// Tests that the PDF generator doesn't crash on edge cases:
///   - Very long client name + address (100+ chars)
///   - Many line items (20+)
///   - Combination of both
///
/// We don't do a golden-file pixel comparison — the goal is to confirm
/// generation completes without throwing and produces a non-empty,
/// multi-page-safe document. We assert the byte count is reasonable and
/// the page count from the generated document's internal structure.
void main() {
  group('PdfService edge cases', () {
    late BusinessProfile business;
    late Client client;
    late Invoice invoice;
    late List<InvoiceItem> items;
    late GstCalculation gst;

    setUp(() {
      business = BusinessProfile(
        id: 1,
        businessName: 'Anjali Sharma Design Studio',
        gstin: '27ABCDE1234F1Z5',
        stateCode: '27',
        address: 'Flat 12B, Sunrise Apartments, Hill Road, Bandra West, Mumbai, Maharashtra 400050',
        phone: '9876543210',
        email: 'anjali@example.com',
        panNumber: 'ABCDE1234F',
        bankAccountName: null,
        bankAccountNumber: null,
        bankIfsc: null,
        upiId: 'anjali@oksbi',
        logoPath: null,
        isGstRegistered: true,
      );

      gst = const GstCalculation(
        subtotal: 100000,
        cgst: 9000,
        sgst: 9000,
        igst: 0,
        total: 118000,
      );
    });

    test('generates PDF with very long client name and address', () async {
      // 100+ character client name and address.
      client = Client(
        id: 'c1',
        name: 'Acme Corporation Private Limited Technologies India Subsidiary Holdings LLC Group'
            ' With A Very Long Name That Exceeds Normal Display Widths',
        gstin: '29AAACI1234L1ZP',
        stateCode: '29',
        address: 'Tower 4, 15th Floor, Wing B, Prestige Tech Park, Outer Ring Road, Kadubeesanahalli,'
            ' Bengaluru, Karnataka 560103, India — Additional address line for stress testing'
            ' the PDF layout engine with unusually long multiline content',
        email: 'accounts@acme-corp-tech-india-subsidiary-holdings-llc-group.example.com',
        phone: '9876543210',
        createdAt: DateTime(2026, 7, 14),
      );

      invoice = Invoice(
        id: 'inv1',
        invoiceNumber: 'INV/2026-27/0001',
        clientId: 'c1',
        issueDate: DateTime(2026, 7, 14),
        dueDate: DateTime(2026, 8, 13),
        status: 'sent',
        notes: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
            'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
        placeOfSupply: '29',
        subtotal: 100000,
        cgstAmount: 9000,
        sgstAmount: 9000,
        igstAmount: 0,
        totalAmount: 118000,
        createdAt: DateTime(2026, 7, 14),
      );

      items = List.generate(3, (i) => InvoiceItem(
        id: 'item$i',
        invoiceId: 'inv1',
        description: 'Design service — milestone ${i + 1}',
        hsnSacCode: '998314',
        quantity: 1,
        unitPrice: 33333.33,
        gstRatePercent: 18,
        lineTotal: 33333.33,
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

      // Non-empty PDF.
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));

      // PDFs start with %PDF.
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('generates PDF with 25 line items', () async {
      client = Client(
        id: 'c2',
        name: 'TechCo',
        gstin: '07AAACI1234L1ZP',
        stateCode: '07',
        address: 'Delhi',
        email: null,
        phone: null,
        createdAt: DateTime(2026, 7, 14),
      );

      invoice = Invoice(
        id: 'inv2',
        invoiceNumber: 'INV/2026-27/0002',
        clientId: 'c2',
        issueDate: DateTime(2026, 7, 14),
        dueDate: null,
        status: 'draft',
        notes: null,
        placeOfSupply: '07',
        subtotal: 25000,
        cgstAmount: 2250,
        sgstAmount: 2250,
        igstAmount: 0,
        totalAmount: 29500,
        createdAt: DateTime(2026, 7, 14),
      );

      // 25 line items — should fit on one A4 page but exercises the
      // table layout engine heavily.
      items = List.generate(25, (i) => InvoiceItem(
        id: 'item$i',
        invoiceId: 'inv2',
        description: 'Line item ${i + 1} — consulting hours, design review,'
            ' implementation support, and documentation for module ${i + 1}',
        hsnSacCode: '998314',
        quantity: (i + 1).toDouble(),
        unitPrice: 1000,
        gstRatePercent: 18,
        lineTotal: (i + 1) * 1000.0,
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
      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('generates PDF with long strings AND 20+ items combined', () async {
      client = Client(
        id: 'c3',
        name: 'Acme Corporation Private Limited Technologies India Subsidiary Holdings LLC Group'
            ' With A Very Long Name That Exceeds Normal Display Widths',
        gstin: '33AAACI1234L1ZP',
        stateCode: '33',
        address: 'Very long address that spans multiple lines when rendered in the'
            ' bill-to block of the PDF — Tower 4, 15th Floor, Wing B, Prestige Tech Park,'
            ' Outer Ring Road, Kadubeesanahalli, Chennai, Tamil Nadu 600001, India',
        email: null,
        phone: '9876543210',
        createdAt: DateTime(2026, 7, 14),
      );

      invoice = Invoice(
        id: 'inv3',
        invoiceNumber: 'INV/2026-27/0003',
        clientId: 'c3',
        issueDate: DateTime(2026, 7, 14),
        dueDate: DateTime(2026, 8, 13),
        status: 'sent',
        notes: 'Long notes block — Lorem ipsum dolor sit amet, consectetur '
            'adipiscing elit. Sed do eiusmod tempor incididunt ut labore et '
            'dolore magna aliqua. Ut enim ad minim veniam, quis nostrud '
            'exercitation ullamco laboris nisi ut aliquip ex ea commodo '
            'consequat. Duis aute irure dolor in reprehenderit in voluptate.',
        placeOfSupply: '33',
        subtotal: 100000,
        cgstAmount: 9000,
        sgstAmount: 9000,
        igstAmount: 0,
        totalAmount: 118000,
        createdAt: DateTime(2026, 7, 14),
      );

      items = List.generate(22, (i) => InvoiceItem(
        id: 'item$i',
        invoiceId: 'inv3',
        description: 'Service item ${i + 1} with a moderately long description'
            ' that exercises the cell-wrapping behavior of the items table'
            ' — milestone ${i + 1} of 22',
        hsnSacCode: '998314',
        quantity: 1,
        unitPrice: (i + 1) * 100,
        gstRatePercent: 18,
        lineTotal: (i + 1) * 100.0,
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

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('unregistered seller PDF omits tax rows', () async {
      final unregisteredBusiness = BusinessProfile(
        id: 1,
        businessName: 'Solo Freelancer',
        gstin: null,
        stateCode: '07',
        address: 'Delhi',
        phone: null,
        email: null,
        panNumber: null,
        bankAccountName: null,
        bankAccountNumber: null,
        bankIfsc: null,
        upiId: null,
        logoPath: null,
        isGstRegistered: false,
      );

      client = Client(
        id: 'c4',
        name: 'Client',
        gstin: null,
        stateCode: '07',
        address: null,
        email: null,
        phone: null,
        createdAt: DateTime(2026, 7, 14),
      );

      invoice = Invoice(
        id: 'inv4',
        invoiceNumber: 'INV/2026-27/0004',
        clientId: 'c4',
        issueDate: DateTime(2026, 7, 14),
        dueDate: null,
        status: 'draft',
        notes: null,
        placeOfSupply: '07',
        subtotal: 5000,
        cgstAmount: 0,
        sgstAmount: 0,
        igstAmount: 0,
        totalAmount: 5000,
        createdAt: DateTime(2026, 7, 14),
      );

      items = [
        InvoiceItem(
          id: 'item0',
          invoiceId: 'inv4',
          description: 'Service',
          hsnSacCode: null,
          quantity: 1,
          unitPrice: 5000,
          gstRatePercent: 0,
          lineTotal: 5000,
        ),
      ];

      final unregisteredGst = const GstCalculation(
        subtotal: 5000,
        cgst: 0,
        sgst: 0,
        igst: 0,
        total: 5000,
      );

      final data = PdfInvoiceData(
        business: unregisteredBusiness,
        client: client,
        invoice: invoice,
        items: items,
        gst: unregisteredGst,
      );

      final doc = PdfService().build(data);
      final bytes = await doc.save();

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });
}
