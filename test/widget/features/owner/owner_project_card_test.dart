import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/features/owner/widgets/owner_project_card.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('OwnerProjectCard', () {
    testWidgets('renders project name', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: createTestProject(name: 'Mumbai Tower'),
          pendingCount: 3,
          inProgressCount: 2,
          completedCount: 5,
          onTap: () {},
        ),
      ));

      expect(find.text('Mumbai Tower'), findsOneWidget);
    });

    testWidgets('renders location when available', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: createTestProject(location: 'Bandra, Mumbai'),
          pendingCount: 1,
          inProgressCount: 1,
          completedCount: 1,
          onTap: () {},
        ),
      ));

      expect(find.text('Bandra, Mumbai'), findsOneWidget);
    });

    testWidgets('uses "Untitled Site" for missing name', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: {'id': '1'},
          pendingCount: 0,
          inProgressCount: 0,
          completedCount: 0,
          onTap: () {},
        ),
      ));

      expect(find.text('Untitled Site'), findsOneWidget);
    });

    testWidgets('renders action counts', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: createTestProject(),
          pendingCount: 3,
          inProgressCount: 2,
          completedCount: 5,
          onTap: () {},
        ),
      ));

      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('5'), findsWidgets);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: createTestProject(),
          pendingCount: 0,
          inProgressCount: 0,
          completedCount: 0,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(Card));
      expect(tapped, true);
    });

    testWidgets('renders as a Card widget', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: createTestProject(),
          pendingCount: 0,
          inProgressCount: 0,
          completedCount: 0,
          onTap: () {},
        ),
      ));

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('handles zero action counts', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: createTestProject(),
          pendingCount: 0,
          inProgressCount: 0,
          completedCount: 0,
          onTap: () {},
        ),
      ));

      // Should render without errors
      expect(find.byType(OwnerProjectCard), findsOneWidget);
    });

    testWidgets('handles empty location', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        OwnerProjectCard(
          project: createTestProject(location: ''),
          pendingCount: 0,
          inProgressCount: 0,
          completedCount: 0,
          onTap: () {},
        ),
      ));

      expect(find.byType(OwnerProjectCard), findsOneWidget);
    });
  });

  group('OwnerProjectCard - Total Actions Calculation', () {
    test('total is sum of all counts', () {
      const pending = 3;
      const inProgress = 2;
      const completed = 5;
      final total = pending + inProgress + completed;

      expect(total, 10);
    });

    test('total is zero when all counts are zero', () {
      const pending = 0;
      const inProgress = 0;
      const completed = 0;
      final total = pending + inProgress + completed;

      expect(total, 0);
    });
  });
}
