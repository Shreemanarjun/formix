import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// Golden tests for the 0.2.0 ergonomic widgets: [FormixValue] and
/// [FormixSubmitButton] (enabled + disabled states).
void main() {
  const email = FormixFieldID<String>('email');
  const name = FormixFieldID<String>('name');

  Widget host(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      );

  testWidgets('FormixValue renders the field value', (tester) async {
    await tester.pumpWidget(
      host(
        Formix(
          initialValue: const {'email': 'ada@example.com'},
          child: FormixValue<String>(
            email,
            builder: (context, value) => Text(
              'Email: ${value ?? ''}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(FormixValue<String>),
      matchesGoldenFile('test/goldens/formix_value.png'),
    );
  });

  testWidgets('FormixSubmitButton enabled (valid form)', (tester) async {
    final c = FormixController(initialValue: const {'name': 'Ada'});
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Formix(
          controller: c,
          child: FormixSubmitButton(
            onValid: (_) async {},
            child: const Text('Save'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(FormixSubmitButton),
      matchesGoldenFile('test/goldens/formix_submit_button_enabled.png'),
    );
  });

  testWidgets('FormixSubmitButton disabled (invalid form)', (tester) async {
    final c = FormixController(
      fields: [
        FormixFieldConfig<String>(
          id: name,
          validationMode: FormixAutovalidateMode.always,
          validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      host(
        Formix(
          controller: c,
          child: FormixSubmitButton(
            onValid: (_) async {},
            child: const Text('Save'),
          ),
        ),
      ),
    );
    c.validate(); // surface the required error → button disables
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(FormixSubmitButton),
      matchesGoldenFile('test/goldens/formix_submit_button_disabled.png'),
    );
  });
}
