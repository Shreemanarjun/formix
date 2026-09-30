import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Focus Management Tests', () {
    const field1 = FormixFieldID<String>('field1');
    const field2 = FormixFieldID<String>('field2');
    const field3 = FormixFieldID<String>('field3');

    testWidgets('Enter-to-Next focuses next field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(id: field1, initialValue: ''),
                FormixFieldConfig<String>(id: field2, initialValue: ''),
                FormixFieldConfig<String>(id: field3, initialValue: ''),
              ],
              child: Column(
                children: [
                  FormixTextFormField(fieldId: field1),
                  FormixTextFormField(fieldId: field2),
                  FormixTextFormField(fieldId: field3),
                ],
              ),
            ),
          ),
        ),
      );

      // Focus first field
      await tester.tap(find.widgetWithText(TextFormField, '').first);
      await tester.pump();
      final firstField = find.byType(TextField).first;
      expect(
        tester.widget<TextField>(firstField).focusNode?.hasFocus,
        isTrue,
        reason: 'First field should be focused',
      );

      // Submit (Enter) - Should move to next
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      // Second field should be focused
      final secondField = find.widgetWithText(TextField, '').at(1);
      final secondFocusNode = tester.widget<TextField>(secondField).focusNode;
      expect(
        secondFocusNode?.hasFocus,
        isTrue,
        reason: 'Second field should be focused after Next',
      );

      // Submit (Enter) again - Should move to third
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final thirdField = find.widgetWithText(TextField, '').at(2);
      final thirdFocusNode = tester.widget<TextField>(thirdField).focusNode;
      expect(
        thirdFocusNode?.hasFocus,
        isTrue,
        reason: 'Third field should be focused after Next',
      );
    });

    testWidgets('Validates Submit-to-Error functionality', (tester) async {
      const requiredField = FormixFieldID<String>('required');
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: requiredField,
                  initialValue: '',
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const Column(
                    children: [FormixTextFormField(fieldId: requiredField)],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Submit form
      await controller.submit(onValid: (_) async {}, autoFocusOnInvalid: true);
      await tester.pump();

      // Field should clearly be invalid
      expect(find.text('Required'), findsOneWidget);

      // And focused
      final fieldFinder = find.widgetWithText(TextField, '');
      final fieldWidget = tester.widget<TextField>(fieldFinder);
      expect(fieldWidget.focusNode?.hasFocus, isTrue);
    });
  });
}
