import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixNumberFormField', () {
    late FormixFieldID<num> numField;
    late FormixFieldID<int> intField;
    late FormixFieldID<double> doubleField;

    setUp(() {
      numField = const FormixFieldID<num>('num_field');
      intField = const FormixFieldID<int>('int_field');
      doubleField = const FormixFieldID<double>('double_field');
    });

    testWidgets('renders with initial numeric value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42.5},
              fields: [FormixFieldConfig(id: numField, initialValue: 42.5)],
              child: FormixNumberFormField(
                fieldId: numField,
                decoration: const InputDecoration(labelText: 'Number'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('42.5'), findsOneWidget);
      expect(find.text('Number'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('renders with int value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'int_field': 42},
              fields: [FormixFieldConfig(id: intField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: intField),
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders with double value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'double_field': 42.7},
              fields: [
                FormixFieldConfig(id: doubleField, initialValue: 42.7),
              ],
              child: FormixNumberFormField(fieldId: doubleField),
            ),
          ),
        ),
      );

      expect(find.text('42.7'), findsOneWidget);
    });

    testWidgets('accepts numeric input and updates value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 0},
              fields: [FormixFieldConfig(id: numField, initialValue: 0)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.pump();

      expect(find.text('123'), findsOneWidget);

      // Check that the controller has the updated value
      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      expect(controller.getValue(numField), 123);
    });

    testWidgets('handles decimal input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 0.0}, // Start with double
              fields: [FormixFieldConfig(id: numField, initialValue: 0.0)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '123.45');
      await tester.pump();

      expect(find.text('123.45'), findsOneWidget);

      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      expect(controller.getValue(numField), 123.45);
    });

    testWidgets('enforces minimum constraint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 50},
              fields: [FormixFieldConfig(id: numField, initialValue: 50)],
              child: FormixNumberFormField(fieldId: numField, min: 10),
            ),
          ),
        ),
      );

      // Try to enter value below minimum
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();

      // Text should show the invalid input (to allow correction)
      expect(find.text('5'), findsOneWidget);

      // But the controller value should remain unchanged
      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      expect(controller.getValue(numField), 50); // Should still be 50
    });

    testWidgets('enforces maximum constraint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 50},
              fields: [FormixFieldConfig(id: numField, initialValue: 50)],
              child: FormixNumberFormField(fieldId: numField, max: 100),
            ),
          ),
        ),
      );

      // Try to enter value above maximum
      await tester.enterText(find.byType(TextFormField), '150');
      await tester.pump();

      // Text should show the invalid input
      expect(find.text('150'), findsOneWidget);

      // But the controller value should remain unchanged
      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      expect(controller.getValue(numField), 50);
    });

    testWidgets('handles empty input by using default value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42},
              fields: [FormixFieldConfig(id: numField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      // Clear the text
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();

      // Should use the current value as default (42.0)
      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      expect(controller.getValue(numField), 42.0);
    });

    testWidgets('handles invalid input gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42},
              fields: [FormixFieldConfig(id: numField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      // Enter invalid text
      await tester.enterText(find.byType(TextFormField), 'not-a-number');
      await tester.pump();

      // Text should show the invalid input
      expect(find.text('not-a-number'), findsOneWidget);

      // Controller value should remain unchanged
      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      expect(controller.getValue(numField), 42);
    });

    testWidgets('updates text when value changes externally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42},
              fields: [FormixFieldConfig(id: numField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);

      // Change value externally
      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      controller.setValue(numField, 99);
      await tester.pump();

      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('shows validation error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(
                  id: numField,
                  validator: (value) => (value ?? 0) < 10 ? 'Must be at least 10' : null,
                ),
              ],
              child: FormixNumberFormField(
                fieldId: numField,
                decoration: const InputDecoration(labelText: 'Number'),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();

      expect(find.text('Must be at least 10'), findsOneWidget);
    });

    testWidgets('shows loading indicator during validation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(
                  id: numField,
                  asyncValidator: (value) async {
                    await Future.delayed(const Duration(milliseconds: 100));
                    return null;
                  },
                ),
              ],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.pump();

      // Should show loading indicator (CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows dirty indicator when field is modified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42},
              fields: [FormixFieldConfig(id: numField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      // Initially clean, no suffix icon
      expect(find.byIcon(Icons.edit), findsNothing);

      await tester.enterText(find.byType(TextFormField), '43');
      await tester.pump();

      // Should show dirty indicator
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('preserves focus state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42},
              fields: [FormixFieldConfig(id: numField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.tap(textField);
      await tester.pump();

      // Check that the text field is focused by verifying it has primary focus
      expect(FocusManager.instance.primaryFocus?.hasFocus, true);
    });

    testWidgets('handles controller override', (tester) async {
      final customController = FormixController(
        initialValue: {'num_field': 99},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormixNumberFormField(
              fieldId: numField,
              controller: customController,
            ),
          ),
        ),
      );

      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('applies custom decoration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42},
              fields: [FormixFieldConfig(id: numField, initialValue: 42)],
              child: FormixNumberFormField(
                fieldId: numField,
                decoration: const InputDecoration(
                  labelText: 'Custom Label',
                  hintText: 'Enter a number',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Label'), findsOneWidget);
      expect(find.text('Enter a number'), findsOneWidget);
      expect(find.byIcon(Icons.numbers), findsOneWidget);
    });

    testWidgets('maintains type consistency for int fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'int_field': 42},
              fields: [FormixFieldConfig(id: intField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: intField),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '123.7');
      await tester.pump();

      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      final value = controller.getValue(intField);

      expect(value, isA<int>());
      expect(value, 123); // Should be truncated to int
    });

    testWidgets('maintains type consistency for double fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'double_field': 42.0},
              fields: [
                FormixFieldConfig(id: doubleField, initialValue: 42.0),
              ],
              child: FormixNumberFormField(fieldId: doubleField),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.pump();

      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      final value = controller.getValue(doubleField);

      expect(value, isA<double>());
      expect(value, 123.0);
    });

    testWidgets('handles null initial values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: numField)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      // Should display empty text
      expect(find.text(''), findsOneWidget);

      final controller = Formix.of(tester.element(find.byType(TextFormField)));
      expect(controller.getValue(numField), isNull);
    });

    testWidgets('disposes resources properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'num_field': 42},
              fields: [FormixFieldConfig(id: numField, initialValue: 42)],
              child: FormixNumberFormField(fieldId: numField),
            ),
          ),
        ),
      );

      // Widget should be present
      expect(find.byType(TextFormField), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(
        MaterialApp(home: Container()),
      );

      // Widget should be disposed
      expect(find.byType(TextFormField), findsNothing);
    });
  });
}
