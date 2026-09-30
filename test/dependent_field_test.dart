import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixDependentField', () {
    testWidgets('rebuilds when watched field value changes', (tester) async {
      const watchedField = FormixFieldID<String>('watched_field');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'watched_field': 'initial'},
              fields: const [
                FormixFieldConfig(id: watchedField, initialValue: 'initial'),
              ],
              child: FormixDependentField<String>(
                fieldId: watchedField,
                builder: (context, value) {
                  buildCount++;
                  return Text('Value: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: initial'), findsOneWidget);
      expect(buildCount, 1);

      // Change the watched field value
      final controller = Formix.of(
        tester.element(find.text('Value: initial')),
      );
      controller.setValue(watchedField, 'updated');

      await tester.pump();

      expect(find.text('Value: updated'), findsOneWidget);
      expect(buildCount, 2); // Should have rebuilt
      controller.setValue(watchedField, 'updated');
      await tester.pump();
      await tester.pump();
      expect(
        buildCount,
        2,
      ); // should not rebuild as value is same before as it is
    });

    testWidgets('does not rebuild when unwatched field changes', (
      tester,
    ) async {
      const watchedField = FormixFieldID<String>('watched_field');
      const otherField = FormixFieldID<String>('other_field');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {
                'watched_field': 'initial',
                'other_field': 'other',
              },
              fields: const [
                FormixFieldConfig(id: watchedField, initialValue: 'initial'),
                FormixFieldConfig(id: otherField, initialValue: 'other'),
              ],
              child: FormixDependentField<String>(
                fieldId: watchedField,
                builder: (context, value) {
                  buildCount++;
                  return Text('Watched: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Watched: initial'), findsOneWidget);
      expect(buildCount, 1);

      // Change the unwatched field
      final controller = Formix.of(
        tester.element(find.text('Watched: initial')),
      );
      controller.setValue(otherField, 'changed');

      await tester.pump();

      // Should still show the same value and not have rebuilt
      expect(find.text('Watched: initial'), findsOneWidget);
      expect(buildCount, 1); // Should not have rebuilt
    });

    testWidgets('works with different field types - int', (tester) async {
      const intField = FormixFieldID<int>('int_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'int_field': 42},
              fields: const [FormixFieldConfig(id: intField, initialValue: 42)],
              child: FormixDependentField<int>(
                fieldId: intField,
                builder: (context, value) {
                  return Text('Number: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Number: 42'), findsOneWidget);

      // Change value
      final controller = Formix.of(tester.element(find.text('Number: 42')));
      controller.setValue(intField, 99);

      await tester.pump();

      expect(find.text('Number: 99'), findsOneWidget);
    });

    testWidgets('works with different field types - bool', (tester) async {
      const boolField = FormixFieldID<bool>('bool_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'bool_field': true},
              fields: const [FormixFieldConfig(id: boolField, initialValue: true)],
              child: FormixDependentField<bool>(
                fieldId: boolField,
                builder: (context, value) {
                  return Text('Boolean: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Boolean: true'), findsOneWidget);

      // Change value
      final controller = Formix.of(tester.element(find.text('Boolean: true')));
      controller.setValue(boolField, false);

      await tester.pump();

      expect(find.text('Boolean: false'), findsOneWidget);
    });

    testWidgets('works with different field types - double', (tester) async {
      const doubleField = FormixFieldID<double>('double_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'double_field': 3.14},
              fields: const [
                FormixFieldConfig(id: doubleField, initialValue: 3.14),
              ],
              child: FormixDependentField<double>(
                fieldId: doubleField,
                builder: (context, value) {
                  return Text('Double: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Double: 3.14'), findsOneWidget);

      // Change value
      final controller = Formix.of(tester.element(find.text('Double: 3.14')));
      controller.setValue(doubleField, 2.71);

      await tester.pump();

      expect(find.text('Double: 2.71'), findsOneWidget);
    });

    testWidgets('handles null values correctly', (tester) async {
      const nullableField = FormixFieldID<String?>('nullable_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [FormixFieldConfig<String?>(id: nullableField)],
              child: FormixDependentField<String?>(
                fieldId: nullableField,
                builder: (context, value) {
                  return Text('Value: ${value ?? "null"}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: null'), findsOneWidget);

      // Set a value
      final controller = Formix.of(tester.element(find.text('Value: null')));
      controller.setValue(nullableField, 'not null');

      await tester.pump();

      expect(find.text('Value: not null'), findsOneWidget);

      // Set back to null
      controller.setValue(nullableField, null);

      await tester.pump();

      expect(find.text('Value: null'), findsOneWidget);
    });

    testWidgets('uses custom controller provider when provided', (
      tester,
    ) async {
      const customField = FormixFieldID<String>('custom_field');
      final customController = FormixController(
        initialValue: {'custom_field': 'custom_value'},
      );
      addTearDown(customController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormixDependentField<String>(
              fieldId: customField,
              controller: customController,
              builder: (context, value) {
                return Text('Custom: $value');
              },
            ),
          ),
        ),
      );

      expect(find.text('Custom: custom_value'), findsOneWidget);
    });

    testWidgets(
      'falls back to Formix.of(context) when no controller provider',
      (tester) async {
        const contextField = FormixFieldID<String>('context_field');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                initialValue: const {'context_field': 'from_context'},
                fields: const [
                  FormixFieldConfig(
                    id: contextField,
                    initialValue: 'from_context',
                  ),
                ],
                child: FormixDependentField<String>(
                  fieldId: contextField,
                  builder: (context, value) {
                    return Text('Context: $value');
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Context: from_context'), findsOneWidget);
      },
    );

    testWidgets(
      'falls back to default provider when no context or custom provider',
      (tester) async {
        const defaultField = FormixFieldID<String>('default_field');
        final defaultController = FormixController(
          initialValue: {'default_field': 'from_default'},
        );
        addTearDown(defaultController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FormixDependentField<String>(
                fieldId: defaultField,
                controller: defaultController,
                builder: (context, value) {
                  return Text('Default: $value');
                },
              ),
            ),
          ),
        );

        expect(find.text('Default: from_default'), findsOneWidget);
      },
    );

    testWidgets('builder receives correct BuildContext', (tester) async {
      const contextField = FormixFieldID<String>('context_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'context_field': 'test'},
              fields: const [
                FormixFieldConfig(id: contextField, initialValue: 'test'),
              ],
              child: FormixDependentField<String>(
                fieldId: contextField,
                builder: (context, value) {
                  final mediaQuery = MediaQuery.maybeOf(context);

                  final hasMediaQuery = mediaQuery != null;
                  return Text(
                    'Has MediaQuery: $hasMediaQuery, Value: $value',
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Has MediaQuery: true, Value: test'), findsOneWidget);
    });

    testWidgets('handles complex data types', (tester) async {
      const listField = FormixFieldID<List<String>>('list_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {
                'list_field': ['a', 'b', 'c'],
              },
              fields: const [
                FormixFieldConfig(
                  id: listField,
                  initialValue: ['a', 'b', 'c'],
                ),
              ],
              child: FormixDependentField<List<String>>(
                fieldId: listField,
                builder: (context, value) {
                  return Text('List length: ${value?.length ?? 0}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('List length: 3'), findsOneWidget);

      // Change the list
      final controller = Formix.of(
        tester.element(find.text('List length: 3')),
      );
      controller.setValue(listField, ['x', 'y']);

      await tester.pump();

      expect(find.text('List length: 2'), findsOneWidget);
    });

    testWidgets('works with enum-like string values', (tester) async {
      const statusField = FormixFieldID<String>('status');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'status': 'active'},
              fields: const [
                FormixFieldConfig(id: statusField, initialValue: 'active'),
              ],
              child: FormixDependentField<String>(
                fieldId: statusField,
                builder: (context, value) {
                  return Text('Status: ${value?.toUpperCase()}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Status: ACTIVE'), findsOneWidget);

      // Change status
      final controller = Formix.of(
        tester.element(find.text('Status: ACTIVE')),
      );
      controller.setValue(statusField, 'inactive');

      await tester.pump();

      expect(find.text('Status: INACTIVE'), findsOneWidget);
    });

    testWidgets('handles rapid consecutive changes', (tester) async {
      const counterField = FormixFieldID<int>('counter');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'counter': 0},
              fields: const [FormixFieldConfig(id: counterField, initialValue: 0)],
              child: FormixDependentField<int>(
                fieldId: counterField,
                builder: (context, value) {
                  buildCount++;
                  return Text('Count: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(buildCount, 1);

      // Make rapid changes
      final controller = Formix.of(tester.element(find.text('Count: 0')));

      controller.setValue(counterField, 1);
      await tester.pump();
      controller.setValue(counterField, 2);
      await tester.pump();
      controller.setValue(counterField, 3);
      await tester.pump();

      expect(find.text('Count: 3'), findsOneWidget);
      expect(
        buildCount,
        greaterThanOrEqualTo(2),
      ); // At least initial + final change
    });

    testWidgets('works with validation state changes', (tester) async {
      const validatedField = FormixFieldID<String>('validated_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(
                  id: validatedField,
                  validator: (v) => (v?.length ?? 0) < 3 ? 'Too short' : null,
                ),
              ],
              child: FormixDependentField<String>(
                fieldId: validatedField,
                builder: (context, value) {
                  return Text('Value: ${value ?? "null"}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: null'), findsOneWidget);

      // Set invalid value
      final controller = Formix.of(tester.element(find.text('Value: null')));
      controller.setValue(validatedField, 'ab');

      await tester.pump();

      expect(find.text('Value: ab'), findsOneWidget);

      // Set valid value
      controller.setValue(validatedField, 'valid');

      await tester.pump();

      expect(find.text('Value: valid'), findsOneWidget);
    });

    testWidgets(
      'works with multiple dependent fields watching different fields',
      (tester) async {
        const field1 = FormixFieldID<String>('field1');
        const field2 = FormixFieldID<String>('field2');

        int buildCount1 = 0;
        int buildCount2 = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                initialValue: const {'field1': 'value1', 'field2': 'value2'},
                fields: const [
                  FormixFieldConfig(id: field1, initialValue: 'value1'),
                  FormixFieldConfig(id: field2, initialValue: 'value2'),
                ],
                child: Column(
                  children: [
                    FormixDependentField<String>(
                      fieldId: field1,
                      builder: (context, value) {
                        buildCount1++;
                        return Text('Field1: $value');
                      },
                    ),
                    FormixDependentField<String>(
                      fieldId: field2,
                      builder: (context, value) {
                        buildCount2++;
                        return Text('Field2: $value');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Field1: value1'), findsOneWidget);
        expect(find.text('Field2: value2'), findsOneWidget);
        expect(buildCount1, 1);
        expect(buildCount2, 1);

        // Change field1
        final controller = Formix.of(
          tester.element(find.text('Field1: value1')),
        );
        controller.setValue(field1, 'changed1');

        await tester.pump();

        expect(find.text('Field1: changed1'), findsOneWidget);
        expect(find.text('Field2: value2'), findsOneWidget); // Unchanged
        expect(buildCount1, 2);
        expect(buildCount2, 1); // Should not have rebuilt
      },
    );

    testWidgets('handles field removal gracefully', (tester) async {
      const tempField = FormixFieldID<String>('temp_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'temp_field': 'exists'},
              fields: const [
                FormixFieldConfig(id: tempField, initialValue: 'exists'),
              ],
              child: FormixDependentField<String>(
                fieldId: tempField,
                builder: (context, value) {
                  return Text('Temp: ${value ?? "gone"}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Temp: exists'), findsOneWidget);

      // Remove the field
      final controller = Formix.of(tester.element(find.text('Temp: exists')));
      controller.unregisterField(tempField);

      await tester.pump();

      expect(find.text('Temp: gone'), findsOneWidget);
    });
  });
}
