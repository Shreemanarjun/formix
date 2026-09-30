import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
import 'package:signals_flutter/signals_flutter.dart' show AsyncState;

void main() {
  group('FormixAsyncField Production Tests', () {
    testWidgets('Shows loading state initially', (tester) async {
      const fieldId = FormixFieldID<String>('async_loading');
      final future = Future.delayed(
        const Duration(milliseconds: 10),
        () => 'Loaded Data',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixAsyncField<String>(
                fieldId: fieldId,
                future: future,
                builder: (context, state) => Text(state.value ?? 'No Data'),
                loadingBuilder: (context) => const Text('Custom Loading...'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Loading...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Loaded Data'), findsOneWidget);
    });

    testWidgets('Handles async errors gracefully', (tester) async {
      const fieldId = FormixFieldID<String>('async_error');
      final future = Future<String>.delayed(
        const Duration(milliseconds: 10),
        () => throw 'Failed to load',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixAsyncField<String>(
                fieldId: fieldId,
                future: future,
                builder: (context, state) => Text(state.value ?? 'No Data'),
                asyncErrorBuilder: (context, error) => Text('Error: $error'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Error: Failed to load'), findsOneWidget);
    });

    testWidgets('Integrates with validation (sync & async)', (tester) async {
      const fieldId = FormixFieldID<String>('async_validation');
      final future = Future.value('invalid_value');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixAsyncField<String>(
                fieldId: fieldId,
                future: future,
                validator: (value) => value == 'invalid_value' ? 'Invalid Value' : null,
                builder: (context, state) => Column(
                  children: [
                    Text('Value: ${state.value}'),
                    if (state.validation.errorMessage != null) Text(state.validation.errorMessage!),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixAsyncField<String>)),
      );
      expect(controller, isNotNull);
      controller!.setValue(fieldId, 'invalid_value');
      await tester.pumpAndSettle();

      expect(find.text('Invalid Value'), findsOneWidget);
    });

    testWidgets('Form submission includes async value', (tester) async {
      const fieldId = FormixFieldID<String>('async_submit');
      final future = Future.value('Submission Data');
      Map<String, dynamic>? submittedData;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  FormixAsyncField<String>(
                    fieldId: fieldId,
                    future: future,
                    builder: (context, state) => Text(state.value ?? ''),
                  ),
                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () {
                        Formix.controllerOf(context)!.submit(
                          onValid: (data) async {
                            submittedData = data;
                          },
                        );
                      },
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(submittedData, isNotNull);
      expect(submittedData!['async_submit'], 'Submission Data');
    });

    testWidgets('Updates when future changes', (tester) async {
      const fieldId = FormixFieldID<String>('async_update');
      final future1 = Future.value('Data 1');
      final future2 = Future.value('Data 2');

      final valueNotifier = ValueNotifier<Future<String>>(future1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: ValueListenableBuilder<Future<String>>(
                valueListenable: valueNotifier,
                builder: (context, future, _) {
                  return FormixAsyncField<String>(
                    fieldId: fieldId,
                    future: future,
                    builder: (context, state) => Text(state.value ?? 'No Data'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Data 1'), findsOneWidget);

      valueNotifier.value = future2;
      await tester.pumpAndSettle();

      expect(find.text('Data 2'), findsOneWidget);
    });

    testWidgets('Works with AsyncValue directly', (tester) async {
      const fieldId = FormixFieldID<String>('async_value_direct');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixAsyncField<String>(
                fieldId: fieldId,
                asyncValue: AsyncState.data('Direct Value'),
                builder: (context, state) => Text(state.value ?? 'No Data'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Direct Value'), findsOneWidget);

      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixAsyncField<String>)),
      );
      expect(controller!.getValue(fieldId), 'Direct Value');
    });
  });
}
