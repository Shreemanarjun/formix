import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// A simple custom field for testing
class CustomToggleField extends FormixFieldWidget<bool> {
  const CustomToggleField({super.key, required super.fieldId});

  @override
  FormixFieldWidgetState<bool> createState() => _CustomToggleFieldState();
}

class _CustomToggleFieldState extends FormixFieldWidgetState<bool> {
  @override
  Widget build(BuildContext context) {
    return Switch(
      key: const Key('custom_switch'),
      value: value ?? false,
      onChanged: (v) => didChange(v),
    );
  }
}

void main() {
  group('Manual Validation & Custom Widget Tests', () {
    const nameField = FormixFieldID<String>('name');
    const toggleField = FormixFieldID<bool>('toggle');

    testWidgets('setFieldError manually updates field error', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig<String>(id: nameField, initialValue: ''),
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

      // Initially valid
      expect(controller.getValidation(nameField).isValid, isTrue);

      // Set manual error
      controller.setFieldError(nameField, 'Backend Error');
      await tester.pump();

      final validation = controller.getValidation(nameField);
      expect(validation.isValid, isFalse);
      expect(validation.errorMessage, 'Backend Error');

      // Clear manual error
      controller.setFieldError(nameField, null);
      await tester.pump();
      expect(controller.getValidation(nameField).isValid, isTrue);
    });

    testWidgets('setFieldValidating updates validating state', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig<String>(id: nameField, initialValue: ''),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(controller.getValidation(nameField).isValidating, isFalse);

      // Start validating
      controller.setFieldValidating(nameField, isValidating: true);
      await tester.pump();
      expect(controller.getValidation(nameField).isValidating, isTrue);

      // Stop validating
      controller.setFieldValidating(nameField, isValidating: false);
      await tester.pump();
      expect(controller.getValidation(nameField).isValidating, isFalse);
    });

    testWidgets('Custom FormixFieldWidget updates form state', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig<bool>(id: toggleField, initialValue: false),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const CustomToggleField(fieldId: toggleField);
                },
              ),
            ),
          ),
        ),
      );

      // Initial value
      expect(controller.getValue(toggleField), isFalse);

      // Interact with custom widget
      await tester.tap(find.byKey(const Key('custom_switch')));
      await tester.pump();

      // Check state update
      expect(controller.getValue(toggleField), isTrue);
      expect(controller.isFieldDirty(toggleField), isTrue);
    });
  });
}
