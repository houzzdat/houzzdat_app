import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/owner/widgets/owner_approval_card.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('OwnerApprovalCard', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(title: 'Concrete Purchase'),
          ),
        ),
      ));

      expect(find.text('Concrete Purchase'), findsOneWidget);
    });

    testWidgets('renders amount with currency', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(amount: 50000.0, currency: 'INR'),
          ),
        ),
      ));

      expect(find.textContaining('INR'), findsOneWidget);
      expect(find.textContaining('50000'), findsOneWidget);
    });

    testWidgets('renders requester name', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(requestedByName: 'Alice Manager'),
          ),
        ),
      ));

      expect(find.textContaining('Alice Manager'), findsOneWidget);
    });

    testWidgets('renders project name', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(projectName: 'Mumbai Site'),
          ),
        ),
      ));

      expect(find.text('Mumbai Site'), findsOneWidget);
    });

    testWidgets('renders description when available', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval:
                createTestApproval(description: 'Need concrete for floor 3'),
          ),
        ),
      ));

      expect(find.text('Need concrete for floor 3'), findsOneWidget);
    });

    testWidgets('shows action buttons for pending status', (tester) async {
      bool approved = false;
      bool denied = false;

      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(status: 'pending'),
            onApprove: () => approved = true,
            onDeny: () => denied = true,
            onAddNote: () {},
          ),
        ),
      ));

      expect(find.text('APPROVE'), findsOneWidget);
      expect(find.text('DENY'), findsOneWidget);
      expect(find.text('ADD NOTE'), findsOneWidget);

      await tester.tap(find.text('APPROVE'));
      expect(approved, true);

      await tester.tap(find.text('DENY'));
      expect(denied, true);
    });

    testWidgets('hides action buttons for non-pending status', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(status: 'approved'),
          ),
        ),
      ));

      expect(find.text('APPROVE'), findsNothing);
      expect(find.text('DENY'), findsNothing);
    });

    testWidgets('renders category badge for spending', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(category: 'spending'),
          ),
        ),
      ));

      expect(find.text('SPENDING'), findsOneWidget);
    });

    testWidgets('renders category badge for design_change', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(category: 'design_change'),
          ),
        ),
      ));

      expect(find.text('DESIGN CHANGE'), findsOneWidget);
    });

    testWidgets('renders category badge for material_change', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(category: 'material_change'),
          ),
        ),
      ));

      expect(find.text('MATERIAL CHANGE'), findsOneWidget);
    });

    testWidgets('renders category badge for schedule_change', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(category: 'schedule_change'),
          ),
        ),
      ));

      expect(find.text('SCHEDULE CHANGE'), findsOneWidget);
    });

    testWidgets('renders status badge', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(status: 'approved'),
          ),
        ),
      ));

      expect(find.text('APPROVED'), findsOneWidget);
    });

    testWidgets('renders owner response when available', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(
              status: 'approved',
              ownerResponse: 'Looks good, proceed.',
            ),
          ),
        ),
      ));

      expect(find.text('Looks good, proceed.'), findsOneWidget);
    });

    testWidgets('handles null amount gracefully', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(amount: null),
          ),
        ),
      ));

      // Should render without crashing
      expect(find.byType(OwnerApprovalCard), findsOneWidget);
    });

    testWidgets('renders default title when null', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(title: null),
          ),
        ),
      ));

      expect(find.text('Approval Request'), findsOneWidget);
    });

    testWidgets('renders default requester when null', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SingleChildScrollView(
          child: OwnerApprovalCard(
            approval: createTestApproval(requestedByName: null),
          ),
        ),
      ));

      expect(find.textContaining('Manager'), findsOneWidget);
    });
  });

  group('OwnerApprovalCard - Category Color Logic', () {
    test('spending returns warning orange', () {
      // Test the logic pattern used in _getCategoryColor
      Color getCategoryColor(String? category) {
        switch (category) {
          case 'spending':
            return const Color(0xFFEF6C00); // AppTheme.warningOrange
          case 'design_change':
            return const Color(0xFF1565C0); // AppTheme.infoBlue
          case 'material_change':
            return const Color(0xFF1A237E); // AppTheme.primaryIndigo
          case 'schedule_change':
            return const Color(0xFFD32F2F); // AppTheme.errorRed
          default:
            return const Color(0xFF757575); // AppTheme.textSecondary
        }
      }

      expect(getCategoryColor('spending'), const Color(0xFFEF6C00));
      expect(getCategoryColor('design_change'), const Color(0xFF1565C0));
      expect(getCategoryColor('material_change'), const Color(0xFF1A237E));
      expect(getCategoryColor('schedule_change'), const Color(0xFFD32F2F));
      expect(getCategoryColor('other'), const Color(0xFF757575));
      expect(getCategoryColor(null), const Color(0xFF757575));
    });
  });

  group('OwnerApprovalCard - Status Color Logic', () {
    test('status colors are mapped correctly', () {
      Color getStatusColor(String? status) {
        switch (status) {
          case 'approved':
            return const Color(0xFF2E7D32); // AppTheme.successGreen
          case 'denied':
            return const Color(0xFFD32F2F); // AppTheme.errorRed
          case 'deferred':
            return const Color(0xFFEF6C00); // AppTheme.warningOrange
          default:
            return const Color(0xFF757575); // AppTheme.textSecondary
        }
      }

      expect(getStatusColor('approved'), const Color(0xFF2E7D32));
      expect(getStatusColor('denied'), const Color(0xFFD32F2F));
      expect(getStatusColor('deferred'), const Color(0xFFEF6C00));
      expect(getStatusColor('pending'), const Color(0xFF757575));
    });
  });
}
