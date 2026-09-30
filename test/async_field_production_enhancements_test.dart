import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixAsyncField Production Enhancements', () {
    testWidgets('Handles race conditions by only applying the latest future', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('race_condition');

      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      final futureNotifier = ValueNotifier<Future<String>>(completer1.future);

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            child: ValueListenableBuilder<Future<String>>(
              valueListenable: futureNotifier,
              builder: (context, f, _) => FormixAsyncField<String>(
                fieldId: fieldId,
                future: f,
                loadingBuilder: (context) => const Text('Loading'),
                builder: (context, state) => Text(state.value ?? 'No Value'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);

      futureNotifier.value = completer2.future;
      await tester.pump();

      // Resolve future2
      completer2.complete('Data 2');
      // Resolve future1
      completer1.complete('Data 1');

      // Using runAsync to ensure both futures are processed
      await tester.runAsync(() async {
        await Future.delayed(Duration.zero);
      });

      await tester.pumpAndSettle();
      expect(find.text('Data 2'), findsOneWidget);
      expect(find.text('Data 1'), findsNothing);
    });

    testWidgets('supports retry via refresh()', (tester) async {
      const fieldId = FormixFieldID<String>('retry_test');
      int callCount = 0;

      // Define fetch function
      Future<String> fetchData() async {
        callCount++;
        // Use Future.error to be explicit, and delayed to ensure listener is attached
        if (callCount == 1) {
          return Future.delayed(Duration.zero, () => throw 'Initial Error');
        }
        return Future.delayed(Duration.zero, () => 'Success Data');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            child: FormixAsyncField<String>(
              fieldId: fieldId,
              future: fetchData(),
              onRetry: fetchData, // Pass callback correctly
              asyncErrorBuilder: (context, error) => Column(
                children: [
                  Text('Error: $error'),
                  Builder(
                    builder: (context) {
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
              builder: (context, state) => Text(state.value ?? 'No Data'),
            ),
          ),
        ),
      );

      // Pump to trigger initState
      await tester.pump();

      // Allow future to complete (it has a delay now)
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      // Check if exception was reported effectively in UI
      expect(find.text('Error: Initial Error'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump(); // Trigger tap

      // Allow retry future to complete
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('Success Data'), findsOneWidget);
    });

    testWidgets('keepPreviousData prevents flicker during loading', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('flicker_test');

      final completer1 = Completer<String>();
      final completer2 = Completer<String>();

      final futureNotifier = ValueNotifier<Future<String>>(completer1.future);

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            child: ValueListenableBuilder<Future<String>>(
              valueListenable: futureNotifier,
              builder: (context, f, _) => FormixAsyncField<String>(
                fieldId: fieldId,
                future: f,
                keepPreviousData: true,
                loadingBuilder: (context) => const Text('Loading'),
                builder: (context, state) => Text(state.value ?? 'No Value'),
              ),
            ),
          ),
        ),
      );

      completer1.complete('Old Data');
      await tester.pumpAndSettle(); // Should resolve
      expect(find.text('Old Data'), findsOneWidget);

      futureNotifier.value = completer2.future;
      await tester.pump();

      expect(find.text('Old Data'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);

      completer2.complete('New Data');
      await tester.pumpAndSettle();
      expect(find.text('New Data'), findsOneWidget);
    });

    testWidgets('debounce prevents execution of intermediate futures', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('debounce_real_test');

      final completer1 = Completer<String>();
      final futureNotifier = ValueNotifier<Future<String>>(completer1.future);

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            child: ValueListenableBuilder<Future<String>>(
              valueListenable: futureNotifier,
              builder: (context, f, _) => FormixAsyncField<String>(
                fieldId: fieldId,
                future: f,
                debounce: const Duration(milliseconds: 200),
                keepPreviousData: false,
                loadingBuilder: (context) => const Text('Loading...'),
                builder: (context, state) => Text(state.value ?? 'No Value'),
              ),
            ),
          ),
        ),
      );

      // Initial load IS ALSO debounced. Pump 200ms.
      // Wait, pump(200) executes the timer callback, which executes future.
      // But future is COMPLETER. It doesn't complete until we tell it.
      // But we must ensure the `_executeFuture` call happens.
      await tester.pump(const Duration(milliseconds: 200));

      // Now future executes and is pending.
      // Since keepPreviousData is false, state should be Loading...
      expect(find.text('Loading...'), findsOneWidget);

      completer1.complete('Old Data');
      await tester.pumpAndSettle();
      expect(find.text('Old Data'), findsOneWidget);

      final completer2 = Completer<String>();
      futureNotifier.value = completer2.future;
      await tester.pump(); // Triggers update, starts debounce

      // Should NOT be loading yet (debouncing)
      expect(find.text('Old Data'), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);

      // Wait 100ms (less than debounce)
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Old Data'), findsOneWidget);

      // Wait remaining 100ms + margin
      await tester.pump(const Duration(milliseconds: 150));
      // Now it should have triggered loading (since keepPreviousData is false)
      expect(find.text('Loading...'), findsOneWidget);

      completer2.complete('New Data');
      await tester.pumpAndSettle();
      expect(find.text('New Data'), findsOneWidget);
    });
  });
}
