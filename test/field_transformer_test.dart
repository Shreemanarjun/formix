import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixFieldTransformer', () {
    late FormixFieldID<String> sourceField;
    late FormixFieldID<int> targetField;

    setUp(() {
      sourceField = const FormixFieldID<String>('source');
      targetField = const FormixFieldID<int>('target');
    });

    testWidgets('build returns SizedBox.shrink', (tester) async {
      final widget = FormixFieldTransformer<String, int>(
        sourceField: sourceField,
        targetField: targetField,
        transform: (value) => value?.length ?? 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'source': 'initial', 'target': 0},
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      expect(find.byWidget(widget), findsOneWidget);
      // The widget should render as a SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('transforms value on source change', (tester) async {
      final widget = FormixFieldTransformer<String, int>(
        sourceField: sourceField,
        targetField: targetField,
        transform: (value) => value?.length ?? 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'source': 'Hi', 'target': 0},
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      // Get controller to check values
      final controller = Formix.of(
        tester.element(find.byType(FormixFieldTransformer<String, int>)),
      )!;

      // Initial value should be transformed
      expect(controller.getValue(targetField), 2);

      // Change source value
      controller.setValue(sourceField, 'Hello');
      await tester.pump();

      expect(controller.getValue(targetField), 5);
    });

    testWidgets('handles null source value', (tester) async {
      final widget = FormixFieldTransformer<String, int>(
        sourceField: sourceField,
        targetField: targetField,
        transform: (value) => value?.length ?? 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'source': null, 'target': 0},
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldTransformer<String, int>)),
      )!;

      expect(controller.getValue(targetField), 0);

      // Change source to non-null
      controller.setValue(sourceField, 'Test');
      await tester.pump();

      expect(controller.getValue(targetField), 4);
    });

    testWidgets('handles errors gracefully in debug mode', (tester) async {
      final widget = FormixFieldTransformer<String, int>(
        sourceField: sourceField,
        targetField: targetField,
        transform: (value) {
          throw Exception('Test error');
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'source': 'initial', 'target': 100},
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldTransformer<String, int>)),
      )!;

      // Should not crash, target field should keep its initial value
      expect(controller.getValue(targetField), 100);
    });

    testWidgets('updates listeners when properties change', (tester) async {
      const newSourceField = FormixFieldID<String>('newSource');

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'source': 'old',
              'newSource': 'new',
              'target': 0,
            },
            fields: [
              FormixFieldConfig(id: sourceField),
              const FormixFieldConfig(id: newSourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: FormixFieldTransformer<String, int>(
              sourceField: sourceField,
              targetField: targetField,
              transform: (value) => value?.length ?? 0,
            ),
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldTransformer<String, int>)),
      )!;

      expect(controller.getValue(targetField), 3); // "old".length

      // Update widget to listen to newSourceField
      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'source': 'old',
              'newSource': 'new',
              'target': 0,
            },
            fields: [
              FormixFieldConfig(id: sourceField),
              const FormixFieldConfig(id: newSourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: FormixFieldTransformer<String, int>(
              sourceField: newSourceField,
              targetField: targetField,
              transform: (value) => value?.length ?? 0,
            ),
          ),
        ),
      );

      // Should update immediately with new source's value
      // "new".length is also 3, so let's check listeners update implicitly
      // by changing value of newSource
      controller.setValue(newSourceField, 'newer');
      await tester.pump();
      expect(controller.getValue(targetField), 5);

      // Changing old source should no longer affect target
      controller.setValue(sourceField, 'very long string');
      await tester.pump();
      expect(controller.getValue(targetField), 5);
    });

    testWidgets('select property limits transformations to specific object changes', (tester) async {
      const objectSourceField = FormixFieldID<Map<String, dynamic>>('obj_source');
      int transformCount = 0;

      final widget = FormixFieldTransformer<Map<String, dynamic>, String>(
        sourceField: objectSourceField,
        targetField: sourceField, // reusing sourceField ID as target for string outcome
        select: (user) => user?['name'],
        transform: (user) {
          transformCount++;
          return (user?['name'] as String? ?? '').toUpperCase();
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'obj_source': {'name': 'John', 'age': 25},
              'source': 'JOHN',
            },
            fields: [
              const FormixFieldConfig(id: objectSourceField),
              FormixFieldConfig(id: sourceField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(tester.element(find.byType(FormixFieldTransformer<Map<String, dynamic>, String>)))!;

      // Initial transform on mount
      expect(transformCount, 1);
      expect(controller.getValue(sourceField), 'JOHN');

      // Change age (unselected property)
      controller.setValue(objectSourceField, {'name': 'John', 'age': 26});
      await tester.pump();

      // Should NOT have triggered another transform
      expect(transformCount, 1);
      expect(controller.getValue(sourceField), 'JOHN');

      // Change name (selected property)
      controller.setValue(objectSourceField, {'name': 'Jane', 'age': 26});
      await tester.pump();

      // SHOULD have triggered another transform
      expect(transformCount, 2);
      expect(controller.getValue(sourceField), 'JANE');
    });
  });
}
