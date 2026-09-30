import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixField used without a Formix ancestor shows a helpful error', (tester) async {
    // Formix is self-contained (no ProviderScope required). A field used outside
    // of a Formix ancestor — and without an explicit controller — should render a
    // helpful configuration error rather than crashing or looping.
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
    final errorWidget = find.byType(FormixConfigurationErrorWidget);

    expect(errorWidget, findsOneWidget);
    expect(find.textContaining('Missing Formix Ancestor'), findsOneWidget);
  });
}
