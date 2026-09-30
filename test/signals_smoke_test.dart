import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// Smoke test for the signals-based core: proves the public API works WITHOUT
/// a ProviderScope and that SignalBuilder-backed widgets rebuild correctly.
void main() {
  const name = FormixFieldID<String>('name');
  const age = FormixFieldID<int>('age');

  testWidgets('field renders, updates, validates and rebuilds reactively', (tester) async {
    final formKey = GlobalKey<FormixState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            key: formKey,
            child: Column(
              children: [
                FormixTextFormField(
                  fieldId: name,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                FormixBuilder(
                  builder: (context, scope) => Text(
                    scope.watchIsValid ? 'VALID' : 'INVALID',
                  ),
                ),
                FormixBuilder(
                  builder: (context, scope) => Text('v=${scope.watchValue(name) ?? ''}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Let field registration + initial validation propagate through the signals.
    await tester.pump();

    // Initial: empty required field -> invalid (autovalidate always).
    expect(find.text('INVALID'), findsOneWidget);
    expect(find.text('v='), findsOneWidget);

    // Type into the field.
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();

    // Reactive slices updated surgically.
    expect(find.text('VALID'), findsOneWidget);
    expect(find.text('v=Ada'), findsOneWidget);

    // Controller accessible via GlobalKey (no ProviderScope / container needed).
    final controller = formKey.currentState!.controller;
    expect(controller.getValue(name), 'Ada');

    // Programmatic set flows back into the reactive UI.
    controller.setValue(name, 'Grace');
    await tester.pump();
    expect(find.text('v=Grace'), findsOneWidget);
  });

  testWidgets('multiple independent forms keep separate state', (tester) async {
    final keyA = GlobalKey<FormixState>();
    final keyB = GlobalKey<FormixState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Formix(
                key: keyA,
                child: const FormixTextFormField(fieldId: name),
              ),
              Formix(
                key: keyB,
                child: const FormixTextFormField(fieldId: name),
              ),
            ],
          ),
        ),
      ),
    );

    keyA.currentState!.controller.setValue(name, 'A');
    keyB.currentState!.controller.setValue(name, 'B');
    await tester.pump();

    expect(keyA.currentState!.controller.getValue(name), 'A');
    expect(keyB.currentState!.controller.getValue(name), 'B');
  });

  test('standalone controller works without any widget tree', () {
    final c = FormixController(
      fields: [
        FormixField<int>(
          id: age,
          initialValue: 0,
          validator: (v) => (v ?? 0) < 18 ? 'Too young' : null,
        ),
      ],
    );
    addTearDown(c.dispose);

    expect(c.getValue(age), 0);
    expect(c.state.isValid, isFalse);

    c.setValue(age, 21);
    expect(c.getValue(age), 21);
    expect(c.state.isValid, isTrue);
  });
}
