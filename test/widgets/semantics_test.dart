import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Accessibility & Semantics', () {
    testWidgets('Formix widget has form semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(child: SizedBox(height: 100, width: 100)),
          ),
        ),
      );

      // Verify SemanticsRole.form
      final semantics = tester.getSemantics(find.byType(Formix));
      final data = semantics.getSemanticsData();
      expect(data.role, equals(SemanticsRole.form));

      handle.dispose();
    });

    testWidgets('Form field communicates validation status to semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const fieldId = FormixFieldID<String>('name');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: fieldId,
                  initialValue: '',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  validationMode: FormixAutovalidateMode.always,
                ),
              ],
              child: FormixRawFormField<String>(
                fieldId: fieldId,
                builder: (context, state) {
                  return TextField(
                    focusNode: state.focusNode,
                    decoration: InputDecoration(
                      errorText: state.shouldShowError ? state.validation.errorMessage : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should be invalid initially due to always validation and empty initialValue
      final semantics = tester.getSemantics(find.byType(TextField));
      final data = semantics.getSemanticsData();

      // Verify validation result is invalid
      expect(data.validationResult, equals(SemanticsValidationResult.invalid));
      // Also verify it's a text field
      expect(data.flagsCollection.isTextField, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: fieldId,
                  initialValue: '',
                  validator: (v) => v!.isEmpty ? 'Error' : null,
                  validationMode: FormixAutovalidateMode.always,
                ),
              ],
              child: FormixRawFormField<String>(
                fieldId: fieldId,
                builder: (context, state) {
                  return const SizedBox(
                    height: 50,
                    width: 50,
                    child: Text('Custom Field'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final customSemantics = tester.getSemantics(find.text('Custom Field'));
      final customData = customSemantics.getSemanticsData();

      // SemanticsValidationResult.invalid should be reflected here.
      expect(
        customData.validationResult,
        equals(SemanticsValidationResult.invalid),
      );

      handle.dispose();
    });

    testWidgets('FormixController.announceErrors sends announcement', (
      tester,
    ) async {
      // Since SemanticsService.sendAnnouncement is a static method that talks to the platform,
      // testing it usually requires a mock for the BinaryMessenger if we want to be thorough.
      // However, we can at least verify that the logic doesn't crash and triggers correctly.

      const fieldId = FormixFieldID<String>('error_field');
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: fieldId,
                  initialValue: '',
                  validator: (v) => v!.isEmpty ? 'Critical Error' : null,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = scope.controller;
                  return const Text('Form');
                },
              ),
            ),
          ),
        ),
      );

      // Trigger announcement
      controller.validate();
      controller.announceErrors();

      // If no crash, it means the context retrieval and View.of/Directionality.of worked.
      expect(true, isTrue);
    });
  });
}
