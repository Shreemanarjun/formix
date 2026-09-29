import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixFieldAsyncTransformer', () {
    late FormixFieldID<String> sourceField;
    late FormixFieldID<String> targetField;

    setUp(() {
      sourceField = const FormixFieldID<String>('source');
      targetField = const FormixFieldID<String>('target');
    });

    testWidgets('build returns SizedBox.shrink', (tester) async {
      await tester.runAsync(() async {
        final widget = FormixFieldAsyncTransformer<String, String>(
          sourceField: sourceField,
          targetField: targetField,
          transform: (value) async => (value ?? '').toUpperCase(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Formix(
              initialValue: const {'source': 'initial', 'target': 'target'},
              fields: [
                FormixFieldConfig(id: sourceField),
                FormixFieldConfig(id: targetField),
              ],
              child: widget,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byWidget(widget), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
      });
    });

    testWidgets('transforms value asynchronously on source change', (
      tester,
    ) async {
      final widget = FormixFieldAsyncTransformer<String, String>(
        sourceField: sourceField,
        targetField: targetField,
        transform: (value) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return (value ?? '').toUpperCase();
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'source': 'Hi', 'target': 'HI'},
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(
          find.byType(FormixFieldAsyncTransformer<String, String>),
        ),
      )!;

      // Wait for initial transform if any (none expected if values match)
      await tester.pumpAndSettle();

      // Change source value
      controller.setValue(sourceField, 'Hello');
      await tester.pump();

      // Should not be updated yet
      expect(controller.getValue(targetField), 'HI');

      // Wait for async transform
      await tester.pumpAndSettle();

      expect(controller.getValue(targetField), 'HELLO');
    });

    testWidgets('supports debounce', (tester) async {
      int transformCallCount = 0;

      final widget = FormixFieldAsyncTransformer<String, String>(
        sourceField: sourceField,
        targetField: targetField,
        debounce: const Duration(milliseconds: 200),
        transform: (value) async {
          transformCallCount++;
          return (value ?? '').toUpperCase();
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'source': 'start', 'target': 'START'},
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(
          find.byType(FormixFieldAsyncTransformer<String, String>),
        ),
      )!;

      // Wait for initial value debounce to settle completely
      await tester.pump(const Duration(seconds: 1));

      // Reset count after any initial calls
      transformCallCount = 0;

      // Rapidly change source value
      controller.setValue(sourceField, 'a');
      await tester.pump(const Duration(milliseconds: 50));

      controller.setValue(sourceField, 'ab');
      await tester.pump(const Duration(milliseconds: 50));

      controller.setValue(sourceField, 'abc');
      await tester.pump();

      // Wait for debounce and processing
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(transformCallCount, greaterThan(0));
      expect(transformCallCount, lessThan(3));
      expect(controller.getValue(targetField), 'ABC');
    });

    testWidgets('handles errors gracefully in debug mode', (tester) async {
      final widget = FormixFieldAsyncTransformer<String, String>(
        sourceField: sourceField,
        targetField: targetField,
        transform: (value) async {
          throw Exception('Async error');
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'source': 'initial', 'target': 'target'},
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(
          find.byType(FormixFieldAsyncTransformer<String, String>),
        ),
      )!;

      // Trigger error
      controller.setValue(sourceField, 'new');
      await tester.pumpAndSettle();

      // Should not crash, target field should keep its initial value
      expect(controller.getValue(targetField), 'target');
    });

    testWidgets('handles widget disposal gracefully', (tester) async {
      await tester.runAsync(() async {
        final widget = FormixFieldAsyncTransformer<String, String>(
          sourceField: sourceField,
          targetField: targetField,
          transform: (value) async {
            await Future.delayed(const Duration(milliseconds: 200));
            return 'Disposed result';
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Formix(
              initialValue: const {'source': 'start', 'target': 'start'},
              fields: [
                FormixFieldConfig(id: sourceField),
                FormixFieldConfig(id: targetField),
              ],
              child: widget,
            ),
          ),
        );

        final controller = Formix.of(
          tester.element(
            find.byType(FormixFieldAsyncTransformer<String, String>),
          ),
        )!;

        // Trigger async operation
        controller.setValue(sourceField, 'new');

        // Dispose widget immediately
        await tester.pumpWidget(Container());

        // Wait for async operation to theoretically complete
        await Future.delayed(const Duration(milliseconds: 300));
      });
    });

    testWidgets('select property limits transformations in FormixFieldAsyncTransformer', (tester) async {
      const objectSourceField = FormixFieldID<Map<String, dynamic>>('obj_source');
      int transformCount = 0;

      final widget = FormixFieldAsyncTransformer<Map<String, dynamic>, String>(
        sourceField: objectSourceField,
        targetField: targetField,
        select: (user) => user?['name'],
        transform: (user) async {
          transformCount++;
          return (user?['name'] as String? ?? '').toUpperCase();
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'obj_source': {'name': 'John', 'age': 25},
              'target': 'JOHN',
            },
            fields: [
              const FormixFieldConfig(id: objectSourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(tester.element(find.byType(FormixFieldAsyncTransformer<Map<String, dynamic>, String>)))!;

      // Initial transform on mount
      await tester.pumpAndSettle();
      expect(transformCount, 1);
      expect(controller.getValue(targetField), 'JOHN');

      // Change age (unselected property)
      controller.setValue(objectSourceField, {'name': 'John', 'age': 26});
      await tester.pumpAndSettle();

      // Should NOT have triggered another transform
      expect(transformCount, 1);
      expect(controller.getValue(targetField), 'JOHN');

      // Change name (selected property)
      controller.setValue(objectSourceField, {'name': 'Jane', 'age': 26});
      await tester.pumpAndSettle();

      // SHOULD have triggered another transform
      expect(transformCount, 2);
      expect(controller.getValue(targetField), 'JANE');
    });
  });
}
