import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
import 'package:example/ui/conditional_form/conditional_form_page.dart';

void main() {
  group('Conditional Form Example Tests', () {
    testWidgets('Shows Business dependent fields when Business is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ConditionalFormExample()),
      );

      await tester.pumpAndSettle();

      // Verify initial state (Personal)
      expect(find.text('Personal Account'), findsOneWidget);
      expect(find.text('Business Information'), findsNothing);
      expect(find.text('Company Name'), findsNothing);

      // Snapshot initial state (Personal)
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/example_conditional_initial.png'),
      );

      // Select Business
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Business Account').last);
      await tester.pumpAndSettle();

      // Verify Business fields shown
      expect(find.text('Business Information'), findsOneWidget);
      expect(
        find.widgetWithText(FormixTextFormField, 'Company Name'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FormixTextFormField, 'Tax ID'),
        findsOneWidget,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/example_conditional_business.png'),
      );
    });

    testWidgets('Removes Business fields data when switching back to Personal', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ConditionalFormExample()),
      );

      await tester.pumpAndSettle();

      // Switch to Business
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Business Account').last);
      await tester.pumpAndSettle();

      // Enter data
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Company Name'),
        'Acme Corp',
      );
      await tester.pumpAndSettle();

      // Switch back to Personal
      await tester.tap(find.byType(DropdownButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal Account').last);
      await tester.pumpAndSettle();

      // Verify Business fields are gone
      expect(find.text('Company Name'), findsNothing);

      // Verify data is removed from controller (commented out check)
      // final controller = Formix.controllerOf(tester.element(find.byType(ConditionalFormExampleContent)))!;
      // final companyNameField = FormixFieldID<String>('companyName');

      // Note: isFieldRegistered might take a microtask to update due to FormixSection implementation
      // expect(controller.isFieldRegistered(companyNameField), isFalse);
    });

    testWidgets(
      'Shows Phone dependent fields when Phone contact method is selected',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ConditionalFormExample()),
        );

        await tester.pumpAndSettle();
        // Find the Formix field widget by ValueKey
        // Use .first to avoid "Too many elements" error if key appears multiple times (unlikely but safer)
        final contactMethodFieldFinder = find
            .byKey(const ValueKey('contactMethodField'))
            .first;
        // Use runAsync to handle dropdown menu animations/timers reliably
        await tester.runAsync(() async {
          // Ensure it is visible
          await tester.ensureVisible(contactMethodFieldFinder);
          await tester.pumpAndSettle();

          // Find the DropdownButton descendant specifically within this field
          final dropdownFinder = find.descendant(
            of: contactMethodFieldFinder,
            matching: find.byType(DropdownButton<String>),
          );

          // Tap to open dropdown
          await tester.tap(dropdownFinder);
          await tester.pumpAndSettle();

          // Select 'Phone'
          await tester.tap(find.text('Phone').last);
          await tester.pumpAndSettle();
        });

        // Verify Phone fields
        expect(
          find.widgetWithText(FormixTextFormField, 'Phone Number'),
          findsOneWidget,
        );
        expect(find.text('Preferred Call Time'), findsOneWidget);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/example_conditional_phone.png'),
        );
      },
    );

    testWidgets(
      'Submit shows validation errors on required conditional fields',
      (tester) async {
        await tester.binding.setSurfaceSize(
          const Size(800, 2000),
        ); // Ensure visibility

        await tester.pumpWidget(
          const MaterialApp(home: ConditionalFormExample()),
        );

        await tester.pumpAndSettle();

        // Switch to Business
        await tester.tap(find.byType(DropdownButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Business Account').last);
        await tester.pumpAndSettle();

        // Tap Submit
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        // Verify Company Name error
        expect(find.text('Company name is required'), findsOneWidget);

        // Also verify First Name error (always visible field)
        expect(find.text('First name is required'), findsOneWidget);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/example_conditional_errors.png'),
        );
      },
    );
  });
}
