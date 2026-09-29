import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixField used WITHOUT a Formix ancestor shows friendly error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormixTextFormField(
            fieldId: FormixFieldID('name'),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    expect(find.textContaining('Missing Formix Ancestor'), findsOneWidget);
  });

  testWidgets('FormixField used inside a Formix ancestor renders (no config error)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Formix(
            child: FormixTextFormField(
              fieldId: FormixFieldID('name'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
