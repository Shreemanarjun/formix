import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/ui/multi_step_form/multi_step_form_page.dart';

void main() {
  group('MultiStepFormPage Data Persistence Tests', () {
    testWidgets(
      'Step 1 data should persist when navigating to Step 2 and back',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: MultiStepFormPage()));

        await tester.pumpAndSettle();

        // Fill out Step 1
        await tester.enterText(
          find.widgetWithText(TextField, 'Full Name').first,
          'John Doe',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Email').first,
          'john@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Phone').first,
          '1234567890',
        );
        await tester.pumpAndSettle();

        // Verify data is entered
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('john@example.com'), findsOneWidget);
        expect(find.text('1234567890'), findsOneWidget);

        // Click Continue to go to Step 2
        await tester.tap(find.byKey(const Key('continue_button')).first);
        await tester.pumpAndSettle();

        // Verify we're on Step 2
        expect(find.text('Street Address'), findsOneWidget);

        // Click Back to return to Step 1
        await tester.tap(find.byKey(const Key('back_button')).first);
        await tester.pumpAndSettle();

        // CRITICAL TEST: Data should still be there!
        expect(
          find.text('John Doe'),
          findsOneWidget,
          reason: 'Name should persist when navigating back',
        );
        expect(
          find.text('john@example.com'),
          findsOneWidget,
          reason: 'Email should persist when navigating back',
        );
        expect(
          find.text('1234567890'),
          findsOneWidget,
          reason: 'Phone should persist when navigating back',
        );
      },
    );

    testWidgets('Step 2 data should persist when navigating forward and back', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MultiStepFormPage()));

      await tester.pumpAndSettle();

      // Fill Step 1 (required to proceed)
      await tester.enterText(
        find.widgetWithText(TextField, 'Full Name').first,
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email').first,
        'jane@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone').first,
        '0987654321',
      );
      await tester.pumpAndSettle();

      // Go to Step 2
      await tester.tap(find.byKey(const Key('continue_button')).first);
      await tester.pumpAndSettle();

      // Fill Step 2
      await tester.enterText(
        find.widgetWithText(TextField, 'Street Address').first,
        '123 Main St',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'City').first,
        'New York',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'ZIP').first,
        '10001',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Country').first,
        'USA',
      );
      await tester.pumpAndSettle();

      // Go to Step 3
      await tester.tap(find.byKey(const Key('continue_button')).first);
      await tester.pumpAndSettle();

      // Go back to Step 2
      await tester.tap(find.byKey(const Key('back_button')).first);
      await tester.pumpAndSettle();

      // CRITICAL TEST: Step 2 data should persist
      expect(
        find.text('123 Main St'),
        findsOneWidget,
        reason: 'Street should persist',
      );
      expect(
        find.text('New York'),
        findsOneWidget,
        reason: 'City should persist',
      );
      expect(find.text('10001'), findsOneWidget, reason: 'ZIP should persist');
      expect(
        find.text('USA'),
        findsOneWidget,
        reason: 'Country should persist',
      );
    });

    testWidgets('All steps data should be collected at submission', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MultiStepFormPage()));

      await tester.pumpAndSettle();

      // Fill Step 1
      await tester.enterText(
        find.widgetWithText(TextField, 'Full Name').first,
        'Test User',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email').first,
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone').first,
        '5555555555',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue_button')).first);
      await tester.pumpAndSettle();

      // Fill Step 2
      await tester.enterText(
        find.widgetWithText(TextField, 'Street Address').first,
        '456 Oak Ave',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'City').first,
        'Boston',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'ZIP').first,
        '02101',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Country').first,
        'USA',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue_button')).first);
      await tester.pumpAndSettle();

      // Fill Step 3
      await tester.enterText(
        find.widgetWithText(TextField, 'Company Name').first,
        'Acme Corp',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Position').first,
        'Developer',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Annual Salary').first,
        '100000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue_button')).first);
      await tester.pumpAndSettle();

      // Step 4 - just submit
      await tester.tap(find.byKey(const Key('continue_button')).first);
      await tester.pumpAndSettle();

      // Verify dialog shows all collected data
      expect(find.text('Form Submitted! 🎉'), findsOneWidget);
      expect(find.text('name: Test User'), findsOneWidget);
      expect(find.text('email: test@example.com'), findsOneWidget);
      expect(find.text('phone: 5555555555'), findsOneWidget);
      expect(find.text('street: 456 Oak Ave'), findsOneWidget);
      expect(find.text('city: Boston'), findsOneWidget);
      expect(find.text('zip: 02101'), findsOneWidget);
      expect(find.text('country: USA'), findsOneWidget);
      expect(find.text('company: Acme Corp'), findsOneWidget);
      expect(find.text('position: Developer'), findsOneWidget);
      expect(find.text('salary: 100000.0'), findsOneWidget);
    });

    testWidgets('Lazy loading: Only current step widgets should be mounted', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MultiStepFormPage()));

      await tester.pumpAndSettle();

      // Verify Step 1 is present
      expect(
        find.widgetWithText(TextField, 'Full Name'),
        findsOneWidget,
        reason: 'Step 1 should be visible initially',
      );

      // Verify Step 2 is NOT present (Lazy initialization)
      expect(
        find.widgetWithText(TextField, 'Street Address'),
        findsNothing,
        reason: 'Step 2 should NOT be mounted yet',
      );

      // Fill Step 1 to proceed
      await tester.enterText(
        find.widgetWithText(TextField, 'Full Name').first,
        'Lazyness Test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email').first,
        'lazy@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone').first,
        '1231231234',
      );
      await tester.pumpAndSettle();

      // Go to Step 2
      await tester.tap(find.byKey(const Key('continue_button')).first);
      await tester.pumpAndSettle();

      // Verify Step 2 is now present
      expect(
        find.widgetWithText(TextField, 'Street Address'),
        findsOneWidget,
        reason: 'Step 2 should be mounted now',
      );

      // Verify Step 1 is NO LONGER present (Unmounted to save memory)
      expect(
        find.widgetWithText(TextField, 'Full Name'),
        findsNothing,
        reason: 'Step 1 should be unmounted when moving to Step 2',
      );
    });
  });
}
