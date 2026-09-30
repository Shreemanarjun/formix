import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Formix Widget Tests', () {
    testWidgets('should render child and provide controller', (tester) async {
      const nameField = FormixFieldID<String>('name');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'name': 'Default Name'},
              child: Column(
                children: [
                  const FormixTextFormField(
                    fieldId: nameField,
                    decoration: InputDecoration(labelText: 'Name'),
                  ),
                  Builder(
                    builder: (context) {
                      final controller = Formix.controllerOf(context);
                      return Text('Controller Ready: ${controller != null}');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Default Name'), findsOneWidget);
      expect(find.text('Controller Ready: true'), findsOneWidget);
    });

    testWidgets('should register fields passed to Formix constructor', (
      tester,
    ) async {
      const emailField = FormixFieldID<String>('email');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: emailField,
                  initialValue: '',
                  validator: (value) => (value?.contains('@') ?? false) ? null : 'Invalid email',
                ),
              ],
              child: Column(
                children: [
                  const FormixTextFormField(
                    fieldId: emailField,
                    decoration: InputDecoration(labelText: 'Email'),
                  ),
                  FormixBuilder(
                    builder: (context, scope) {
                      return Text('Is Valid: ${scope.watchIsValid}');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially invalid because empty doesn't contain @
      expect(find.text('Is Valid: false'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pump();

      expect(find.text('Is Valid: true'), findsOneWidget);
    });

    testWidgets('should handle reset via controller from Formix.of', (
      tester,
    ) async {
      const nameField = FormixFieldID<String>('name');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'name': 'Original'},
              child: Column(
                children: [
                  const FormixTextFormField(fieldId: nameField),
                  Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () {
                          Formix.of(context)?.reset();
                        },
                        child: const Text('Reset Form'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Original'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Modified');
      await tester.pump();
      expect(find.text('Modified'), findsOneWidget);

      await tester.tap(find.text('Reset Form'));
      await tester.pump();

      expect(find.text('Original'), findsOneWidget);
    });

    testWidgets('should support nested Formixs with independent states', (
      tester,
    ) async {
      const fieldA = FormixFieldID<String>('field');
      const fieldB = FormixFieldID<String>('field');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Formix(
                  key: Key('form_a'),
                  initialValue: {'field': 'Form A'},
                  child: Column(
                    children: [
                      Text('Scope A'),
                      FormixTextFormField(fieldId: fieldA),
                    ],
                  ),
                ),
                Divider(),
                Formix(
                  key: Key('form_b'),
                  initialValue: {'field': 'Form B'},
                  child: Column(
                    children: [
                      Text('Scope B'),
                      FormixTextFormField(fieldId: fieldB),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Form A'), findsOneWidget);
      expect(find.text('Form B'), findsOneWidget);

      // Modify first form
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('form_a')),
          matching: find.byType(TextField),
        ),
        'Changed A',
      );
      await tester.pump();

      expect(find.text('Changed A'), findsOneWidget);
      expect(find.text('Form B'), findsOneWidget);
    });
  });
}
