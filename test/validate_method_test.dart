import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixController.validate() tests', () {
    const nameField = FormixFieldID<String>('name');

    testWidgets('validate() introduces errors and clears them correctly', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: nameField,
                  initialValue: '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const FormixTextFormField(fieldId: nameField);
                },
              ),
            ),
          ),
        ),
      );

      // Initially, it might already be invalid if autovalidateMode is always (default)
      // but let's check.
      expect(controller.getValidation(nameField).isValid, isFalse, reason: 'Should be invalid initially with empty value');

      // Now set a valid value
      controller.setValue(nameField, 'John');
      await tester.pump();
      expect(controller.getValidation(nameField).isValid, isTrue, reason: 'Should be valid after setting value');

      // Clear the value manually (bypassing validation for a moment if needed,
      // but setValue triggers validation)
      // Actually, setValue triggers validation, so it will become invalid immediately.
      controller.setValue(nameField, '');
      await tester.pump();
      expect(controller.getValidation(nameField).isValid, isFalse);

      // Let's test manual validate() call
      controller.setValue(nameField, 'Doe');
      await tester.pump();
      expect(controller.getValidation(nameField).isValid, isTrue);

      // Force a re-validation which should pass
      final isValid = controller.validate();
      expect(isValid, isTrue);
      expect(controller.getValidation(nameField).isValid, isTrue);

      // Now let's try to simulate a case where it might fail to clear if we had a bug.
      // We'll use a manual error first.
      controller.setFieldError(nameField, 'Manual Error');
      await tester.pump();
      expect(controller.getValidation(nameField).isValid, isFalse);
      expect(controller.getValidation(nameField).errorMessage, 'Manual Error');

      // Now call validate(). It should run the validator, which returns null (valid),
      // and update the state, CLEARING the manual error.
      controller.validate();
      await tester.pump();
      expect(controller.getValidation(nameField).isValid, isTrue, reason: 'validate() should clear manual errors if the field is actually valid');
    });

    testWidgets('validate() makes errors visible in the UI', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              autovalidateMode: FormixAutovalidateMode.onUserInteraction,
              fields: [
                FormixFieldConfig<String>(
                  id: nameField,
                  initialValue: '',
                  validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const FormixTextFormField(fieldId: nameField);
                },
              ),
            ),
          ),
        ),
      );

      // Initially no error shown because not touched
      expect(find.text('Required'), findsNothing);

      // Call validate()
      controller.validate();
      await tester.pump();

      // IF validate() is supposed to show errors, it should find 'Required' now.
      // Many users expect validate() to trigger error display.
      expect(find.text('Required'), findsOneWidget, reason: 'validate() should trigger error display in widgets');
    });
  });
}
