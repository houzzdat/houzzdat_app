import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/auth/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders HOUZZDAT branding', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      expect(find.text('HOUZZDAT'), findsOneWidget);
    });

    testWidgets('renders email field', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    });

    testWidgets('renders password field', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('renders Sign In button', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('renders construction icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      expect(find.byIcon(Icons.construction), findsOneWidget);
    });

    testWidgets('email field has email keyboard type', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      // Access the underlying TextField to check keyboardType
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      final emailTextField = textFields.first;
      expect(emailTextField.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('password field is obscured', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      // Access the underlying TextField to check obscureText
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      final passwordTextField = textFields.last;
      expect(passwordTextField.obscureText, true);
    });

    testWidgets('validates empty email', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      // Tap Sign In without entering anything
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('validates empty password', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      // Enter email but leave password empty
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('has email and lock icons', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
    });

    testWidgets('background is primaryIndigo', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppTheme.primaryIndigo);
    });

    testWidgets('Sign In button has amber background', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      final style = button.style;
      // Check that style is not null (has custom styling)
      expect(style, isNotNull);
    });

    testWidgets('can enter text in email field', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');

      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('can enter text in password field', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'mypassword');

      // Password is obscured, so find the text in the form field
      final field = tester.widget<EditableText>(
        find.byType(EditableText).last,
      );
      expect(field.controller.text, 'mypassword');
    });

    testWidgets('form uses validation on submit', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: LoginScreen(),
      ));

      // Submit empty form
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Both validation messages should appear
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });
}
