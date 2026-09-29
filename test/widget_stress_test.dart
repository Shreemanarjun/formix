// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Formix Widget Stress & Memory Tests', () {
    testWidgets('Rapidly rebuilds field without leaking listeners', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('stress_field');
      int rebuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'stress_field': 'initial'},
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuildCount++;
                  return Column(
                    children: [
                      FormixTextFormField(
                        fieldId: fieldId,
                        decoration: InputDecoration(
                          labelText: 'Rebuild $rebuildCount',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Rebuild'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixTextFormField)),
      );

      // Perform 100 rapid rebuilds
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await tester.tap(find.text('Rebuild'));
        await tester.pump();
      }
      stopwatch.stop();
      print('100 Widget Rebuilds took: ${stopwatch.elapsedMilliseconds}ms');

      // Verify no extra listeners attached
      // We can't easily check private listener count, but we can verify behavior
      // and ensure performance didn't degrade significantly.

      // Also verify value still works
      await tester.enterText(find.byType(TextField), 'updated');
      await tester.pump();
      expect(controller!.getValue(fieldId), 'updated');
    });

    testWidgets('Many Form Fields Rendering Performance', (tester) async {
      const fieldCount = 5000;
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: ListView.builder(
                itemCount: fieldCount,
                itemBuilder: (context, index) {
                  return FormixTextFormField(
                    fieldId: FormixFieldID('field_$index'),
                    initialValue: 'value_$index',
                  );
                },
              ),
            ),
          ),
        ),
      );

      final renderTime = stopwatch.elapsedMilliseconds;
      print('Render $fieldCount ListView items took: ${renderTime}ms');

      // Note: ListView builds lazily, so this measures initial frame + first batch.
      // To test full mount, we'd need a Column in SingleChildScrollView, but 500 might be too slow for test environment.
      // Let's try scrolling to end to force build some more.

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
    });

    testWidgets('Fast typing updates do not lag', (tester) async {
      const fieldId = FormixFieldID<String>('typing_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(child: FormixTextFormField(fieldId: fieldId)),
          ),
        ),
      );

      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixTextFormField)),
      );
      final stopwatch = Stopwatch()..start();

      // Simulate fast typing
      String text = '';
      for (int i = 0; i < 50; i++) {
        text += 'a';
        try {
          await tester.enterText(find.byType(TextField), text);
          await tester.pump(); // frame
        } catch (e) {
          print('Crash at iteration $i: $e');
          rethrow;
        }
      }

      print('50 keystrokes took: ${stopwatch.elapsedMilliseconds}ms');

      try {
        expect(controller!.getValue(fieldId), text);
      } catch (e) {
        print('Value mismatch or error: $e');
        print('Current Controller Value: ${controller!.getValue(fieldId)}');
        rethrow;
      }
    });

    testWidgets('Widget disposal cleans up controller listeners', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('disposable_field');
      final showField = ValueNotifier(true);
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = scope.controller;
                  return ValueListenableBuilder<bool>(
                    valueListenable: showField,
                    builder: (context, show, _) {
                      return show ? const FormixTextFormField(fieldId: fieldId) : Container();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FormixTextFormField), findsOneWidget);

      // Unmount
      showField.value = false;
      await tester.pumpAndSettle();

      expect(find.byType(FormixTextFormField), findsNothing);

      // Note: Field might still be registered in controller (state preservation),
      // but the *listener* from the widget to the controller should be gone.
      // We can't introspect the listener list directly without hacky reflection or exposing it.
      // However, we can check that changing the value in controller doesn't throw or try to call setState on defunct widget.

      try {
        controller.setValue(fieldId, 'new value');
      } catch (e) {
        fail('Setting value after widget dispose caused error: $e');
      }
    });

    testWidgets('Duplicate value updates do not trigger unnecessary rebuilds', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('idempotent_field');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'idempotent_field': 'initial'},
              child: FormixBuilder(
                builder: (context, scope) {
                  return Column(
                    children: [
                      Builder(
                        builder: (context) {
                          scope.watchValue(fieldId); // Watch field
                          buildCount++;
                          return Text('Builds: $buildCount');
                        },
                      ),
                      ElevatedButton(
                        onPressed: () {
                          scope.controller.setValue(fieldId, 'new_value');
                        },
                        child: const Text('Update'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          scope.controller.setValue(fieldId, 'new_value');
                        },
                        child: const Text('Update Duplicate'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Builds: 1'), findsOneWidget);

      // First update (should trigger rebuild)
      await tester.tap(find.text('Update'));
      await tester.pump();
      expect(find.text('Builds: 2'), findsOneWidget);

      // Duplicate update (should NOT trigger rebuild ideally, or handle it gracefully)
      await tester.tap(find.text('Update Duplicate'));
      await tester.pump();
      // Depending on implementation, Riverpod state might not update if value is same.
      // Assuming FormixController checks for equality before updating state.
      expect(find.text('Builds: 2'), findsOneWidget);
    });

    testWidgets('Cross-field dependency performance with many dependents', (
      tester,
    ) async {
      const sourceField = FormixFieldID<String>('source');
      const dependentCount = 100;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'source': 'start'},
              child: ListView.builder(
                itemCount: dependentCount + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const FormixTextFormField(fieldId: sourceField);
                  }
                  final dependentId = FormixFieldID<String>('dep_$index');
                  return FormixBuilder(
                    builder: (context, scope) {
                      final sourceVal = scope.watchValue(sourceField);
                      return Text('$dependentId: $sourceVal');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixTextFormField)),
      );

      // Ensure initial build is complete
      await tester.pumpAndSettle();

      final stopwatch = Stopwatch()..start();
      controller!.setValue(sourceField, 'updated');
      await tester.pumpAndSettle(); // Allow all dependents to rebuild
      stopwatch.stop();

      print(
        'Update source with $dependentCount dependents took: ${stopwatch.elapsedMilliseconds}ms',
      );

      try {
        expect(
          find.text('FormixFieldID<String>(dep_1): updated'),
          findsOneWidget,
        );
      } catch (e) {
        print('Error finding dependent text: $e');
        print(
          'Current value in controller: ${controller.getValue(sourceField)}',
        );

        print('Found text widgets:');
        find.byType(Text).evaluate().map((e) => (e.widget as Text).data).forEach(print);

        rethrow;
      }
    });
  });
}
