import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixTextFormField Golden Test - Autovalidate always shows error', (tester) async {
    const id = FormixFieldID<String>('text_field');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Formix(
                fields: [
                  FormixFieldConfig(
                    id: id,
                    initialValue: '',
                    validator: (v) => (v?.isEmpty ?? true) ? 'This field is required' : null,
                  ),
                ],
                child: const FormixTextFormField(
                  fieldId: id,
                  autovalidateMode: FormixAutovalidateMode.always,
                  decoration: InputDecoration(
                    labelText: 'Standard Text Field',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the error text is present (TextFormField logic)
    expect(find.text('This field is required'), findsOneWidget);

    // Golden check
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('test/goldens/text_form_field_autovalidate_always.png'),
    );
  });
}
