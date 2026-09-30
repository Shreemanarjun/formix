import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/ui/multi_step_form/multi_step_form_page.dart';

void main() {
  group('MultiStepFormPage Validation Tests', () {
    testWidgets('Step 1 validation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MultiStepFormPage()));
      await tester.pumpAndSettle();

      // Skip initial continue tap for now to debug finding

      // 2. Enter invalid name
      final nameFinder = find.widgetWithText(TextField, 'Full Name');
      expect(nameFinder, findsAtLeastNWidgets(1));
      await tester.enterText(nameFinder.first, 'Jo');

      await tester.pumpAndSettle();
      expect(find.text('Name must be at least 3 characters'), findsOneWidget);

      // 3. Enter valid name, invalid email
      await tester.enterText(nameFinder.first, 'John');
      final emailFinder = find.widgetWithText(TextField, 'Email');
      await tester.enterText(emailFinder.first, 'bad-email');

      await tester.pumpAndSettle();
      expect(find.text('Invalid email format'), findsOneWidget);

      // 4. Valid Step 1
      await tester.enterText(emailFinder.first, 'john@example.com');
      final phoneFinder = find.widgetWithText(TextField, 'Phone');
      await tester.enterText(phoneFinder.first, '1234567890');

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();
    });

    testWidgets('Step 2 validation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MultiStepFormPage()));
      await tester.pumpAndSettle();

      // Pass Step 1
      await tester.enterText(
        find.widgetWithText(TextField, 'Full Name').first,
        'John',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email').first,
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone').first,
        '1234567890',
      );
      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();

      // Skip empty continue tap

      // Invalid ZIP
      final zipFinder = find.widgetWithText(TextField, 'ZIP');
      await tester.enterText(zipFinder.first, '123');
      await tester.pumpAndSettle();
      expect(find.text('ZIP must be at least 5 digits'), findsOneWidget);
    });

    testWidgets('Step 4 validation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MultiStepFormPage()));
      await tester.pumpAndSettle();

      // Pass Step 1
      await tester.enterText(
        find.widgetWithText(TextField, 'Full Name').first,
        'John',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email').first,
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone').first,
        '1234567890',
      );
      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();

      // Pass Step 2
      await tester.enterText(
        find.widgetWithText(TextField, 'Street Address').first,
        'Street',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'City').first,
        'City',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'ZIP').first,
        '12345',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Country').first,
        'US',
      );
      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();

      // Pass Step 3
      await tester.enterText(
        find.widgetWithText(TextField, 'Company Name').first,
        'Corp',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Position').first,
        'Dev',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Annual Salary').first,
        '50000',
      );
      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();

      // Step 4

      // Invalid comment validation check
      final commentFinder = find.widgetWithText(
        TextField,
        'Additional Comments (Optional)',
      );
      await tester.enterText(commentFinder.first, 'short');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Comments must be at least 10 characters'),
        findsOneWidget,
      );

      // Wait for SnackBar to disappear to reveal the button
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Fix comment and submit
      await tester.enterText(
        commentFinder.first,
        'This is a valid long comment',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();
      expect(find.text('Form Submitted! 🎉'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });
}
