import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const EmptyStateWidget(
          icon: Icons.inbox,
          title: 'No Items',
        ),
      ));

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No Items'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const EmptyStateWidget(
          icon: Icons.inbox,
          title: 'No Items',
          subtitle: 'Add some items to get started.',
        ),
      ));

      expect(find.text('Add some items to get started.'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const EmptyStateWidget(
          icon: Icons.inbox,
          title: 'No Items',
        ),
      ));

      // Only finds the title, no subtitle
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        EmptyStateWidget(
          icon: Icons.inbox,
          title: 'No Items',
          action: ElevatedButton(
            onPressed: () {},
            child: const Text('Add Item'),
          ),
        ),
      ));

      expect(find.text('Add Item'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('does not render action when null', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const EmptyStateWidget(
          icon: Icons.inbox,
          title: 'No Items',
        ),
      ));

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('is centered', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const EmptyStateWidget(
          icon: Icons.inbox,
          title: 'No Items',
        ),
      ));

      // createTestableWidget wraps in Scaffold which may also have Center
      expect(find.byType(Center), findsWidgets);
    });
  });

  group('LoadingWidget', () {
    testWidgets('renders CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const LoadingWidget(),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders message when provided', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const LoadingWidget(message: 'Loading data...'),
      ));

      expect(find.text('Loading data...'), findsOneWidget);
    });

    testWidgets('does not render message when null', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const LoadingWidget(),
      ));

      expect(find.byType(Text), findsNothing);
    });
  });

  group('SectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const SectionHeader(title: 'My Section'),
      ));

      expect(find.text('My Section'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        SectionHeader(
          title: 'My Section',
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('uses default white background', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const SectionHeader(title: 'Test'),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, AppTheme.cardWhite);
    });

    testWidgets('uses custom background color when provided', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const SectionHeader(
          title: 'Test',
          backgroundColor: Colors.blue,
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, Colors.blue);
    });
  });

  group('CategoryBadge', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const CategoryBadge(text: 'PENDING', color: Colors.orange),
      ));

      expect(find.text('PENDING'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const CategoryBadge(
          text: 'APPROVED',
          color: Colors.green,
          icon: Icons.check_circle,
        ),
      ));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('does not render icon when null', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const CategoryBadge(text: 'PENDING', color: Colors.orange),
      ));

      expect(find.byType(Icon), findsNothing);
    });
  });

  group('PriorityIndicator', () {
    testWidgets('shows upward arrow for high priority', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const PriorityIndicator(priority: 'high'),
      ));

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('shows remove icon for medium priority', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const PriorityIndicator(priority: 'medium'),
      ));

      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('accepts "med" as medium', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const PriorityIndicator(priority: 'med'),
      ));

      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('shows downward arrow for low priority', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const PriorityIndicator(priority: 'low'),
      ));

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('shows remove icon for unknown priority', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const PriorityIndicator(priority: 'unknown'),
      ));

      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('is case insensitive', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const PriorityIndicator(priority: 'HIGH'),
      ));

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('renders as CircleAvatar', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const PriorityIndicator(priority: 'high'),
      ));

      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });

  group('ActionButton', () {
    testWidgets('renders label and icon', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        ActionButton(
          label: 'Submit',
          icon: Icons.send,
          onPressed: () {},
        ),
      ));

      expect(find.text('Submit'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(createTestableWidget(
        ActionButton(
          label: 'Click Me',
          icon: Icons.touch_app,
          onPressed: () => pressed = true,
        ),
      ));

      await tester.tap(find.text('Click Me'));
      expect(pressed, true);
    });

    testWidgets('compact mode uses smaller icon', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        ActionButton(
          label: 'Small',
          icon: Icons.add,
          onPressed: () {},
          isCompact: true,
        ),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.size, 16);
    });

    testWidgets('normal mode uses larger icon', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        ActionButton(
          label: 'Normal',
          icon: Icons.add,
          onPressed: () {},
          isCompact: false,
        ),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.size, 20);
    });
  });

  group('ErrorStateWidget', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const ErrorStateWidget(message: 'Something went wrong'),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        ErrorStateWidget(
          message: 'Failed to load',
          onRetry: () {},
        ),
      ));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('does not show retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const ErrorStateWidget(message: 'Failed to load'),
      ));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('calls onRetry when retry button is tapped', (tester) async {
      bool retried = false;

      await tester.pumpWidget(createTestableWidget(
        ErrorStateWidget(
          message: 'Failed',
          onRetry: () => retried = true,
        ),
      ));

      await tester.tap(find.text('Retry'));
      expect(retried, true);
    });
  });

  group('ShimmerLoadingCard', () {
    testWidgets('renders with default height', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const ShimmerLoadingCard(),
      ));

      expect(find.byType(ShimmerLoadingCard), findsOneWidget);
    });

    testWidgets('renders with custom height', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const ShimmerLoadingCard(height: 200),
      ));

      expect(find.byType(ShimmerLoadingCard), findsOneWidget);
    });
  });

  group('ShimmerLoadingList', () {
    testWidgets('renders default number of shimmer cards', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const ShimmerLoadingList(),
      ));

      expect(find.byType(ShimmerLoadingCard), findsNWidgets(5));
    });

    testWidgets('renders custom number of shimmer cards', (tester) async {
      await tester.pumpWidget(createTestableWidget(
        const ShimmerLoadingList(itemCount: 3),
      ));

      expect(find.byType(ShimmerLoadingCard), findsNWidgets(3));
    });
  });
}
