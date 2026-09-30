import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Focus Traversal Tests', () {
    const field1 = FormixFieldID<String>('field1');
    const field2 = FormixFieldID<String>('field2');
    const field3 = FormixFieldID<String>('field3');

    testWidgets('Focus moves from Text -> Dropdown -> Text via Next action', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(id: field1, initialValue: ''),
                FormixFieldConfig<String>(id: field2, initialValue: 'A'),
                FormixFieldConfig<String>(id: field3, initialValue: ''),
              ],
              child: Column(
                children: [
                  FormixTextFormField(
                    fieldId: field1,
                    textInputAction: TextInputAction.next,
                  ),
                  FormixDropdownFormField<String>(
                    fieldId: field2,
                    items: [
                      DropdownMenuItem(value: 'A', child: Text('Alpha')),
                      DropdownMenuItem(value: 'B', child: Text('Beta')),
                    ],
                  ),
                  FormixTextFormField(
                    fieldId: field3,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Focus first field
      await tester.tap(find.byType(FormixTextFormField).first);
      await tester.pump();
      expect(FocusScope.of(tester.element(find.byType(FormixTextFormField).first)).focusedChild, isNotNull);

      // 2. Press "Next" on keyboard
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      // 3. Dropdown should have focus
      final dropdown = find.byType(DropdownButton<String>);
      expect(dropdown, findsOneWidget);
      final dropdownFocus = tester.widget<DropdownButton<String>>(dropdown).focusNode;
      expect(dropdownFocus?.hasFocus, isTrue, reason: 'Dropdown should be focused after Textfield Next');

      // 4. Since Dropdown doesn't have a virtual keyboard "Next" button,
      // we check physical keyboard navigation (Tab)
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // 5. Third field should be focused
      final lastField = find.byType(FormixTextFormField).last;
      final textFieldInLastField = find.descendant(
        of: lastField,
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(textFieldInLastField).focusNode?.hasFocus,
        isTrue,
        reason: 'Third field should be focused after Tab',
      );
    });
  });
}
