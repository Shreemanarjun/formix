import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// verify path

void main() {
  group('Optimistic Field Updates Tests', () {
    const fieldId = FormixFieldID<String>('field');

    testWidgets('Validates Optimistic Update Flow', (tester) async {
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
      expect(controller.state.isFieldPending(fieldId), isFalse);

      // Trigger optimistic update
      final completer = Completer<void>();

      // Perform update but don't await immediately to check pending state
      final future = controller.optimisticUpdate(
        fieldId: fieldId,
        value: 'optimistic',
        action: () => completer.future,
      );

      await tester.pump();

      // 1. Should be updated immediately
      expect(controller.getValue(fieldId), 'optimistic');

      // 2. Should be pending
      expect(controller.state.isFieldPending(fieldId), isTrue);

      // Complete the action successfully
      completer.complete();
      await future;
      await tester.pump();

      // 3. Should still be updated and no longer pending
      expect(controller.getValue(fieldId), 'optimistic');
      expect(controller.state.isFieldPending(fieldId), isFalse);
    });

    testWidgets('Validates Revert on Error', (tester) async {
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

      // Trigger optimistic update that fails
      try {
        await controller.optimisticUpdate(
          fieldId: fieldId,
          value: 'optimistic',
          action: () async {
            throw Exception('Sync failed');
          },
          revertOnError: true,
        );
      } catch (e) {
        expect(e, isA<Exception>());
      }

      await tester.pump();

      // 4. Should revert to 'initial'
      expect(controller.getValue(fieldId), 'initial');
      expect(controller.state.isFieldPending(fieldId), isFalse);
    });
  });
}
