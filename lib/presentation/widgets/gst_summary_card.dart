import 'package:flutter/material.dart';

import '../../domain/models/gst_calculation.dart';
import '../../theme/app_theme.dart';

/// Live-updating summary card shown at the bottom of the Invoice Create
/// screen. Renders the subtotal, applicable taxes (CGST/SGST or IGST),
/// and the bold total. Shows a disclaimer when the seller is unregistered.
class GstSummaryCard extends StatelessWidget {
  const GstSummaryCard({
    super.key,
    required this.calculation,
    required this.isUnregistered,
  });

  final GstCalculation calculation;
  final bool isUnregistered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColors(context);
    final fmt = _rupeeFormatter;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Summary',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _row(context, 'Subtotal', fmt(calculation.subtotal)),
            if (calculation.discountAmount > 0) ...[
              _row(context, 'Discount', '- ${fmt(calculation.discountAmount)}'),
              _row(context, 'Taxable Amount', fmt(calculation.taxableAmount)),
            ],
            if (isUnregistered)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tax',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: colors.warning,
                        ),
                      ),
                    ),
                    Text(
                      'Not applicable',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colors.warning,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (calculation.cgst > 0)
                _row(context, 'CGST', fmt(calculation.cgst)),
              if (calculation.sgst > 0)
                _row(context, 'SGST', fmt(calculation.sgst)),
              if (calculation.igst > 0)
                _row(context, 'IGST', fmt(calculation.igst)),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Amount',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  fmt(calculation.total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (isUnregistered) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: colors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Not registered under GST — tax not applicable. '
                        'The generated PDF will omit all tax line items.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String Function(double) _rupeeFormatter = (double v) {
  // Indian grouping, manually formatted.
  final isNeg = v < 0;
  final abs = v.abs();
  final intPart = abs.floor();
  final frac = (abs - intPart);
  final intStr = _groupIndian(intPart.toString());
  final fracStr =
      frac == 0 ? '' : '.${(frac * 100).round().toString().padLeft(2, '0')}';
  return '${isNeg ? '-' : ''}₹$intStr$fracStr';
};

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  final rest = digits.substring(0, digits.length - 3);
  final out = StringBuffer();
  for (var i = 0; i < rest.length; i++) {
    if (i > 0 && (rest.length - i) % 2 == 0) out.write(',');
    out.write(rest[i]);
  }
  return '${out.toString()},$last3';
}
