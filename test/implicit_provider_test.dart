import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Implicit Formix Provider Tests', () {
    testWidgets('FormixFieldWidget works implicitly', (tester) async {
      const fieldId = FormixFieldID<String>('test_field');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixTextFormField(
                fieldId: fieldId,
                initialValue: 'Implicit',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
      expect(find.text('Implicit'), findsOneWidget);
    });

    testWidgets('FormixDependentField works implicitly', (tester) async {
      const sourceId = FormixFieldID<bool>('source');
      const targetId = FormixFieldID<String>('target');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  const FormixCheckboxFormField(
                    fieldId: sourceId,
                    initialValue: false,
                    title: Text('Show Field'),
                  ),
                  FormixDependentField<bool>(
                    fieldId: sourceId,
                    builder: (context, value) {
                      if (value == true) {
                        return const FormixTextFormField(fieldId: targetId, initialValue: 'Target');
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
      expect(find.text('Target'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(find.text('Target'), findsOneWidget);
    });

    testWidgets('FormixFieldTransformer works implicitly', (tester) async {
      const sourceId = FormixFieldID<String>('source');
      const targetId = FormixFieldID<int>('target');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  const FormixTextFormField(fieldId: sourceId, initialValue: 'abc'),
                  FormixFieldTransformer<String, int>(
                    sourceField: sourceId,
                    targetField: targetId,
                    transform: (val) => val?.length ?? 0,
                  ),
                  FormixDependentField<int>(
                    fieldId: targetId,
                    builder: (context, val) => Text('Length: $val'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(); // Allow transformer to run

      expect(find.text('Length: 3'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'abcde');
      await tester.pumpAndSettle();

      expect(find.text('Length: 5'), findsOneWidget);
    });

    testWidgets('FormixFieldAsyncTransformer works implicitly', (tester) async {
      const sourceId = FormixFieldID<String>('source');
      const targetId = FormixFieldID<String>('target');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  const FormixTextFormField(fieldId: sourceId, initialValue: 'a'),
                  FormixFieldAsyncTransformer<String, String>(
                    sourceField: sourceId,
                    targetField: targetId,
                    transform: (val) async {
                      await Future.delayed(const Duration(milliseconds: 10));
                      return 'Async: $val';
                    },
                  ),
                  FormixDependentField<String>(
                    fieldId: targetId,
                    builder: (context, val) => Text('Result: $val'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Result: Async: a'), findsOneWidget);
    });

    testWidgets('FormixFieldDerivation works implicitly', (tester) async {
      const fieldA = FormixFieldID<int>('a');
      const fieldB = FormixFieldID<int>('b');
      const resultField = FormixFieldID<int>('result');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const FormixTextFormField(fieldId: FormixFieldID<String>('a_str'), initialValue: '10'),
                    const FormixTextFormField(fieldId: FormixFieldID<String>('b_str'), initialValue: '20'),

                    FormixFieldTransformer<String, int>(
                      sourceField: const FormixFieldID<String>('a_str'),
                      targetField: fieldA,
                      transform: (val) => int.tryParse(val ?? '') ?? 0,
                    ),
                    FormixFieldTransformer<String, int>(
                      sourceField: const FormixFieldID<String>('b_str'),
                      targetField: fieldB,
                      transform: (val) => int.tryParse(val ?? '') ?? 0,
                    ),

                    FormixFieldDerivation(
                      dependencies: const [fieldA, fieldB],
                      targetField: resultField,
                      derive: (values) {
                        final a = values[fieldA] as int? ?? 0;
                        final b = values[fieldB] as int? ?? 0;
                        return a + b;
                      },
                    ),

                    FormixDependentField<int>(
                      fieldId: resultField,
                      builder: (context, val) => Text('Sum: $val'),
                    ),
                  ],
                ), // Column
              ), // SingleChildScrollView
            ), // Formix
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Sum: 30'), findsOneWidget);
    });

    testWidgets('FormixSection works implicitly', (tester) async {
      const fieldId = FormixFieldID<String>('section_field');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixSection(
                fields: [],
                child: FormixTextFormField(
                  fieldId: fieldId,
                  initialValue: 'Section Value',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
      expect(find.text('Section Value'), findsOneWidget);
    });

    testWidgets('SliverFormixArray works implicitly', (tester) async {
      const arrayId = FormixArrayID<String>('test_array');

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, id, scope) {
                      return Text('Item $index');
                    },
                    emptyBuilder: (context, scope) => const Text('Empty Array'),
                  ),
                ],
              ),
              floatingActionButton: Builder(
                builder: (context) {
                  return FloatingActionButton(
                    onPressed: () {
                      // This will now find the controller from the Formix above
                      Formix.controllerOf(context)!.addArrayItem(arrayId, 'Item');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
      expect(find.text('Empty Array'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('FormixDependentAsyncField works implicitly', (tester) async {
      const depId = FormixFieldID<String>('dependency');
      const asyncId = FormixFieldID<String>('async_result');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  const FormixTextFormField(fieldId: depId, initialValue: 'trigger'),
                  FormixDependentAsyncField<String, String>(
                    fieldId: asyncId,
                    dependency: depId,
                    future: (val) async {
                      await Future.delayed(const Duration(milliseconds: 10));
                      return 'Fetched: $val';
                    },
                    builder: (context, state) {
                      if (state.asyncState.isLoading) return const Text('Loading...');
                      return Text(state.asyncState.value ?? 'No Data');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Fetched: trigger'), findsOneWidget);
    });

    testWidgets('FormixNavigationGuard works implicitly (construction only)', (tester) async {
      const fieldId = FormixFieldID<String>('guard_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixNavigationGuard(
                enabled: true,
                showDirtyDialog: (context) async => false, // Always prevent pop
                child: const FormixTextFormField(
                  fieldId: fieldId,
                  initialValue: 'init',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
      expect(find.text('init'), findsOneWidget);
    });

    testWidgets('FormixFieldSelector works implicitly', (tester) async {
      const fieldId = FormixFieldID<String>('selector_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  const FormixTextFormField(
                    fieldId: fieldId,
                    initialValue: 'SelectMe',
                  ),
                  FormixFieldSelector<String>(
                    fieldId: fieldId,
                    builder: (context, info, child) {
                      return Text('Selector: ${info.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
      expect(find.text('Selector: SelectMe'), findsOneWidget);

      await tester.enterText(find.byType(FormixTextFormField), 'Changed');
      await tester.pump();

      expect(find.text('Selector: Changed'), findsOneWidget);
    });
  });
}
