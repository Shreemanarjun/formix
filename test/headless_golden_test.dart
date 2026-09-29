import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixRawTextField Golden Test - Autovalidate always shows error', (tester) async {
    const id = FormixFieldID<String>('test_field');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
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
                child: FormixRawTextField<String>(
                  fieldId: id,
                  autovalidateMode: FormixAutovalidateMode.always,
                  valueToString: (v) => v ?? '',
                  stringToValue: (s) => s,
                  builder: (context, snapshot) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: snapshot.textController,
                          focusNode: snapshot.focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (snapshot.shouldShowError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              snapshot.validation.errorMessage ?? '',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                      ],
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

    // Verify the error text is present
    expect(find.text('This field is required'), findsOneWidget);

    // Golden check
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('test/goldens/headless_autovalidate_always.png'),
    );
  });
}
