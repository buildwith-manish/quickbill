import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/presentation/widgets/gst_summary_card.dart';
import 'package:quickbill/presentation/widgets/empty_state.dart';
import 'package:quickbill/domain/models/gst_calculation.dart';
import 'package:quickbill/theme/app_theme.dart';

void main() {
  // Wrap with the app's actual theme so AppColors extension is available.
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      );

  group('EmptyState widget', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(
        wrap(const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No invoices yet',
          message: 'Tap the + button to create your first invoice.',
        )),
      );

      expect(find.text('No invoices yet'), findsOneWidget);
      expect(
          find.text('Tap the + button to create your first invoice.'),
          findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('shows action button when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No invoices yet',
          message: 'Tap below to create one.',
          actionLabel: 'New invoice',
          onAction: () => tapped = true,
        )),
      );

      final button = find.text('New invoice');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('hides action button when onAction is null', (tester) async {
      await tester.pumpWidget(
        wrap(const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No matches',
          message: 'Try a different search.',
          actionLabel: 'New invoice',
        )),
      );

      expect(find.text('New invoice'), findsNothing);
    });
  });

  group('GstSummaryCard widget', () {
    testWidgets('renders intrastate breakdown', (tester) async {
      await tester.pumpWidget(
        wrap(GstSummaryCard(
          calculation: const GstCalculation(
            subtotal: 10000,
            cgst: 900,
            sgst: 900,
            igst: 0,
            total: 11800,
          ),
          isUnregistered: false,
        )),
      );

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('CGST'), findsOneWidget);
      expect(find.text('SGST'), findsOneWidget);
      expect(find.text('IGST'), findsNothing);
      expect(find.text('Total Amount'), findsOneWidget);
    });

    testWidgets('renders interstate breakdown', (tester) async {
      await tester.pumpWidget(
        wrap(GstSummaryCard(
          calculation: const GstCalculation(
            subtotal: 10000,
            cgst: 0,
            sgst: 0,
            igst: 1800,
            total: 11800,
          ),
          isUnregistered: false,
        )),
      );

      expect(find.text('IGST'), findsOneWidget);
      expect(find.text('CGST'), findsNothing);
      expect(find.text('SGST'), findsNothing);
    });

    testWidgets('shows unregistered disclaimer', (tester) async {
      await tester.pumpWidget(
        wrap(GstSummaryCard(
          calculation: const GstCalculation(
            subtotal: 5000,
            cgst: 0,
            sgst: 0,
            igst: 0,
            total: 5000,
          ),
          isUnregistered: true,
        )),
      );

      expect(find.text('Not applicable'), findsOneWidget);
      expect(find.textContaining('Not registered under GST'), findsOneWidget);
    });
  });
}
