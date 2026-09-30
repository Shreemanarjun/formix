import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/ui/multi_form_sync_page.dart';

void main() {
  testWidgets('editing Form A syncs into Form B (owned controllers + bindField)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MultiFormSyncPage()));
    await tester.pumpAndSettle();

    // Bindings are wired in initState → the page reports sync active immediately.
    expect(find.text('Sync Active'), findsOneWidget);

    // Two text fields: Form A's editable title, Form B's read-only synced title.
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Type into Form A (the source).
    await tester.enterText(textFields.first, 'Hello Sync');
    await tester.pumpAndSettle();

    // Both forms now show the value → the one-way binding propagated it.
    expect(find.widgetWithText(TextField, 'Hello Sync'), findsNWidgets(2));
  });
}
