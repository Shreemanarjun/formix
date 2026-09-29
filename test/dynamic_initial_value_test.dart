import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  const fieldId = FormixFieldID<String>('dynamic_field');

  group('Dynamic Initial Value Updates', () {
    testWidgets('should update field value when initialValue changes from null to value (pristine)', (tester) async {
      String? currentInitialValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixRawFormField<String>(
                        fieldId: fieldId,
                        initialValue: currentInitialValue,
                        builder: (context, state) => Text('Value: ${state.value ?? 'null'}'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentInitialValue = 'Updated Value';
                          });
                        },
                        child: const Text('Load Data'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially null
      expect(find.text('Value: null'), findsOneWidget);

      // Trigger update
      await tester.tap(find.text('Load Data'));
      await tester.pump();

      // Should update to new value
      expect(find.text('Value: Updated Value'), findsOneWidget);
    });

    testWidgets('should NOT update field value if user has modified it (dirty)', (tester) async {
      String? currentInitialValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixRawFormField<String>(
                        fieldId: fieldId,
                        initialValue: currentInitialValue,
                        builder: (context, state) => Column(
                          children: [
                            Text('Value: ${state.value ?? 'null'}'),
                            ElevatedButton(
                              onPressed: () => state.didChange('User Modified'),
                              child: const Text('Modify Value'),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentInitialValue = 'Server Value';
                          });
                        },
                        child: const Text('Load Data'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially null
      expect(find.text('Value: null'), findsOneWidget);

      // User modifies value
      await tester.tap(find.text('Modify Value'));
      await tester.pump();
      expect(find.text('Value: User Modified'), findsOneWidget);

      // Trigger "Server Load" update
      await tester.tap(find.text('Load Data'));
      await tester.pump();

      // Should STILL be user modified value, NOT server value
      expect(find.text('Value: User Modified'), findsOneWidget);
    });

    testWidgets('should NOT update field value when initialValue changes and strategy is preferGlobal (even if pristine)', (tester) async {
      String? currentInitialValue = 'Initial';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixRawFormField<String>(
                        fieldId: fieldId,
                        initialValue: currentInitialValue,
                        initialValueStrategy: FormixInitialValueStrategy.preferGlobal,
                        builder: (context, state) => Text('Value: ${state.value ?? 'null'}'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentInitialValue = 'Try Update';
                          });
                        },
                        child: const Text('Try Load'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially 'Initial'
      expect(find.text('Value: Initial'), findsOneWidget);

      // Trigger update attempt
      await tester.tap(find.text('Try Load'));
      await tester.pump();

      // Should STILL be 'Initial' because strategy is preferGlobal
      expect(find.text('Value: Initial'), findsOneWidget);
      expect(find.text('Value: Try Update'), findsNothing);
    });

    testWidgets('should update value if strategy is changed from preferGlobal to preferLocal dynamically', (tester) async {
      String? currentInitialValue = 'Initial';
      FormixInitialValueStrategy currentStrategy = FormixInitialValueStrategy.preferGlobal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixRawFormField<String>(
                        fieldId: fieldId,
                        initialValue: currentInitialValue,
                        initialValueStrategy: currentStrategy,
                        builder: (context, state) => Text('Value: ${state.value ?? 'null'}'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentInitialValue = 'Strategy Changed';
                            currentStrategy = FormixInitialValueStrategy.preferLocal;
                          });
                        },
                        child: const Text('Update Both'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially 'Initial'
      expect(find.text('Value: Initial'), findsOneWidget);

      // Trigger update with strategy change
      await tester.tap(find.text('Update Both'));
      await tester.pump();
      await tester.pump(); // Need another pump for microtask-triggered setState

      // Should now observe the new value because strategy is now preferLocal
      expect(find.text('Value: Strategy Changed'), findsOneWidget);
    });

    testWidgets('Golden Test: Verify dynamic update visual transition', (tester) async {
      String? currentInitialValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FormixRawFormField<String>(
                            fieldId: fieldId,
                            initialValue: currentInitialValue,
                            builder: (context, state) => Text(
                              'Current Value: ${state.value ?? 'Loading...'}',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                currentInitialValue = 'Loaded Successfully!';
                              });
                            },
                            child: const Text('Simulate Load'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial State (Loading)
      await expectLater(
        find.byType(Formix),
        matchesGoldenFile('goldens/dynamic_initial_value_loading.png'),
      );

      // Tap to load
      await tester.tap(find.text('Simulate Load'));
      await tester.pump();

      // Loaded State
      await expectLater(
        find.byType(Formix),
        matchesGoldenFile('goldens/dynamic_initial_value_loaded.png'),
      );
    });
  });
}
