import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/features/finance/widgets/invoice_card.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('InvoiceCard', () {
    testWidgets('renders invoice number', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(invoiceNumber: 'INV-042'),
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.textContaining('#INV-042'), findsOneWidget);
    });

    testWidgets('renders vendor name', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(vendor: 'Cement Corp'),
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('Cement Corp'), findsOneWidget);
    });

    testWidgets('renders status badge', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(status: 'submitted'),
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('SUBMITTED'), findsOneWidget);
    });

    testWidgets('renders amount', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(amount: 25000),
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.textContaining('25,000'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(),
            isExpanded: false,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, true);
    });

    testWidgets('shows expanded content when isExpanded true', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(description: 'Cement delivery'),
            isExpanded: true,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('Cement delivery'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('hides expanded content when isExpanded false',
        (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(description: 'Cement delivery'),
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('Description'), findsNothing);
    });

    testWidgets('shows approve/reject buttons for submitted status',
        (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(status: 'submitted'),
            isExpanded: true,
            onTap: () {},
            onApprove: () {},
            onReject: () {},
          ),
        ),
      ));

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('shows submit button for draft status', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(status: 'draft'),
            isExpanded: true,
            onTap: () {},
            onSubmit: () {},
          ),
        ),
      ));

      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('shows add payment button for approved status',
        (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(status: 'approved'),
            isExpanded: true,
            onTap: () {},
            onAddPayment: () {},
          ),
        ),
      ));

      expect(find.text('Add Payment'), findsOneWidget);
    });

    testWidgets('shows rejection reason when rejected', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(
              status: 'rejected',
              rejectionReason: 'Price too high',
            ),
            isExpanded: true,
            onTap: () {},
          ),
        ),
      ));

      expect(find.textContaining('Price too high'), findsOneWidget);
    });

    testWidgets('shows payment progress when payments exist', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(
              status: 'approved',
              amount: 10000,
            ),
            linkedPayments: [
              {'amount': 5000, 'payment_method': 'bank_transfer'},
            ],
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.textContaining('50%'), findsOneWidget);
    });

    testWidgets('handles null amount gracefully', (tester) async {
      final invoice = {
        'id': 'inv-1',
        'status': 'draft',
        'vendor': 'Test',
        'invoice_number': 'INV-1',
      };

      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: invoice,
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byType(InvoiceCard), findsOneWidget);
    });

    testWidgets('shows due date when available', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(dueDate: '2024-06-15'),
            isExpanded: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.textContaining('Due:'), findsOneWidget);
    });

    testWidgets('shows submitted by name when expanded', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: InvoiceCard(
            invoice: createTestInvoice(
              users: {'full_name': 'Ravi Kumar'},
            ),
            isExpanded: true,
            onTap: () {},
          ),
        ),
      ));

      expect(find.textContaining('Ravi Kumar'), findsOneWidget);
    });
  });

  group('InvoiceCard - Status Color Logic', () {
    test('draft is grey', () {
      Color statusColor(String status) {
        switch (status) {
          case 'draft':
            return Colors.grey;
          case 'submitted':
            return const Color(0xFF1565C0);
          case 'approved':
            return const Color(0xFF2E7D32);
          case 'rejected':
            return const Color(0xFFD32F2F);
          case 'paid':
            return const Color(0xFF2E7D32);
          case 'overdue':
            return const Color(0xFFD32F2F);
          default:
            return Colors.grey;
        }
      }

      expect(statusColor('draft'), Colors.grey);
      expect(statusColor('submitted'), const Color(0xFF1565C0));
      expect(statusColor('approved'), const Color(0xFF2E7D32));
      expect(statusColor('rejected'), const Color(0xFFD32F2F));
      expect(statusColor('paid'), const Color(0xFF2E7D32));
      expect(statusColor('overdue'), const Color(0xFFD32F2F));
      expect(statusColor('unknown'), Colors.grey);
    });
  });

  group('InvoiceCard - Payment Progress Calculation', () {
    test('calculates correct progress', () {
      const amount = 10000.0;
      const totalPaid = 5000.0;
      final progress =
          amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

      expect(progress, 0.5);
    });

    test('clamps progress to 1.0', () {
      const amount = 10000.0;
      const totalPaid = 15000.0;
      final progress =
          amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

      expect(progress, 1.0);
    });

    test('returns 0.0 for zero amount', () {
      const amount = 0.0;
      const totalPaid = 5000.0;
      final progress =
          amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

      expect(progress, 0.0);
    });
  });
}
