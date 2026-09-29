import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Global Validation Mode', () {
    test('defaults to auto/always which triggers validation', () {
      const field = FormixFieldID<String>('name');
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: field,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      );

      // Default is always (via auto fallback)
      expect(controller.getValidation(field).isValid, isFalse);
    });

    test('setting global mode to disabled prevents auto-validation', () {
      const field = FormixFieldID<String>('name');
      final controller = FormixController(
        autovalidateMode: FormixAutovalidateMode.disabled,
        fields: [
          FormixField<String>(
            id: field,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      );

      // Should be valid (or rather, not validated yet, so defaults to valid)
      expect(controller.getValidation(field).isValid, isTrue);

      // Manual validation still works
      controller.validate();
      expect(controller.getValidation(field).isValid, isFalse);
    });

    test('field level mode overrides global mode', () {
      const fieldAlways = FormixFieldID<String>('always');
      const fieldDisabled = FormixFieldID<String>('disabled');

      final controller = FormixController(
        autovalidateMode: FormixAutovalidateMode.disabled,
        fields: [
          FormixField<String>(
            id: fieldAlways,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Err' : null,
            validationMode: FormixAutovalidateMode.always,
          ),
          FormixField<String>(
            id: fieldDisabled,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Err' : null,
            validationMode: FormixAutovalidateMode.disabled,
          ),
        ],
      );

      expect(controller.getValidation(fieldAlways).isValid, isFalse);
      expect(controller.getValidation(fieldDisabled).isValid, isTrue);
    });

    test('global onUserInteraction works correctly', () {
      const field = FormixFieldID<String>('name');
      final controller = FormixController(
        autovalidateMode: FormixAutovalidateMode.onUserInteraction,
        fields: [
          FormixField<String>(
            id: field,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      );

      // Initially valid (not touched)
      expect(controller.getValidation(field).isValid, isTrue);

      // After user interaction (setValue)
      controller.setValue(field, 'a');
      controller.setValue(field, ''); // Back to empty
      expect(controller.getValidation(field).isValid, isFalse);
    });
    test('global mode affects dependencies correctly', () {
      const source = FormixFieldID<String>('source');
      const dependent = FormixFieldID<String>('dependent');

      final controller = FormixController(
        autovalidateMode: FormixAutovalidateMode.disabled,
        fields: [
          const FormixField<String>(id: source, initialValue: 'initial'),
          FormixField<String>(
            id: dependent,
            initialValue: 'init',
            dependsOn: [source],
            validator: (v) => v == 'trigger' ? 'Error' : null,
          ),
        ],
      );

      // Dependent should not validate on start
      expect(controller.getValidation(dependent).isValid, isTrue);

      // Change dependent value to trigger condition
      controller.setValue(dependent, 'trigger');
      // Should still be valid because global mode is disabled
      expect(controller.getValidation(dependent).isValid, isTrue);

      // Manual validate
      controller.validate();
      expect(controller.getValidation(dependent).isValid, isFalse);
    });

    test('global mode affects async validation', () async {
      const field = FormixFieldID<String>('async');
      int callCount = 0;

      final controller = FormixController(
        autovalidateMode: FormixAutovalidateMode.disabled,
        fields: [
          FormixField<String>(
            id: field,
            initialValue: '',
            asyncValidator: (v) async {
              callCount++;
              return null;
            },
          ),
        ],
      );

      controller.setValue(field, 'change');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(callCount, 0); // Should not have called async validator

      controller.autovalidateMode == FormixAutovalidateMode.always; // Note: autovalidateMode is final in implementation
    });

    test('late registered fields inherit global mode', () {
      final controller = FormixController(
        autovalidateMode: FormixAutovalidateMode.disabled,
      );

      const field = FormixFieldID<String>('late');
      controller.registerField(
        FormixField<String>(
          id: field,
          initialValue: '',
          validator: (v) => v!.isEmpty ? 'Err' : null,
        ),
      );

      // Should be valid because inherited disabled mode
      expect(controller.getValidation(field).isValid, isTrue);

      controller.validate();
      expect(controller.getValidation(field).isValid, isFalse);
    });

    test('onBlur global mode triggers on touch', () {
      const field = FormixFieldID<String>('blur');
      final controller = FormixController(
        autovalidateMode: FormixAutovalidateMode.onBlur,
        fields: [
          FormixField<String>(
            id: field,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      );

      // Initially valid
      expect(controller.getValidation(field).isValid, isTrue);

      // Touch the field
      controller.markAsTouched(field);
      // Now it should be validated
      expect(controller.getValidation(field).isValid, isFalse);
    });
  });

  group('Formix Widget Global Mode Integration', () {
    testWidgets('Formix widget propagates autovalidateMode to controller', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              autovalidateMode: FormixAutovalidateMode.disabled,
              fields: [
                FormixFieldConfig<String>(
                  id: fieldId,
                  initialValue: '',
                  validator: (v) => v!.isEmpty ? 'Error' : null,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) => Text(scope.watchError(fieldId) ?? 'Valid'),
              ),
            ),
          ),
        ),
      );

      // Should show 'Valid' because validation is disabled
      expect(find.text('Valid'), findsOneWidget);

      final controller = Formix.controllerOf(
        tester.element(find.text('Valid')),
      );
      expect(controller, isNotNull);
      controller!.validate();
      await tester.pump();

      // Now should show 'Error'
      expect(find.text('Error'), findsOneWidget);
    });
  });
}
