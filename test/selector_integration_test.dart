import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Selector Integration Tests', () {
    testWidgets('FormixDependentField supports selectors', (tester) async {
      const objectField = FormixFieldID<Map<String, dynamic>>('obj');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'obj': {'name': 'John', 'age': 25},
            },
            fields: const [
              FormixFieldConfig(id: objectField),
            ],
            child: FormixDependentField<Map<String, dynamic>>(
              fieldId: objectField,
              select: (val) => val?['name'],
              builder: (context, value) {
                buildCount++;
                return Text('User: ${value?['name']}');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('User: John'), findsOneWidget);
      final initialBuildCount = buildCount;

      final controller = Formix.of(tester.element(find.byType(FormixDependentField<Map<String, dynamic>>)))!;

      // Change age (unselected)
      controller.setValue(objectField, <String, dynamic>{'name': 'John', 'age': 26});
      await tester.pump();
      expect(buildCount, initialBuildCount);

      // Change name (selected)
      controller.setValue(objectField, <String, dynamic>{'name': 'Jane', 'age': 26});
      await tester.pump();
      expect(buildCount, initialBuildCount + 1);
      expect(find.text('User: Jane'), findsOneWidget);
    });

    testWidgets('FormixDependentAsyncField supports selectors', (tester) async {
      const objectField = FormixFieldID<Map<String, dynamic>>('obj');
      const targetField = FormixFieldID<String>('target');
      int futureCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'obj': {'name': 'John', 'age': 25},
            },
            fields: const [
              FormixFieldConfig(id: objectField),
              FormixFieldConfig(id: targetField),
            ],
            child: FormixDependentAsyncField<String, Map<String, dynamic>>(
              fieldId: targetField,
              dependency: objectField,
              select: (val) => val?['name'],
              future: (val) async {
                futureCallCount++;
                return 'Hello ${val?['name']}';
              },
              builder: (context, state) {
                return Text('Result: ${state.asyncState.value}');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(futureCallCount, 1);
      expect(find.text('Result: Hello John'), findsOneWidget);

      final controller = Formix.of(tester.element(find.byType(FormixDependentAsyncField<String, Map<String, dynamic>>)))!;

      // Change age (unselected)
      controller.setValue(objectField, <String, dynamic>{'name': 'John', 'age': 26});
      await tester.pumpAndSettle();
      expect(futureCallCount, 1);

      // Change name (selected)
      controller.setValue(objectField, <String, dynamic>{'name': 'Jane', 'age': 26});
      await tester.pumpAndSettle();
      expect(futureCallCount, 2);
      expect(find.text('Result: Hello Jane'), findsOneWidget);
    });

    testWidgets('FormixFieldDerivation supports selectors', (tester) async {
      const objectField = FormixFieldID<Map<String, dynamic>>('obj');
      const targetField = FormixFieldID<String>('target');
      int deriveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'obj': {'name': 'John', 'age': 25},
              'target': '',
            },
            fields: const [
              FormixFieldConfig(id: objectField),
              FormixFieldConfig(id: targetField),
            ],
            child: FormixFieldDerivation(
              dependencies: const [objectField],
              selectors: {
                objectField: (val) => (val as Map?)?['name'],
              },
              targetField: targetField,
              derive: (values) {
                deriveCount++;
                final user = values[objectField] as Map?;
                return 'DERIVED: ${user?['name']}';
              },
            ),
          ),
        ),
      );

      final controller = Formix.of(tester.element(find.byType(FormixFieldDerivation)))!;

      await tester.pump(); // for initial microtask recalculation
      expect(deriveCount, 1);
      expect(controller.getValue(targetField), 'DERIVED: John');

      // Change age (unselected)
      controller.setValue(objectField, <String, dynamic>{'name': 'John', 'age': 26});
      await tester.pump();
      expect(deriveCount, 1);

      // Change name (selected)
      controller.setValue(objectField, <String, dynamic>{'name': 'Jane', 'age': 26});
      await tester.pump();
      expect(deriveCount, 2);
      expect(controller.getValue(targetField), 'DERIVED: Jane');
    });

    testWidgets('FormixFieldSelector supports selectors', (tester) async {
      const objectField = FormixFieldID<Map<String, dynamic>>('obj');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'obj': {'name': 'John', 'age': 25},
            },
            fields: const [
              FormixFieldConfig(id: objectField),
            ],
            child: FormixFieldSelector<Map<String, dynamic>>(
              fieldId: objectField,
              select: (val) => val?['name'],
              listenToValidation: false,
              listenToDirty: false,
              builder: (context, info, _) {
                buildCount++;
                return Text('Selector Name: ${info.value?['name']}');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      final initialBuildCount = buildCount;

      final controller = Formix.of(tester.element(find.byType(FormixFieldSelector<Map<String, dynamic>>)))!;

      // Change age
      controller.setValue(objectField, <String, dynamic>{'name': 'John', 'age': 26});
      await tester.pump();
      expect(buildCount, initialBuildCount);

      // Change name
      controller.setValue(objectField, <String, dynamic>{'name': 'Jane', 'age': 26});
      await tester.pump();
      expect(buildCount, initialBuildCount + 1);
      expect(find.text('Selector Name: Jane'), findsOneWidget);
    });

    testWidgets('FormixFieldValueSelector supports selectors', (tester) async {
      const objectField = FormixFieldID<Map<String, dynamic>>('obj');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'obj': {'name': 'John', 'age': 25},
            },
            fields: const [
              FormixFieldConfig(id: objectField),
            ],
            child: FormixFieldValueSelector<Map<String, dynamic>>(
              fieldId: objectField,
              select: (val) => val?['name'],
              builder: (context, value, _) {
                buildCount++;
                return Text('Value Selector: ${value?['name']}');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      final initialBuildCount = buildCount;

      final controller = Formix.of(tester.element(find.byType(FormixFieldValueSelector<Map<String, dynamic>>)))!;

      // Change age
      controller.setValue(objectField, <String, dynamic>{'name': 'John', 'age': 26});
      await tester.pump();
      expect(buildCount, initialBuildCount);

      // Change name
      controller.setValue(objectField, <String, dynamic>{'name': 'Jane', 'age': 26});
      await tester.pump();
      expect(buildCount, initialBuildCount + 1);
      expect(find.text('Value Selector: Jane'), findsOneWidget);
    });
  });
}
