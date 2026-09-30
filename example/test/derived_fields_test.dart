import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/ui/derived_fields/derived_fields_page.dart';

void main() {
  group('DerivedFieldsExample (FormixFieldDerivation)', () {
    testWidgets('fullName derives from first + last name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DerivedFieldsExample())),
      );
      await tester.pumpAndSettle();

      // Empty names → placeholder from the display builder.
      expect(find.text('Enter names above'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'First Name'), 'Ada');
      await tester.enterText(find.widgetWithText(TextFormField, 'Last Name'), 'Lovelace');
      await tester.pumpAndSettle();

      // Derivation ran (via gated effect, not a build-time write).
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Enter names above'), findsNothing);
    });

    testWidgets('subtotal derives from price * quantity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DerivedFieldsExample())),
      );
      await tester.pumpAndSettle();

      // price 100.0 * quantity 1 = 100.00 on mount.
      expect(find.text('\$100.00'), findsWidgets);

      await tester.enterText(find.widgetWithText(TextFormField, 'Quantity'), '3');
      await tester.pumpAndSettle();

      // 100.0 * 3 = 300.00 (subtotal, and finalTotal with 0% discount).
      expect(find.text('\$300.00'), findsWidgets);
    });
  });
}
