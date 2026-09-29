import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Programmatic Control Tests', () {
    testWidgets('Focusing a field programmatically', (tester) async {
      const fieldA = FormixFieldID<String>('a');
      const fieldB = FormixFieldID<String>('b');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixBuilder(
                builder: (context, scope) {
                  return Column(
                    children: [
                      const FormixTextFormField(
                        key: Key('A'),
                        fieldId: fieldA,
                      ),
                      const FormixTextFormField(
                        key: Key('B'),
                        fieldId: fieldB,
                      ),
                      ElevatedButton(
                        onPressed: () => scope.focusField(fieldB),
                        child: const Text('Focus B'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap Focus B button
      await tester.tap(find.text('Focus B'));
      await tester.pumpAndSettle();

      // Verify B is focused
      expect(find.byKey(const Key('B')), findsOneWidget);
      // We check focus by looking at the EditableText inside
      final editableB = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('B')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editableB.focusNode.hasFocus, isTrue);
    });

    testWidgets('Scrolling to a field programmatically', (tester) async {
      const fieldB = FormixFieldID<String>('b');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixBuilder(
                builder: (context, scope) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => scope.scrollToField(fieldB),
                        child: const Text('Scroll to B'),
                      ),
                      const Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(height: 1000),
                              FormixTextFormField(
                                key: Key('B'),
                                fieldId: fieldB,
                              ),
                              SizedBox(height: 1000),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Ensure field B is NOT visible
      // findsOneWidget might still be true if it's in the tree but off-screen.
      // We use isVisible to check.
      expect(tester.getCenter(find.byKey(const Key('B'))).dy > 800, isTrue);

      // Tap Scroll to B button
      await tester.tap(find.text('Scroll to B'));
      await tester.pumpAndSettle();

      // Verify B is now visible (somewhere in the middle of the screen)
      final centerB = tester.getCenter(find.byKey(const Key('B')));
      expect(centerB.dy, greaterThan(0));
      expect(centerB.dy, lessThan(600));
    });

    testWidgets('Focusing first error', (tester) async {
      const fieldA = FormixFieldID<String>('a');
      const fieldB = FormixFieldID<String>('b');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: fieldA,
                  initialValue: '',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
                FormixFieldConfig<String>(
                  id: fieldB,
                  initialValue: '',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  return Column(
                    children: [
                      const FormixTextFormField(
                        key: Key('A'),
                        fieldId: fieldA,
                      ),
                      const FormixTextFormField(
                        key: Key('B'),
                        fieldId: fieldB,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!scope.validate()) {
                            scope.focusFirstError();
                          }
                        },
                        child: const Text('Fix Errors'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap button
      await tester.tap(find.text('Fix Errors'));
      await tester.pumpAndSettle();

      // Verify A is focused (since it's the first error)
      final editableA = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('A')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editableA.focusNode.hasFocus, isTrue);
    });
  });
}
