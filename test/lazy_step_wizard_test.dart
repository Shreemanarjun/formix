import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Lazy Step Wizard Tests', () {
    // Step 1 Fields
    const nameField = FormixFieldID<String>('name');
    const ageField = FormixFieldID<String>('age');

    // Step 2 Fields
    const streetField = FormixFieldID<String>('street');
    const cityField = FormixFieldID<String>('city');

    testWidgets('Wizard flow with lazy loading preserves state across steps', (
      tester,
    ) async {
      late FormixController controller;
      final currentStep = ValueNotifier<int>(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return ValueListenableBuilder<int>(
                    valueListenable: currentStep,
                    builder: (context, step, _) {
                      return Column(
                        children: [
                          if (step == 0)
                            const FormixSection(
                              keepAlive: true,
                              fields: [
                                FormixFieldConfig<String>(
                                  id: nameField,
                                  initialValue: '',
                                ),
                                FormixFieldConfig<String>(
                                  id: ageField,
                                  initialValue: '0',
                                ),
                              ],
                              child: Column(
                                children: [
                                  FormixTextFormField(
                                    fieldId: nameField,
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                    ),
                                  ),
                                  FormixTextFormField(
                                    fieldId: ageField,
                                    decoration: InputDecoration(
                                      labelText: 'Age',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (step == 1)
                            const FormixSection(
                              keepAlive: true,
                              fields: [
                                FormixFieldConfig<String>(
                                  id: streetField,
                                  initialValue: '',
                                ),
                                FormixFieldConfig<String>(
                                  id: cityField,
                                  initialValue: '',
                                ),
                              ],
                              child: Column(
                                children: [
                                  FormixTextFormField(
                                    fieldId: streetField,
                                    decoration: InputDecoration(
                                      labelText: 'Street',
                                    ),
                                  ),
                                  FormixTextFormField(
                                    fieldId: cityField,
                                    decoration: InputDecoration(
                                      labelText: 'City',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (step == 2)
                            // Summary step - no registry needed as we just read data
                            Column(
                              children: [
                                const Text('Summary:'),
                                Text(
                                  'Name: ${controller.values[nameField.key]}',
                                ),
                                Text(
                                  'Street: ${controller.values[streetField.key]}',
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // --- STEP 1 ---
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Street'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'John Doe',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '30');
      await tester.pump();

      expect(controller.getValue(nameField), 'John Doe');

      // Move to Step 2
      currentStep.value = 1;
      await tester.pumpAndSettle();

      // --- STEP 2 ---
      // Step 1 fields are NOT unregistered with FormixSection(keepAlive: true)
      // They remain registered to maintain validation state if needed.
      expect(find.text('Name'), findsNothing);
      expect(find.text('Street'), findsOneWidget);
      expect(
        controller.isFieldRegistered(nameField),
        isTrue,
      ); // Changed from isFalse
      expect(
        controller.getValue(nameField),
        'John Doe',
        reason: 'Step 1 data preserved',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Street'),
        '123 Main St',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'City'),
        'Tech City',
      );
      await tester.pump();

      expect(controller.getValue(streetField), '123 Main St');

      // Move to Step 3 (Summary)
      currentStep.value = 2;
      await tester.pumpAndSettle();

      // --- STEP 3 ---
      // Both previous steps unregistered? No, they stay registered.
      expect(find.text('Name: John Doe'), findsOneWidget);
      expect(find.text('Street: 123 Main St'), findsOneWidget);

      expect(
        controller.isFieldRegistered(nameField),
        isTrue,
      ); // Changed from isFalse
      expect(
        controller.isFieldRegistered(streetField),
        isTrue,
      ); // Changed from isFalse

      // Move BACK to Step 1
      currentStep.value = 0;
      await tester.pumpAndSettle();

      // --- STEP 1 (Revisited) ---
      expect(find.text('Name'), findsOneWidget);
      expect(
        find.text('John Doe'),
        findsOneWidget,
        reason: 'Step 1 UI restored with value',
      );
      expect(controller.isFieldRegistered(nameField), isTrue);

      // Verify validation logic works on restored field
      // Assuming we had a validator (we didn't add one in config, but testing basic binding)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Jane Doe',
      );
      await tester.pump();
      expect(controller.getValue(nameField), 'Jane Doe');
    });
  });
}
