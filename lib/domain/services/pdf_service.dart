import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/database/database.dart';
import '../../utils/gst_state_codes.dart';
import '../models/gst_calculation.dart';

/// Snapshot of everything the PDF renderer needs, decoupled from the live
/// Drift rows so it can be unit-tested without a database.
class PdfInvoiceData {
  final BusinessProfile business;
  final Client client;
  final Invoice invoice;
  final List<InvoiceItem> items;
  final GstCalculation gst;

  PdfInvoiceData({
    required this.business,
    required this.client,
    required this.invoice,
    required this.items,
    required this.gst,
  });
}

/// Builds a [pw.Document] matching the layout in §7 of the spec.
///
/// Currency is formatted with the Indian lakh/crore grouping via `intl`
/// (`NumberFormat.currency(locale: 'en_IN', symbol: '₹')`).
class PdfService {
  pw.Document build(PdfInvoiceData data) {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final template = data.business.invoiceTemplate;
    pdf.addPage(_buildPage(data, template));
    return pdf;
  }

  pw.MultiPage _buildPage(PdfInvoiceData data, String template) {
    final isClassic = template == 'classic';
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: isClassic
          ? (ctx) => _buildClassicHeaderBand(data, ctx)
          : null,
      build: (ctx) => _buildContent(data, ctx, isClassic),
      footer: (ctx) => pw.Center(
        child: pw.Text(
          'Generated with Invory',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
    );
  }

  List<pw.Widget> _buildContent(PdfInvoiceData data, pw.Context ctx, bool isClassic) {
    final isUnregistered = !(data.business.isGstRegistered);
    final blocks = <pw.Widget>[];

    // For 'classic' template, the header band is rendered by MultiPage's
    // header callback (repeats on every page). For 'minimal', the header
    // is inline content (first page only).
    if (!isClassic) {
      // 1 & 2. Header: business block (left) + invoice meta (right).
      blocks.add(_buildHeader(data, isUnregistered));
      blocks.add(pw.SizedBox(height: 18));
    }

    // 3 & 4. Bill-to + place of supply.
    blocks.add(_buildBillTo(data));
    blocks.add(pw.SizedBox(height: 18));

    // 5. Line items table.
    blocks.add(_buildItemsTable(data, isUnregistered, isClassic));
    blocks.add(pw.SizedBox(height: 12));

    // 6 & 7. Summary + amount in words.
    blocks.add(_buildSummary(data, isUnregistered));
    blocks.add(pw.SizedBox(height: 8));
    blocks.add(_buildAmountInWords(data, isUnregistered));

    // 8. Bank details / UPI.
    if (_hasBankDetails(data.business)) {
      blocks.add(pw.SizedBox(height: 16));
      blocks.add(_buildBankBlock(data.business));
    }

    // 9. Notes.
    if ((data.invoice.notes ?? '').trim().isNotEmpty) {
      blocks.add(pw.SizedBox(height: 16));
      blocks.add(_buildNotesBlock(data.invoice.notes!));
    }

    return blocks;
  }

  /// Classic template header band — a colored strip with the business name
  /// + document title, repeated on every page by MultiPage's header callback.
  pw.Widget _buildClassicHeaderBand(PdfInvoiceData data, pw.Context ctx) {
    final isUnregistered = !(data.business.isGstRegistered);
    final title = _documentTitle(data);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF2563EB), // Invory brand blue
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            data.business.businessName,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Header ----------

  pw.Widget _buildHeader(PdfInvoiceData data, bool isUnregistered) {
    final business = data.business;
    final invoice = data.invoice;

    final leftChildren = <pw.Widget>[];

    // Logo (if set, with a sane max height).
    if (business.logoPath != null && File(business.logoPath!).existsSync()) {
      final bytes = File(business.logoPath!).readAsBytesSync();
      leftChildren.add(
        pw.Image(pw.MemoryImage(bytes),
            height: 56, width: 56, fit: pw.BoxFit.contain),
      );
      leftChildren.add(pw.SizedBox(height: 6));
    }

    leftChildren.add(
      pw.Text(
        business.businessName,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
    );
    if (business.address.isNotEmpty) {
      leftChildren.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child:
              pw.Text(business.address, style: const pw.TextStyle(fontSize: 9)),
        ),
      );
    }
    if (isUnregistered) {
      leftChildren.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            'Not registered under GST',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.red700),
          ),
        ),
      );
    } else {
      if ((business.gstin ?? '').isNotEmpty) {
        leftChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text('GSTIN: ${business.gstin}',
                style: const pw.TextStyle(fontSize: 9)),
          ),
        );
      }
      if ((business.panNumber ?? '').isNotEmpty) {
        leftChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text('PAN: ${business.panNumber}',
                style: const pw.TextStyle(fontSize: 9)),
          ),
        );
      }
    }
    if ((business.phone ?? '').isNotEmpty) {
      leftChildren.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text('Phone: ${business.phone}',
              style: const pw.TextStyle(fontSize: 9)),
        ),
      );
    }
    if ((business.email ?? '').isNotEmpty) {
      leftChildren.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text('Email: ${business.email}',
              style: const pw.TextStyle(fontSize: 9)),
        ),
      );
    }

    final rightChildren = <pw.Widget>[
      pw.Text(
        _documentTitle(data),
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      _kv('Invoice #', invoice.invoiceNumber),
      _kv('Issue Date', _formatDate(invoice.issueDate)),
      if (invoice.dueDate != null)
        _kv('Due Date', _formatDate(invoice.dueDate!)),
      _kv('Status', invoice.status.toUpperCase()),
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: leftChildren,
            )),
        pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: rightChildren,
            )),
      ],
    );
  }

  // ---------- Bill-to ----------

  pw.Widget _buildBillTo(PdfInvoiceData data) {
    final client = data.client;
    final invoice = data.invoice;
    final children = <pw.Widget>[
      pw.Text('Bill To',
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700)),
      pw.SizedBox(height: 2),
      pw.Text(client.name,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    ];
    if ((client.gstin ?? '').isNotEmpty) {
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Text('GSTIN: ${client.gstin}',
            style: const pw.TextStyle(fontSize: 9)),
      ));
    }
    if ((client.address ?? '').isNotEmpty) {
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Text(client.address!, style: const pw.TextStyle(fontSize: 9)),
      ));
    }
    children.add(pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Text(
        'State: ${stateNameForCode(client.stateCode) ?? client.stateCode} (${client.stateCode})',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ));

    final placeName =
        stateNameForCode(invoice.placeOfSupply) ?? invoice.placeOfSupply;
    children.add(pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        'Place of Supply: $placeName (Code: ${invoice.placeOfSupply})',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ));

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ---------- Items table ----------

  pw.Widget _buildItemsTable(PdfInvoiceData data, bool isUnregistered, bool isClassic) {
    // Classic template uses the brand blue header; minimal uses dark grey.
    final headerColor = isClassic
        ? const PdfColor.fromInt(0xFF2563EB)
        : PdfColors.blueGrey900;
    final headerRow = pw.TableRow(
      decoration: pw.BoxDecoration(color: headerColor),
      children: [
        _headerCell('Description'),
        _headerCell('HSN/SAC'),
        _headerCell('Qty', align: pw.Alignment.centerRight),
        _headerCell('Unit Price', align: pw.Alignment.centerRight),
        if (!isUnregistered)
          _headerCell('GST%', align: pw.Alignment.centerRight),
        _headerCell('Amount', align: pw.Alignment.centerRight),
      ],
    );

    final rows = <pw.TableRow>[headerRow];
    for (final item in data.items) {
      rows.add(pw.TableRow(
        children: [
          _bodyCell(item.description),
          _bodyCell(item.hsnSacCode ?? '—'),
          _bodyCell(_fmtNumber(item.quantity), align: pw.Alignment.centerRight),
          _bodyCell(_fmtRupee(item.unitPrice), align: pw.Alignment.centerRight),
          if (!isUnregistered)
            _bodyCell('${item.gstRatePercent.toStringAsFixed(0)}%',
                align: pw.Alignment.centerRight),
          _bodyCell(_fmtRupee(item.lineTotal), align: pw.Alignment.centerRight),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(1.5),
        if (!isUnregistered) 4: const pw.FlexColumnWidth(1.0),
        if (!isUnregistered)
          5: const pw.FlexColumnWidth(1.5)
        else
          4: const pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }

  // ---------- Summary ----------

  pw.Widget _buildSummary(PdfInvoiceData data, bool isUnregistered) {
    final rows = <pw.TableRow>[
      _summaryRow('Subtotal', _fmtRupee(data.gst.subtotal)),
    ];

    // v3: discount line (before tax).
    if (data.gst.discountAmount > 0) {
      rows.add(_summaryRow(
        'Discount',
        '- ${_fmtRupee(data.gst.discountAmount)}',
      ));
      rows.add(_summaryRow(
        'Taxable Amount',
        _fmtRupee(data.gst.taxableAmount),
      ));
    }

    if (isUnregistered) {
      // Explicit disclaimer line.
      rows.add(_summaryRow(
        'Tax',
        'Not applicable',
        bold: false,
        italic: true,
      ));
    } else {
      if (data.gst.cgst > 0)
        rows.add(_summaryRow('CGST', _fmtRupee(data.gst.cgst)));
      if (data.gst.sgst > 0)
        rows.add(_summaryRow('SGST', _fmtRupee(data.gst.sgst)));
      if (data.gst.igst > 0)
        rows.add(_summaryRow('IGST', _fmtRupee(data.gst.igst)));
    }

    rows.add(
        _summaryRow('Total Amount', _fmtRupee(data.gst.total), bold: true));

    // v3: payment status — show amount paid + balance due when partially paid.
    final amountPaid = data.invoice.amountPaid;
    if (amountPaid > 0 && amountPaid < data.gst.total) {
      rows.add(_summaryRow('Amount Paid', _fmtRupee(amountPaid)));
      final balance = data.gst.total - amountPaid;
      rows.add(_summaryRow(
        'Balance Due',
        _fmtRupee(balance),
        bold: true,
      ));
    }

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        child: pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1.6),
          },
          children: rows,
        ),
      ),
    );
  }

  pw.Widget _buildAmountInWords(PdfInvoiceData data, bool isUnregistered) {
    final words = _numberToIndianWords(data.gst.total);
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 240,
        child: pw.Text(
          'Rupees $words Only',
          style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
          textAlign: pw.TextAlign.right,
        ),
      ),
    );
  }

  // ---------- Bank block ----------

  bool _hasBankDetails(BusinessProfile b) {
    return (b.bankAccountName?.isNotEmpty ?? false) ||
        (b.bankAccountNumber?.isNotEmpty ?? false) ||
        (b.bankIfsc?.isNotEmpty ?? false) ||
        (b.upiId?.isNotEmpty ?? false);
  }

  pw.Widget _buildBankBlock(BusinessProfile b) {
    final lines = <pw.Widget>[];
    lines.add(pw.Text(
      'Payment Details',
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    ));
    if ((b.bankAccountName ?? '').isNotEmpty) {
      lines.add(_kv('Account Name', b.bankAccountName!));
    }
    if ((b.bankAccountNumber ?? '').isNotEmpty) {
      lines.add(_kv('Account Number', b.bankAccountNumber!));
    }
    if ((b.bankIfsc ?? '').isNotEmpty) {
      lines.add(_kv('IFSC', b.bankIfsc!));
    }
    if ((b.upiId ?? '').isNotEmpty) {
      lines.add(_kv('UPI ID', b.upiId!));
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }

  pw.Widget _buildNotesBlock(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Notes',
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ---------- Helpers ----------

  /// Returns the document title for the PDF header.
  /// Quotations show "QUOTATION", unregistered sellers show "INVOICE",
  /// registered sellers show "TAX INVOICE".
  String _documentTitle(PdfInvoiceData data) {
    if (data.invoice.documentType == 'quotation') {
      return 'QUOTATION';
    }
    return data.business.isGstRegistered ? 'TAX INVOICE' : 'INVOICE';
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _headerCell(String text,
      {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)),
      ),
    );
  }

  pw.Widget _bodyCell(String text,
      {pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      ),
    );
  }

  pw.TableRow _summaryRow(String label, String value,
      {bool bold = false, bool italic = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontStyle: italic ? pw.FontStyle.italic : null,
              ),
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontStyle: italic ? pw.FontStyle.italic : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Formatting helpers ----------

  // Note: pdf package's tables don't directly use intl's NumberFormat because
  // we want a single canonical formatter accessible from non-Flutter code.
  // We replicate the Indian lakh/crore grouping manually to keep the service
  // pure and avoid intl's locale-loading edge cases in release builds.
  String _fmtRupee(double v) {
    return '₹${_fmtIndian(v)}';
  }

  String _fmtNumber(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  /// Indian-style grouping: 1,00,000.00 (not 100,000.00).
  String _fmtIndian(double v) {
    final isNeg = v < 0;
    final abs = v.abs();
    final intPart = abs.floor();
    final frac = (abs - intPart);
    final intStr = _groupIndian(intPart.toString());
    final fracStr =
        frac == 0 ? '' : '.${(frac * 100).round().toString().padLeft(2, '0')}';
    return '${isNeg ? '-' : ''}$intStr$fracStr';
  }

  String _groupIndian(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    final rest = digits.substring(0, digits.length - 3);
    final buf = StringBuffer(rest);
    // Insert commas from the right in groups of 2.
    final out = StringBuffer();
    for (var i = 0; i < buf.length; i++) {
      if (i > 0 && (buf.length - i) % 2 == 0) out.write(',');
      out.write(buf.toString()[i]);
    }
    return '${out.toString()},$last3';
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  /// Convert a non-negative double to Indian English words.
  /// e.g. 12345.0 -> "Twelve Thousand Three Hundred Forty Five"
  ///
  /// Handles up to crores (10^7). Fractional rupee part is rendered as
  /// "and X Paise" if non-zero.
  String _numberToIndianWords(double amount) {
    if (amount < 0) return 'Zero';
    final intPart = amount.floor();
    final paise = ((amount - intPart) * 100).round();

    final words = <String>[];
    final crore = intPart ~/ 10000000;
    final lakh = (intPart % 10000000) ~/ 100000;
    final thousand = (intPart % 100000) ~/ 1000;
    final hundred = (intPart % 1000) ~/ 100;
    final tens = intPart % 100;

    if (crore > 0) words.add('${_belowHundred(crore)} Crore');
    if (lakh > 0) words.add('${_belowHundred(lakh)} Lakh');
    if (thousand > 0) words.add('${_belowHundred(thousand)} Thousand');
    if (hundred > 0) words.add('${_belowHundred(hundred)} Hundred');
    if (tens > 0) words.add(_belowHundred(tens));

    if (words.isEmpty) words.add('Zero');
    var out = words.join(' ');
    if (paise > 0) {
      out += ' and ${_belowHundred(paise)} Paise';
    }
    return out;
  }

  String _belowHundred(int n) {
    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];
    if (n < 20) return ones[n];
    return '${tens[n ~/ 10]}${n % 10 == 0 ? '' : ' ${ones[n % 10]}'}';
  }
}
