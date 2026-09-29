import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  const fieldId = FormixFieldID<String>('test');

  group('Configuration Error Visibility Tests', () {
    testWidgets('Missing Formix ancestor shows config error for FormixTextFormField', (tester) async {
      // No Formix ancestor and no explicit controller -> config error surfaces.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormixTextFormField(fieldId: fieldId),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
      expect(find.textContaining('Missing Formix Ancestor'), findsOneWidget);
    });

    testWidgets('Missing Formix ancestor shows config error for FormixFieldSelector', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormixFieldSelector<String>(
              fieldId: fieldId,
              builder: _dummyBuilder,
            ),
          ),
        ),
      );

      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
      expect(find.textContaining('Missing Formix Ancestor'), findsOneWidget);
    });
  });
}

Widget _dummyBuilder(BuildContext context, FieldChangeInfo<String> info, Widget? child) {
  return const SizedBox();
}
