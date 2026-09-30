// ignore_for_file: avoid_print

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Memory and Performance Tests', () {
    testWidgets('Large Form Performance & Memory Leak Check', (tester) async {
      final watcher = Stopwatch()..start();

      late FormixController controller;
      await tester.pumpWidget(
        Formix(
          child: FormixBuilder(
            builder: (context, _) {
              controller = Formix.controllerOf(context) as FormixController;
              return Container();
            },
          ),
        ),
      );

      print('Setup time: ${watcher.elapsedMilliseconds}ms');
      watcher.reset();

      // 1. Bulk Registration Performance
      const fieldCount = 1000;
      final fields = List.generate(
        fieldCount,
        (i) => FormixFieldConfig<int>(
          id: FormixFieldID('field_$i'),
          initialValue: i,
        ).toField(),
      );

      controller.registerFields(fields);
      final registrationTime = watcher.elapsedMilliseconds;
      print('Register $fieldCount fields: ${registrationTime}ms');

      // Expect reasonable performance (e.g., < 500ms for 1000 fields on typical dev machine)
      // Note: CI/CD machines vary, so we just log it or set a very loose bound.
      // Ideally < 16ms per frame is hard for 1000 items at once, but < 200ms is good for bulk.

      expect(controller.registeredFieldsCount, fieldCount);
      expect(controller.state.values.length, fieldCount);

      watcher.reset();

      // 2. Validation Performance
      controller.validate();
      final validationTime = watcher.elapsedMilliseconds;
      print('Validate $fieldCount fields: ${validationTime}ms');

      // 3. Unregistration Performance & Memory Cleanup (No Preserve)
      watcher.reset();
      controller.unregisterFields(
        fields.map((f) => f.id).toList(),
        preserveState: false,
      );
      final unregisterTime = watcher.elapsedMilliseconds;
      print('Unregister $fieldCount fields (Clean): ${unregisterTime}ms');

      // Verify Cleanup
      expect(
        controller.registeredFieldsCount,
        0,
        reason: 'All fields should be unregistered',
      );
      expect(
        controller.state.values.isEmpty,
        isTrue,
        reason: 'Values should be cleared',
      );
      expect(controller.state.dirtyStates.isEmpty, isTrue);
      expect(controller.state.touchedStates.isEmpty, isTrue);

      // 4. Memory Leak Check with FormixFieldRegistry (Mount/Unmount cycle)
      watcher.reset();

      // We will perform 50 cycles of mount/unmount of 100 fields
      const cycleCount = 50;
      const cycleFieldCount = 100;
      final cycleFields = List.generate(
        cycleFieldCount,
        (i) => FormixFieldConfig<String>(id: FormixFieldID('cycle_$i')),
      );

      final showRegistry = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        Formix(
          child: FormixBuilder(
            builder: (context, _) {
              controller = Formix.controllerOf(context) as FormixController;
              return ValueListenableBuilder<bool>(
                valueListenable: showRegistry,
                builder: (context, show, child) {
                  if (!show) return const SizedBox();
                  return FormixFieldRegistry(
                    fields: cycleFields,
                    preserveStateOnDispose: false, // Ensure full cleanup
                    child: const SizedBox(),
                  );
                },
              );
            },
          ),
        ),
      );

      for (int i = 0; i < cycleCount; i++) {
        showRegistry.value = false;
        await tester.pump(); // Unmount (triggers unregister via microtask)
        await tester.pump(
          const Duration(milliseconds: 1),
        ); // Allow microtask to run

        expect(
          controller.registeredFieldsCount,
          0,
          reason: 'Cycle $i: Leaked fields after unmount',
        );

        showRegistry.value = true;
        await tester.pump(); // Mount (triggers register)

        expect(
          controller.registeredFieldsCount,
          cycleFieldCount,
          reason: 'Cycle $i: Failed to register',
        );
      }

      final cycleTime = watcher.elapsedMilliseconds;
      print(
        '$cycleCount Mount/Unmount cycles ($cycleFieldCount fields): ${cycleTime}ms',
      );
    });

    testWidgets('Undo/Redo History Memory & Performance', (tester) async {
      late FormixController controller;
      await tester.pumpWidget(
        Formix(
          child: FormixBuilder(
            builder: (context, _) {
              controller = Formix.controllerOf(context) as FormixController;
              return Container();
            },
          ),
        ),
      );

      final watcher = Stopwatch()..start();

      // 1. Stress Test History
      const updatesCount = 100;
      const field = FormixFieldID<int>('counter');
      controller.registerField(
        const FormixFieldConfig<int>(id: field, initialValue: 0).toField(),
      );

      for (int i = 0; i < updatesCount; i++) {
        controller.setValue(field, i);
      }

      final time = watcher.elapsedMilliseconds;
      print('Undo/Redo: $updatesCount updates in ${time}ms');

      // 2. Memory Cap Check
      expect(
        controller.historyCount,
        lessThanOrEqualTo(50),
        reason: 'History should be capped at 50',
      );
      expect(
        controller.historyCount,
        50,
        reason: 'Should have reached max capacity',
      );

      watcher.reset();

      // 3. Undo Performance
      for (int i = 0; i < 20; i++) {
        controller.undo();
      }
      print('Undo 20 steps: ${watcher.elapsedMilliseconds}ms');
    });

    testWidgets('Multi-Form Sync Performance & Cleanup', (tester) async {
      late FormixController formA;
      late FormixController formB;

      await tester.pumpWidget(
        Column(
          children: [
            Formix(
              formId: 'formA',
              child: FormixBuilder(
                builder: (c, _) {
                  formA = Formix.controllerOf(c) as FormixController;
                  return Container();
                },
              ),
            ),
            Formix(
              formId: 'formB',
              child: FormixBuilder(
                builder: (c, _) {
                  formB = Formix.controllerOf(c) as FormixController;
                  return Container();
                },
              ),
            ),
          ],
        ),
      );

      // 1. Setup Sync (Bind B to A)
      const fieldsToSync = 50;
      final watcher = Stopwatch()..start();

      for (int i = 0; i < fieldsToSync; i++) {
        final fieldId = FormixFieldID<String>('field_$i');
        formA.registerField(
          FormixFieldConfig<String>(id: fieldId, initialValue: 'A').toField(),
        );
        formB.registerField(
          FormixFieldConfig<String>(id: fieldId, initialValue: 'B').toField(),
        );

        // Bind B's field to listen to A's field
        formB.bindField(fieldId, sourceController: formA, sourceField: fieldId);
      }

      print('Setup $fieldsToSync bindings: ${watcher.elapsedMilliseconds}ms');

      // Check active bindings count on B (target)
      expect(formB.activeBindingsCount, fieldsToSync);

      watcher.reset();

      // 2. Sync Performance
      // Update A, check B
      for (int i = 0; i < fieldsToSync; i++) {
        formA.setValue(FormixFieldID<String>('field_$i'), 'Synced_$i');
      }

      // Allow streams to propagate
      await tester.pump();

      for (int i = 0; i < fieldsToSync; i++) {
        expect(formB.getValue(FormixFieldID<String>('field_$i')), 'Synced_$i');
      }

      print(
        'Sync $fieldsToSync fields update: ${watcher.elapsedMilliseconds}ms',
      );

      // 3. Cleanup / Dispose
      // Remove FormB from tree to trigger auto-dispose
      await tester.pumpWidget(
        Column(
          children: [
            Formix(
              formId: 'formA',
              child: FormixBuilder(
                builder: (c, _) {
                  formA = Formix.controllerOf(c) as FormixController;
                  return Container();
                },
              ),
            ),
          ],
        ),
      );

      // Allow disposal hooks to run
      await tester.pumpAndSettle();

      expect(
        formB.activeBindingsCount,
        0,
        reason: 'Bindings should be cleared on dispose',
      );
    });
  });
}
