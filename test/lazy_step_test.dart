import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Lazy Step Initialization Tests', () {
    const fieldA = FormixFieldID<String>('fieldA');

    testWidgets(
      'FormixFieldRegistry handles registration and state preservation',
      (tester) async {
        final showStep = ValueNotifier<bool>(true);
        late FormixController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                // Root validation mode disabled to allow manual checks
                child: FormixBuilder(
                  builder: (context, scope) {
                    controller = Formix.controllerOf(context)!;
                    return ValueListenableBuilder<bool>(
                      valueListenable: showStep,
                      builder: (context, show, _) {
                        return Column(
                          children: [
                            if (show)
                              const FormixFieldRegistry(
                                fields: [
                                  FormixFieldConfig<String>(
                                    id: fieldA,
                                    initialValue: 'A',
                                  ),
                                ],
                                child: FormixTextFormField(fieldId: fieldA),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // 1. Verify initial registration
        expect(find.byType(TextFormField), findsOneWidget);
        expect(controller.isFieldRegistered(fieldA), isTrue);
        expect(controller.getValue(fieldA), 'A');

        // 2. Modify value
        await tester.enterText(find.byType(TextFormField), 'User Value');
        await tester.pump();
        expect(controller.getValue(fieldA), 'User Value');

        // 3. Unmount step (Sleep)
        showStep.value = false;
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNothing);
        expect(
          controller.isFieldRegistered(fieldA),
          isFalse,
          reason: 'Field definition should be removed',
        );
        expect(
          controller.getValue(fieldA),
          'User Value',
          reason: 'Value should be preserved',
        );

        // 4. Mount step again (Wake)
        showStep.value = true;
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);
        expect(controller.isFieldRegistered(fieldA), isTrue);
        expect(
          controller.getValue(fieldA),
          'User Value',
          reason: 'Value should be restored from state',
        );
        expect(find.text('User Value'), findsOneWidget);
      },
    );
  });
}
