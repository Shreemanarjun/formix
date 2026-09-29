import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixAsyncField works with async validation', (tester) async {
    const fieldId = FormixFieldID<String>('username');

    // Simulates an API call to load the initial suggested username
    final initialFuture = Future.delayed(
      const Duration(milliseconds: 10),
      () => 'john_doe',
    );

    // Simulates an API call to check if a username is available
    Future<String?> checkAvailability(String? value) async {
      await Future.delayed(const Duration(milliseconds: 10));
      if (value == 'john_doe') {
        return 'Username already taken';
      }
      return null;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            child: FormixAsyncField<String>(
              fieldId: fieldId,
              future: initialFuture,
              asyncValidator: checkAvailability,
              builder: (context, state) {
                return Column(
                  children: [
                    Text('Current Value: ${state.value}'),
                    if (state.validation.isValidating) const Text('Validating...'),
                    if (state.validation.errorMessage != null) Text('Error: ${state.validation.errorMessage}'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    // 1. Initially it should be loading the value
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 2. Wait for the initial value to load
    await tester.pumpAndSettle();
    expect(find.text('Current Value: john_doe'), findsOneWidget);

    // 3. Since the value was set, async validation should be triggered
    // Note: setValue marks it as validating and then starts a timer.
    // In FormixController, async validation has a default debounce of 300ms.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Validating...'), findsOneWidget);

    // 4. Wait for debounce and the validation future to complete
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // 5. It should show the error from the async validator
    expect(find.text('Error: Username already taken'), findsOneWidget);

    // 6. Test updating to a valid value
    final controller = Formix.controllerOf(
      tester.element(find.byType(FormixAsyncField<String>)),
    );
    controller!.setValue(fieldId, 'new_user');

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Current Value: new_user'), findsOneWidget);
    expect(find.text('Validating...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Error: Username already taken'), findsNothing);
    expect(find.text('Validating...'), findsNothing);
  });
}
