import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Standard Form Field Properties', () {
    late FormixFieldID<String> textField;
    late FormixFieldID<bool> boolField;

    setUp(() {
      textField = const FormixFieldID<String>('text_field');
      boolField = const FormixFieldID<bool>('bool_field');
    });

    testWidgets('enabled property works for FormixTextFormField', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: textField)],
              child: FormixTextFormField(fieldId: textField, enabled: false),
            ),
          ),
        ),
      );

      final textFieldWidget = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldWidget.enabled, false);
    });

    testWidgets('enabled property works for FormixCheckboxFormField', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: boolField)],
              child: FormixCheckboxFormField(
                fieldId: boolField,
                enabled: false,
              ),
            ),
          ),
        ),
      );

      final checkboxListTile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkboxListTile.enabled, false);
    });

    testWidgets('restorationId is passed to FormixTextFormField', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: textField)],
              child: FormixTextFormField(
                fieldId: textField,
                restorationId: 'restore_me',
              ),
            ),
          ),
        ),
      );

      final textFormField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(textFormField.restorationId, 'restore_me');
    });

    testWidgets('onChanged is called for FormixTextFormField', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: textField)],
              child: FormixTextFormField(
                fieldId: textField,
                onChanged: (val) => changedValue = val,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'hello');
      expect(changedValue, 'hello');
    });

    testWidgets('onSaved is called during form save for FormixTextFormField', (
      tester,
    ) async {
      String? savedValue;
      final controller = FormixController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: controller,
              fields: [
                FormixFieldConfig(id: textField, initialValue: 'initial'),
              ],
              child: FormixTextFormField(
                fieldId: textField,
                onSaved: (val) => savedValue = val,
              ),
            ),
          ),
        ),
      );

      // We need to find the state and call save() manually or trigger it via controller if supported.
      // FormixFieldWidgetState has save() method.
      final state = tester.state<FormixFieldWidgetState<String>>(
        find.byType(FormixTextFormField),
      );
      state.save();

      expect(savedValue, 'initial');
    });
  });
}
