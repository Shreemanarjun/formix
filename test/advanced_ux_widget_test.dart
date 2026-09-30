import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Advanced UX Widget Integration Tests', () {
    const fieldA = FormixFieldID<String>('fieldA');
    const fieldB = FormixFieldID<String>('fieldB');

    testWidgets('Validates visual feedback for Optimistic Update (Pending State)', (
      tester,
    ) async {
      final completer = Completer<void>();
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'fieldA': 'initial'},
              fields: const [
                FormixFieldConfig<String>(
                  id: fieldA,
                  initialValue: 'initial',
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  final isPending = scope.watchIsPending(fieldA);

                  return Column(
                    children: [
                      const FormixTextFormField(fieldId: fieldA),
                      if (isPending)
                        const CircularProgressIndicator(
                          key: Key('pending_indicator'),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          controller.optimisticUpdate(
                            fieldId: fieldA,
                            value: 'optimistic',
                            action: () => completer.future,
                          );
                        },
                        child: const Text('Sync'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('initial'), findsOneWidget);
      expect(find.byKey(const Key('pending_indicator')), findsNothing);

      // Trigger optimistic update via button
      await tester.tap(find.text('Sync'));
      await tester.pump();
      // Need purely sync pump or pump(Duration) maybe, but optimisticUpdate is async.
      // However the SETTING of value and pending is synchronous before await action.
      // So pumping a microtask should show it.

      // 1. Check visual update
      expect(find.text('optimistic'), findsOneWidget);

      // 2. Check pending indicator
      expect(find.byKey(const Key('pending_indicator')), findsOneWidget);

      // Complete action
      completer.complete();
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Allow future to complete

      // 3. Pending indicator gone
      expect(find.byKey(const Key('pending_indicator')), findsNothing);
      expect(find.text('optimistic'), findsOneWidget);
    });

    testWidgets('Validates Multi-Form Synchronization via UI interactions', (
      tester,
    ) async {
      final keyA = GlobalKey<FormixState>();
      final keyB = GlobalKey<FormixState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Formix(
                  key: keyA,
                  initialValue: const {'fieldA': 'A'},
                  fields: const [
                    FormixFieldConfig<String>(id: fieldA, initialValue: 'A'),
                  ],
                  child: const FormixTextFormField(
                    fieldId: fieldA,
                    decoration: InputDecoration(labelText: 'Form A'),
                  ),
                ),
                Formix(
                  key: keyB,
                  initialValue: const {'fieldB': 'B'},
                  fields: const [
                    FormixFieldConfig<String>(id: fieldB, initialValue: 'B'),
                  ],
                  child: const FormixTextFormField(
                    fieldId: fieldB,
                    decoration: InputDecoration(labelText: 'Form B'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Bind B -> A (One way)
      final controllerA = keyA.currentState!.controller;
      final controllerB = keyB.currentState!.controller;

      controllerB.bindField(
        fieldB,
        sourceController: controllerA,
        sourceField: fieldA,
      );

      // Verify initial
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      // Edit A
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Form A'),
        'New Value',
      );
      await tester.pump();

      // Verify B updated
      expect(find.widgetWithText(TextFormField, 'Form B'), findsOneWidget);
      // We need to check the text value inside the widget
      expect(controllerB.getValue(fieldB), 'New Value');

      // Ideally verify purely via UI
      expect(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Form B'),
          matching: find.text('New Value'),
        ),
        findsOneWidget,
      );
    });
  });
}
