import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixConfigurationErrorWidget Golden Tests', () {
    testWidgets('Golden Test - Missing Formix Ancestor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: FormixTextFormField(
                fieldId: FormixFieldID('test'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(FormixConfigurationErrorWidget),
        matchesGoldenFile('goldens/error_missing_formix.png'),
      );
    });
  });
}
