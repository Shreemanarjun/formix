import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixAsyncField Production Grade Tests', () {
    testWidgets('Coordinated with isPending state to ensure submission safety', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('async_data');
      final completer = Completer<String>();
      bool submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  FormixAsyncField<String>(
                    fieldId: fieldId,
                    future: completer.future,
                    builder: (context, state) => Text(state.value ?? 'No Value'),
                    loadingBuilder: (context) => const Text('Loading...'),
                  ),
                  FormixBuilder(
                    builder: (context, scope) => ElevatedButton(
                      onPressed: () => scope.controller.submit(
                        onValid: (values) async {
                          submitted = true;
                        },
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Need to pump enough to trigger initState and the first build of AsyncField
      await tester.pump();
      expect(find.text('Loading...'), findsOneWidget);

      final controller = Formix.controllerOf(
        tester.element(find.text('Submit')),
      );

      // Wait for the microtask that updates pending state
      await tester.pump(Duration.zero);
      expect(
        controller!.state.isPending,
        isTrue,
        reason: 'Form should be pending while async field is loading',
      );

      // Attempt to submit while pending
      await tester.tap(find.text('Submit'));
      await tester.pump(); // Start submission process

      expect(
        controller.state.isSubmitting,
        isTrue,
        reason: 'Form should be in submitting state',
      );
      expect(
        submitted,
        isFalse,
        reason: 'Submission should wait for pending fields',
      );

      // Complete the future
      completer.complete('Ready');

      // Give time for the microtask and the submission loop
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();

      expect(controller.state.isPending, isFalse);
      expect(submitted, isTrue);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('Automatically re-triggers fetch on form reset via onRetry', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('reset_test');
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'Data $fetchCount';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: Column(
                children: [
                  FormixAsyncField<String>(
                    fieldId: fieldId,
                    future: fetchData(),
                    onRetry: fetchData,
                    builder: (context, state) => Text(state.value ?? ''),
                  ),
                  FormixBuilder(
                    builder: (context, scope) => ElevatedButton(
                      onPressed: () => scope.controller.reset(),
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Data 1'), findsOneWidget);
      expect(fetchCount, 1);

      // Reset form
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Data 2'), findsOneWidget);
      expect(fetchCount, 2);
    });

    testWidgets(
      'Race condition protection ensures only the latest future results are used',
      (tester) async {
        const fieldId = FormixFieldID<String>('race_test');
        final completer1 = Completer<String>();
        final completer2 = Completer<String>();

        final futureNotifier = ValueNotifier<Future<String>>(completer1.future);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                child: ValueListenableBuilder<Future<String>>(
                  valueListenable: futureNotifier,
                  builder: (context, future, _) => FormixAsyncField<String>(
                    fieldId: fieldId,
                    future: future,
                    builder: (context, state) => Text(state.value ?? 'No Value'),
                    loadingBuilder: (context) => const Text('Loading'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Loading'), findsOneWidget);

        // Update to second future before first completes
        futureNotifier.value = completer2.future;
        await tester.pump();

        // Resolve first future (should be ignored)
        completer1.complete('First');
        await tester.pump();

        // Resolve second future (should be accepted)
        completer2.complete('Second');
        await tester.pumpAndSettle();

        expect(find.text('Second'), findsOneWidget);
        expect(find.text('First'), findsNothing);
      },
    );

    testWidgets('Retry logic via manual refresh() works correctly', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('manual_refresh');
      int attempts = 0;

      // Use a controlled completer for the initial error to avoid uncaught exception during boot
      final initialCompleter = Completer<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixAsyncField<String>(
                fieldId: fieldId,
                future: initialCompleter.future,
                onRetry: () async {
                  attempts++;
                  return 'Attempt $attempts';
                },
                asyncErrorBuilder: (context, error) => Column(
                  children: [
                    Text('Error: $error'),
                    FormixBuilder(
                      builder: (context, scope) {
                        return ElevatedButton(
                          onPressed: () {
                            final state = tester.state<FormixAsyncFieldState<String>>(
                              find.byType(FormixAsyncField<String>),
                            );
                            state.refresh();
                          },
                          child: const Text('Retry'),
                        );
                      },
                    ),
                  ],
                ),
                builder: (context, state) => Text(state.value ?? ''),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      initialCompleter.completeError('Initial Failure');
      await tester.pumpAndSettle();

      expect(find.text('Error: Initial Failure'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Attempt 1'), findsOneWidget);
      expect(attempts, 1);
    });
  });
}
