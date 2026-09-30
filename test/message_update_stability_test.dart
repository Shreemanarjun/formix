import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

class SpanishMessages extends DefaultFormixMessages {
  const SpanishMessages();
  @override
  String required(String label) => '$label es requerido';
}

void main() {
  group('Formix Message Update Stability', () {
    testWidgets('updating global messages updates error strings without resetting values', (tester) async {
      const nameField = FormixFieldID<String>('name');

      addTearDown(() => formixGlobalMessages.value = const DefaultFormixMessages());
      formixGlobalMessages.value = const DefaultFormixMessages();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              autovalidateMode: FormixAutovalidateMode.always,
              fields: const [
                FormixFieldConfig(
                  id: nameField,
                ),
              ],
              child: Column(
                children: [
                  FormixTextFormField(
                    fieldId: nameField,
                    validator: (v) => (v == null || v.isEmpty) ? FormixValidationKeys.required : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Enter some initial data
      await tester.enterText(find.byType(TextFormField), 'John Doe');
      await tester.pumpAndSettle();

      final controller = Formix.controllerOf(tester.element(find.byType(FormixTextFormField)))!;
      expect(controller.getValue(nameField), 'John Doe');

      // 2. Clear text to trigger "REQUIRED_KEY" error in English
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();

      // Need to mark as touched OR wait for autovalidation
      expect(find.text('name is required'), findsOneWidget);

      // 3. Change language via the global messages signal
      formixGlobalMessages.value = const SpanishMessages();

      // Pump several times to handle microtasks and rebuilds
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 4. Verify error text is now in Spanish
      expect(find.text('name es requerido'), findsOneWidget);
      expect(find.text('name is required'), findsNothing);

      // 5. Verify that entered data WAS PRESERVED (if we enter it back)
      await tester.enterText(find.byType(TextFormField), 'Jane Doe');
      await tester.pump();
      expect(controller.getValue(nameField), 'Jane Doe');

      // Now change language back and see if value stays 'Jane Doe'
      formixGlobalMessages.value = const DefaultFormixMessages();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.getValue(nameField), 'Jane Doe');
      expect(find.text('Jane Doe'), findsOneWidget);
    });

    testWidgets('Formix widget messages prop override works reactively', (tester) async {
      const nameField = FormixFieldID<String>('name');

      bool isSpanish = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => isSpanish = !isSpanish),
                      child: const Text('Toggle'),
                    ),
                    Formix(
                      autovalidateMode: FormixAutovalidateMode.always,
                      messages: isSpanish ? const SpanishMessages() : const DefaultFormixMessages(),
                      child: FormixTextFormField(
                        fieldId: nameField,
                        validator: (v) => (v == null || v.isEmpty) ? FormixValidationKeys.required : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Trigger error
      await tester.enterText(find.byType(TextFormField), 'test');
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pumpAndSettle();

      expect(find.text('name is required'), findsOneWidget);

      // Toggle to Spanish
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('name es requerido'), findsOneWidget);

      // Verify no state reset
      final controller = Formix.controllerOf(tester.element(find.byType(FormixTextFormField)))!;
      controller.setValue(nameField, 'preserved_value');
      await tester.pump();

      // Toggle back to English
      await tester.tap(find.text('Toggle'));
      await tester.pump();

      expect(controller.getValue(nameField), 'preserved_value');
      expect(find.text('preserved_value'), findsOneWidget);
    });
  });
}
