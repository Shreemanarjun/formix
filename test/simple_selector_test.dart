import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixFieldConditionalSelector simple test', (tester) async {
    const fieldId = FormixFieldID<String>('name');
    int buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'name': 'A'},
            fields: const [FormixFieldConfig(id: fieldId)],
            child: FormixFieldConditionalSelector<String>(
              fieldId: fieldId,
              shouldRebuild: (info) => true,
              builder: (context, info, child) {
                buildCount++;
                return Text('Value: ${info.value}');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Value: A'), findsOneWidget);
    expect(buildCount, 1);
  });
}
