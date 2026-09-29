import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixRawTextField with TextFormField', () {
    testWidgets('Functional Test - shows error in TextFormField when autovalidateMode is always', (tester) async {
      const id = FormixFieldID<String>('headless_tff');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(
                  id: id,
                  initialValue: '',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required Field' : null,
                ),
              ],
              child: FormixRawTextField<String>(
                fieldId: id,
                autovalidateMode: FormixAutovalidateMode.always,
                valueToString: (v) => v ?? '',
                stringToValue: (s) => s,
                builder: (context, snapshot) {
                  return TextFormField(
                    controller: snapshot.textController,
                    focusNode: snapshot.focusNode,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: snapshot.shouldShowError ? snapshot.validation.errorMessage : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the error text is visible inside the TextFormField's decoration
      expect(find.text('Required Field'), findsOneWidget);
    });

    testWidgets('Golden Test - verifies UI layout of FormixRawTextField + TextFormField', (tester) async {
      const id = FormixFieldID<String>('golden_headless_tff');

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            primarySwatch: Colors.blue,
          ),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Formix(
                  fields: [
                    FormixFieldConfig(
                      id: id,
                      initialValue: '',
                      validator: (v) => (v?.isEmpty ?? true) ? 'Username cannot be empty' : null,
                    ),
                  ],
                  child: FormixRawTextField<String>(
                    fieldId: id,
                    autovalidateMode: FormixAutovalidateMode.always,
                    valueToString: (v) => v ?? '',
                    stringToValue: (s) => s,
                    builder: (context, snapshot) {
                      return TextFormField(
                        controller: snapshot.textController,
                        focusNode: snapshot.focusNode,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter your username',
                          prefixIcon: const Icon(Icons.person),
                          border: const OutlineInputBorder(),
                          errorText: snapshot.shouldShowError ? snapshot.validation.errorMessage : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Golden check
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('test/goldens/headless_text_form_field_always.png'),
      );
    });
  });
}
