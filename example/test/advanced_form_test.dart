import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/ui/advanced/advanced_page.dart';

void main() {
  group('Advanced Example Validation Tests', () {
    Finder findField(String label) {
      return find.widgetWithText(TextFormField, label);
    }

    testWidgets('Entering matching passwords should clear error message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdvancedExample())),
      );

      // Settle initial load
      await tester.pumpAndSettle();

      final passwordFieldFinder = findField('Password');
      final confirmPasswordFieldFinder = findField('Confirm Password');

      // 1. Enter valid password
      await tester.enterText(passwordFieldFinder, 'Test@1234');
      await tester.pumpAndSettle();

      // 2. Enter matching confirm password
      await tester.enterText(confirmPasswordFieldFinder, 'Test@1234');
      await tester.pumpAndSettle();

      // 3. Verify no error message "Passwords do not match" is present
      expect(find.text('Passwords do not match'), findsNothing);

      // 4. Verify the "Save Profile" button is enabled
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Profile');
      expect(
        tester.widget<ElevatedButton>(saveButton).onPressed,
        isNotNull,
        reason: 'Save button should be enabled when form is valid',
      );

      // 5. Verify the status text show it is valid
      expect(
        find.textContaining('Form is valid and ready to submit'),
        findsOneWidget,
      );
    });

    testWidgets('Entering mismatching passwords should show error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdvancedExample())),
      );

      await tester.pumpAndSettle();

      final passwordFieldFinder = findField('Password');
      final confirmPasswordFieldFinder = findField('Confirm Password');

      await tester.enterText(passwordFieldFinder, 'Test@1234');
      await tester.enterText(confirmPasswordFieldFinder, 'Wrong@1234');
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);

      final saveButton = find.widgetWithText(ElevatedButton, 'Save Profile');
      expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNull);
    });

    testWidgets(
      'Changing main password should trigger confirm password re-validation',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdvancedExample())),
        );

        await tester.pumpAndSettle();

        final passwordFieldFinder = findField('Password');
        final confirmPasswordFieldFinder = findField('Confirm Password');

        // Make them match
        await tester.enterText(passwordFieldFinder, 'Test@1234');
        await tester.enterText(confirmPasswordFieldFinder, 'Test@1234');
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsNothing);

        // Change main password to create mismatch
        await tester.enterText(passwordFieldFinder, 'Changed@1234');
        await tester.pumpAndSettle();

        expect(
          find.text('Passwords do not match'),
          findsOneWidget,
          reason:
              'Confirm password should re-validate when main password changes',
        );
      },
    );
    group('Field State Transition Tests', () {
      testWidgets(
        'Confirm password should NOT show mismatch if both are empty initially',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: AdvancedExample())),
          );
          await tester.pumpAndSettle();

          // Initial state from code: password='' and confirmPassword=''
          // Both fail "required" validators, but should they fail "match" validator?
          // They match (''), so it shouldn't show "passwords do not match".
          expect(find.text('Passwords do not match'), findsNothing);
        },
      );
    });
  });
}
