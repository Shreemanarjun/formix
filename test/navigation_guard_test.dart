import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixNavigationGuard prevents navigation when dirty', (
    tester,
  ) async {
    bool confirmedDiscard = false;

    const nameField = FormixFieldID<String>('name');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Formix(
                      child: FormixNavigationGuard(
                        showDirtyDialog: (context) async {
                          confirmedDiscard = true;
                          return true; // Confirm discard
                        },
                        child: Scaffold(
                          appBar: AppBar(title: const Text('Form Page')),
                          body: FormixBuilder(
                            builder: (context, scope) {
                              final isDirty = scope.watchIsFormDirty;
                              return Column(
                                children: [
                                  Text('Dirty: $isDirty'),
                                  const FormixSection(
                                    fields: [
                                      FormixFieldConfig(id: nameField),
                                    ],
                                    child: FormixTextFormField(
                                      fieldId: nameField,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).maybePop();
                                    },
                                    child: const Text('Back'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Go to Form'),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Navigate to Form
    await tester.tap(find.text('Go to Form'));
    await tester.pumpAndSettle();
    expect(find.text('Form Page'), findsOneWidget);

    // 2. Modify field to make it dirty
    await tester.enterText(find.byType(TextField), 'John');
    await tester.pumpAndSettle();
    expect(find.text('Dirty: true'), findsOneWidget);

    // 3. Try to pop
    await tester.tap(find.text('Back'));

    await tester.runAsync(() async {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(confirmedDiscard, isTrue);

    await tester.pumpAndSettle();

    expect(find.text('Form Page'), findsNothing);
    expect(find.text('Go to Form'), findsOneWidget);
  });

  testWidgets('FormixNavigationGuard allows navigation when not dirty', (
    tester,
  ) async {
    bool dialogShown = false;

    const nameField = FormixFieldID<String>('name');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Formix(
                    child: FormixNavigationGuard(
                      showDirtyDialog: (context) async {
                        dialogShown = true;
                        return true;
                      },
                      child: Scaffold(
                        body: Column(
                          children: [
                            const FormixSection(
                              fields: [FormixFieldConfig(id: nameField)],
                              child: FormixTextFormField(fieldId: nameField),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Go to Form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go to Form'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(dialogShown, isFalse);
    expect(find.text('Go to Form'), findsOneWidget);
  });

  testWidgets('FormixNavigationGuard prevents pop if dialog returns false', (
    tester,
  ) async {
    const nameField = FormixFieldID<String>('name');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Formix(
                    child: FormixNavigationGuard(
                      showDirtyDialog: (context) async => false, // Don't discard
                      child: Scaffold(
                        body: Column(
                          children: [
                            const FormixSection(
                              fields: [FormixFieldConfig(id: nameField)],
                              child: FormixTextFormField(fieldId: nameField),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Go to Form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go to Form'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'John');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));

    await tester.runAsync(() async {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    await tester.pumpAndSettle();

    expect(find.text('Back'), findsOneWidget);
  });
}
