import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Undo/Redo History Tests', () {
    const fieldId = FormixFieldID<String>('field');

    testWidgets('Validates Undo/Redo functionality', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'field': 'initial'},
              fields: const [
                FormixFieldConfig<String>(
                  id: fieldId,
                  initialValue: 'initial',
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const Column(
                    children: [FormixTextFormField(fieldId: fieldId)],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify initial state
      expect(controller.getValue(fieldId), 'initial');
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      // Change value
      await tester.enterText(find.byType(TextField), 'change1');
      await tester.pump();
      expect(controller.getValue(fieldId), 'change1');
      expect(
        controller.canUndo,
        isTrue,
      ); // History: [initial, change1] (index 1)
      expect(controller.canRedo, isFalse);

      // Change value again
      await tester.enterText(find.byType(TextField), 'change2');
      await tester.pump();
      expect(controller.getValue(fieldId), 'change2');
      expect(
        controller.canUndo,
        isTrue,
      ); // History: [initial, change1, change2] (index 2)

      // Undo -> change1
      controller.undo();
      await tester.pump();
      expect(controller.getValue(fieldId), 'change1');
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isTrue);

      // Undo -> initial
      controller.undo();
      await tester.pump();
      expect(controller.getValue(fieldId), 'initial');
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      // Redo -> change1
      controller.redo();
      await tester.pump();
      expect(controller.getValue(fieldId), 'change1');
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isTrue);

      // New change while in middle of history -> truncates future
      await tester.enterText(find.byType(TextField), 'change3');
      await tester.pump();
      expect(controller.getValue(fieldId), 'change3');
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse); // Future history lost

      // Undo -> change1
      controller.undo();
      await tester.pump();
      expect(controller.getValue(fieldId), 'change1');

      // Redo -> change3 (not change2!)
      controller.redo();
      await tester.pump();
      expect(controller.getValue(fieldId), 'change3');
    });
  });
}
