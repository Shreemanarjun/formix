import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixAdaptiveTextFormField', () {
    const fieldId = FormixFieldID<String>('name');

    testWidgets('renders TextFormField on Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: fieldId),
              ],
              child: FormixAdaptiveTextFormField(
                fieldId: fieldId,
                decoration: InputDecoration(labelText: 'Name'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(CupertinoFormRow), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders CupertinoFormRow on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: fieldId),
              ],
              child: FormixAdaptiveTextFormField(
                fieldId: fieldId,
                placeholder: 'Name',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CupertinoFormRow), findsOneWidget);
      expect(find.byType(CupertinoTextField), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('correctly maps decoration properties to cupertino on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: fieldId),
              ],
              child: FormixAdaptiveTextFormField(
                fieldId: fieldId,
                decoration: InputDecoration(
                  labelText: 'Label',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
      // labelText maps to placeholder in our implementation
      expect(textField.placeholder, equals('Label'));

      final cupertinoRow = tester.widget<CupertinoFormRow>(find.byType(CupertinoFormRow));
      // prefixIcon maps to prefix in CupertinoFormRow
      expect(cupertinoRow.prefix, isNotNull);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('value synchronization works on Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: fieldId, initialValue: 'Initial'),
              ],
              child: FormixAdaptiveTextFormField(fieldId: fieldId),
            ),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Updated Material');
      await tester.pump();
      expect(find.text('Updated Material'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('value synchronization works on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Formix(
                fields: [
                  FormixFieldConfig(id: fieldId, initialValue: 'Initial iOS'),
                ],
                child: FormixAdaptiveTextFormField(fieldId: fieldId),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Initial iOS'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), 'Updated Cupertino');
      await tester.pump();
      expect(find.text('Updated Cupertino'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
