import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/user_action_dialogs.dart';

void main() {
  group('UserActionDialogs - Deactivate', () {
    testWidgets('shows deactivation dialog with user name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showDeactivateDialog(context, 'John Doe');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate User?'), findsOneWidget);
      // User name is in RichText/TextSpan, use byWidgetPredicate
      expect(
        find.byWidgetPredicate((widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('John Doe')),
        findsOneWidget,
      );
      expect(find.text('Deactivate User'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows preservation info', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showDeactivateDialog(context, 'Jane');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('All data will be preserved'), findsOneWidget);
      expect(find.text('Can be reactivated anytime'), findsOneWidget);
      expect(find.text('User will be unassigned from projects'), findsOneWidget);
    });

    testWidgets('returns true when confirmed', (tester) async {
      bool? result;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await UserActionDialogs.showDeactivateDialog(
                    context, 'Test User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deactivate User'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? result;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await UserActionDialogs.showDeactivateDialog(
                    context, 'Test User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, false);
    });

    testWidgets('shows pause icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showDeactivateDialog(context, 'User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_circle), findsOneWidget);
    });
  });

  group('UserActionDialogs - Remove', () {
    testWidgets('shows remove dialog with user name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showRemoveDialog(context, 'John Doe');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Remove User from Company?'), findsOneWidget);
      // User name is in RichText/TextSpan, use byWidgetPredicate
      expect(
        find.byWidgetPredicate((widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('John Doe')),
        findsOneWidget,
      );
      expect(find.text('Remove User'), findsOneWidget);
    });

    testWidgets('shows warning info', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showRemoveDialog(context, 'User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('This action cannot be undone'), findsOneWidget);
      // Historical data text is in a plain Text widget from _buildInfoRow
      expect(find.textContaining('Historical data'), findsOneWidget);
    });

    testWidgets('returns true when confirmed', (tester) async {
      bool? result;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await UserActionDialogs.showRemoveDialog(
                    context, 'Test User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove User'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('shows person_remove icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showRemoveDialog(context, 'User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_remove), findsOneWidget);
    });
  });

  group('UserActionDialogs - Reactivate', () {
    testWidgets('shows reactivation dialog with user name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showActivateDialog(context, 'Jane Smith');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Reactivate User?'), findsOneWidget);
      // User name is in RichText/TextSpan, use byWidgetPredicate
      expect(
        find.byWidgetPredicate((widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Jane Smith')),
        findsOneWidget,
      );
      expect(find.text('Reactivate User'), findsOneWidget);
    });

    testWidgets('shows reactivation info', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showActivateDialog(context, 'User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // 'regain access' is inside RichText/TextSpan, use byWidgetPredicate
      expect(
        find.byWidgetPredicate((widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('regain access')),
        findsOneWidget,
      );
    });

    testWidgets('returns true when confirmed', (tester) async {
      bool? result;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await UserActionDialogs.showActivateDialog(
                    context, 'Test User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reactivate User'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('shows play_circle icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                UserActionDialogs.showActivateDialog(context, 'User');
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle), findsOneWidget);
    });
  });
}
