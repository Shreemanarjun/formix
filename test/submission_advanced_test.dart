import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('Submission throttles multiple calls', (tester) async {
    int callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            child: FormixBuilder(
              builder: (context, scope) {
                return ElevatedButton(
                  onPressed: () => scope.submit(
                    throttle: const Duration(milliseconds: 100),
                    onValid: (values) async {
                      callCount++;
                    },
                  ),
                  child: const Text('Submit'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Initial tap
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(callCount, 1);

    // Immediate follow-up taps (throttled)
    await tester.tap(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(callCount, 1);

    // Wait for throttle to expire
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });

    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(callCount, 2);
  });

  testWidgets('Optimistic submission works correctly', (tester) async {
    const nameField = FormixFieldID<String>('name');
    bool shouldFail = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'name': 'Initial'},
            child: FormixBuilder(
              builder: (context, scope) {
                final isDirty = scope.watchIsFormDirty;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Text('Dirty: $isDirty'),
                      const FormixSection(
                        fields: [FormixFieldConfig(id: nameField)],
                        child: FormixTextFormField(fieldId: nameField),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          scope
                              .submit(
                                optimistic: true,
                                onValid: (values) async {
                                  if (shouldFail) {
                                    await Future.delayed(
                                      const Duration(milliseconds: 50),
                                    );
                                    throw Exception('API Error');
                                  }
                                },
                              )
                              .catchError((_) {});
                        },
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initially clean
    expect(find.text('Dirty: false'), findsOneWidget);

    // 2. Modify field -> Dirty
    await tester.enterText(find.byType(TextField), 'Modified');
    await tester.pumpAndSettle();
    expect(find.text('Dirty: true'), findsOneWidget);

    // 3. Optimistic Submit -> Should become clean immediately
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Dirty: false'), findsOneWidget);

    // 4. Test failure revert
    shouldFail = true;
    await tester.enterText(find.byType(TextField), 'Modified Again');
    await tester.pumpAndSettle();
    expect(find.text('Dirty: true'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    // Still clean optimistically
    expect(find.text('Dirty: false'), findsOneWidget);

    // Wait for the simulated API delay and failure
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Reverted to dirty because of error
    expect(find.text('Dirty: true'), findsOneWidget);
  });
}
