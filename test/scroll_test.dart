import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Scroll to Error Tests', () {
    const field1 = FormixFieldID<String>('field1');
    const field2 = FormixFieldID<String>('field2');

    testWidgets('focusFirstError() should scroll to the field with error', (tester) async {
      late FormixController controller;
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: field1,
                  initialValue: '',
                  validator: (v) => v!.isEmpty ? 'Error' : null,
                ),
                FormixFieldConfig<String>(
                  id: field2,
                  initialValue: '',
                  validator: (v) => v!.isEmpty ? 'Error' : null,
                ),
              ],
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    const FormixTextFormField(fieldId: field1),
                    const SizedBox(height: 1000), // Make it long
                    const FormixTextFormField(fieldId: field2),
                    FormixBuilder(
                      builder: (context, scope) {
                        controller = Formix.controllerOf(context)!;
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Initially at 0
      expect(scrollController.offset, 0.0);

      // Validate manually and focus first error (field1)
      // Since field1 is already at the top, it might not scroll much.
      controller.validate();
      controller.focusFirstError();
      await tester.pumpAndSettle();

      // Now set field1 as valid, and field2 as invalid.
      controller.setValue(field1, 'Valid');
      controller.validate();

      // Initially scrollController is still at 0 (or near it)
      expect(scrollController.offset, closeTo(0.0, 1.0));

      // Focus first error (which is now field2)
      controller.focusFirstError(scrollDuration: Duration.zero);
      await tester.pumpAndSettle();

      // It should have scrolled down to field2
      expect(scrollController.offset, greaterThan(500.0));
    });

    testWidgets('scrollToField can use a custom ScrollController', (tester) async {
      late FormixController controller;
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig<String>(id: field1, initialValue: ''),
                FormixFieldConfig<String>(id: field2, initialValue: ''),
              ],
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    const FormixTextFormField(fieldId: field1),
                    const SizedBox(height: 1200),
                    const FormixTextFormField(fieldId: field2),
                    const SizedBox(height: 1000), // Add padding here
                    FormixBuilder(
                      builder: (context, scope) {
                        controller = Formix.controllerOf(context)!;
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(scrollController.offset, 0.0);

      // Scroll to field2 using the explicit scrollController at the top
      controller.scrollToField(
        field2,
        duration: Duration.zero,
        scrollController: scrollController,
        alignment: 0.0,
      );
      await tester.pumpAndSettle();

      expect(scrollController.offset, greaterThan(1100.0));
    });

    testWidgets('focusFirstError supports custom alignment', (tester) async {
      late FormixController controller;
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: Formix(
                fields: [
                  FormixFieldConfig<String>(
                    id: field1,
                    initialValue: '',
                    validator: (v) => 'Error',
                  ),
                ],
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 1000),
                      const FormixTextFormField(fieldId: field1),
                      const SizedBox(height: 1000),
                      FormixBuilder(
                        builder: (context, scope) {
                          controller = Formix.controllerOf(context)!;
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Focus with alignment 0.0 (top)
      controller.focusFirstError(
        scrollDuration: Duration.zero,
        alignment: 0.0,
      );
      await tester.pumpAndSettle();
      final topOffset = scrollController.offset;

      // Focus with alignment 1.0 (bottom)
      controller.focusFirstError(
        scrollDuration: Duration.zero,
        alignment: 1.0,
      );
      await tester.pumpAndSettle();
      final bottomOffset = scrollController.offset;

      expect(bottomOffset, lessThan(topOffset), reason: 'Bottom alignment should scroll less than top alignment to show it at the bottom of viewport');
      // Wait, if alignment is 1.0, the widget is at the bottom of viewport.
      // If alignment is 0.0, the widget is at the top of viewport.
      // So to show it at the top, we must scroll MORE.
      // Example: widget is at 1000. Viewport is 600.
      // Top (0.0): scroll offset = 1000.
      // Bottom (1.0): scroll offset = 1000 - 600 = 400.
    });
  });
}
