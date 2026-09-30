import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Mock API for testing
Future<List<String>> fetchModels(String carMake) async {
  await Future.delayed(const Duration(milliseconds: 10)); // Simulate latency
  if (carMake == 'Tesla') return ['Model S', 'Model 3', 'Model X', 'Model Y'];
  if (carMake == 'Ford') return ['Mustang', 'F-150', 'Focus'];
  return [];
}

void main() {
  group('Async Data & Dependent Dropdowns', () {
    const makeField = FormixFieldID<String>('make');
    const modelField = FormixFieldID<String>('model');

    testWidgets('Async Dropdown loads options based on dependency', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  const FormixDropdownFormField<String>(
                    fieldId: makeField,
                    items: [
                      DropdownMenuItem(value: 'Tesla', child: Text('Tesla')),
                      DropdownMenuItem(value: 'Ford', child: Text('Ford')),
                    ],
                    decoration: InputDecoration(labelText: 'Make'),
                  ),
                  FormixDependentAsyncField<List<String>, String>(
                    fieldId: const FormixFieldID<List<String>>('model_options'),
                    dependency: makeField,
                    future: (make) => fetchModels(make ?? ''),
                    loadingBuilder: (context) => const Text('Loading models...'),
                    asyncErrorBuilder: (context, e) => Text('Error: $e'),
                    builder: (context, state) {
                      final models = state.asyncState.value ?? const <String>[];
                      return FormixDropdownFormField<String>(
                        fieldId: modelField,
                        items: models
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        decoration: const InputDecoration(labelText: 'Model'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Loading models...'), findsOneWidget);
      await tester.pumpAndSettle();

      // Should show empty dropdown or nothing (empty list returned for '')
      // Since it's 'data' state, FormixDropdownFormField is built.
      // But we have 2 dropdowns now (Make and Model). We want to ensure Model is present.
      expect(find.text('Loading models...'), findsNothing);
      expect(find.byType(FormixDropdownFormField<String>), findsNWidgets(2));

      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixDropdownFormField<String>).last),
      );
      if (controller == null) fail('Formix controller not found');

      await tester.tap(find.byType(FormixDropdownFormField<String>).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tesla').last);
      await tester.pumpAndSettle();

      await tester.pumpAndSettle();

      await tester.tap(find.byType(FormixDropdownFormField<String>).last);
      await tester.pumpAndSettle();

      // Verify options are loaded
      expect(find.text('Model S').last, findsOneWidget);
      expect(find.text('Model 3').last, findsOneWidget);

      // Select 'Model 3'
      await tester.tap(find.text('Model 3').last);
      await tester.pumpAndSettle();

      expect(controller.getValue(modelField), 'Model 3');
    });

    testWidgets('Async value is correctly set via FormixAsyncField', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('async_field');
      final future = Future.delayed(
        const Duration(milliseconds: 10),
        () => 'Loaded Value',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixAsyncField<String>(
                fieldId: fieldId,
                future: future,
                builder: (context, state) {
                  return Text(state.value ?? 'No Value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixAsyncField<String>)),
      );
      expect(controller, isNotNull);
      expect(controller!.getValue(fieldId), 'Loaded Value');
      expect(find.text('Loaded Value'), findsOneWidget);
    });
  });
}
