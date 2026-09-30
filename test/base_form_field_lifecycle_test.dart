import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Concrete implementation for testing
class TestTextField extends FormixFieldWidget<String> {
  const TestTextField({super.key, required super.fieldId, super.initialValue});

  @override
  TestTextFieldState createState() => TestTextFieldState();
}

class TestTextFieldState extends FormixFieldWidgetState<String> with FormixFieldTextMixin<String> {
  @override
  String? stringToValue(String text) => text;

  @override
  String valueToString(String? value) => value ?? '';

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: textController,
      key: const Key('text_field'),
    );
  }
}

void main() {
  const fieldId = FormixFieldID<String>('test_field');

  Widget buildTestApp({
    required Widget child,
    Map<String, dynamic>? initialValue,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Formix(initialValue: initialValue ?? const {}, child: child),
      ),
    );
  }

  group('FormixFieldTextMixin Lifecycle', () {
    testWidgets('initializes textController correctly', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          initialValue: {fieldId.key: 'initial'},
          child: const TestTextField(fieldId: fieldId),
        ),
      );

      final fieldFinder = find.byType(TestTextField);
      expect(find.text('initial'), findsOneWidget);

      final state = tester.state<TestTextFieldState>(fieldFinder);
      expect(state.textController.text, 'initial');
    });

    testWidgets(
      'handles didChangeDependencies without crashing (re-initialization check)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                initialValue: {fieldId.key: 'value1'},
                child: Builder(
                  builder: (context) {
                    MediaQuery.of(context);
                    return const TestTextField(fieldId: fieldId);
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('value1'), findsOneWidget);

        // Trigger a dependency change by updating MediaQuery data
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Formix(
                initialValue: {fieldId.key: 'value1'},
                child: Builder(
                  builder: (context) {
                    MediaQuery.of(context);
                    return const TestTextField(fieldId: fieldId);
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('value1'), findsOneWidget);
      },
    );

    testWidgets(
      'updates text when controller value changes externally and dependencies update',
      (tester) async {
        final formKey = GlobalKey<FormixState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                initialValue: {fieldId.key: 'initial'},
                child: const TestTextField(fieldId: fieldId),
              ),
            ),
          ),
        );

        expect(find.text('initial'), findsOneWidget);

        // Update value via controller
        formKey.currentState!.controller.setValue(fieldId, 'updated');
        await tester.pump();

        expect(find.text('updated'), findsOneWidget);
      },
    );

    testWidgets('updates text when parent Formix rebuilds with new values', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              key: const ValueKey('value1'),
              initialValue: {fieldId.key: 'value1'},
              child: const TestTextField(fieldId: fieldId),
            ),
          ),
        ),
      );

      expect(find.text('value1'), findsOneWidget);

      // Rebuild with different initial value.
      // This simulates a full rebuild of the form with new data. A changed key
      // yields a fresh FormixState (and controller), mirroring how the old
      // family provider created a new entry when the FormixParameter changed.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              key: const ValueKey('value2'),
              initialValue: {fieldId.key: 'value2'},
              child: const TestTextField(fieldId: fieldId),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // A new form instance should have the new value.
      expect(find.text('value2'), findsOneWidget);
    });

    testWidgets('preserves textController instance on dependency change', (
      tester,
    ) async {
      final fieldKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: {fieldId.key: 'initial'},
              child: TestTextField(key: fieldKey, fieldId: fieldId),
            ),
          ),
        ),
      );

      final state = tester.state<TestTextFieldState>(find.byKey(fieldKey));
      final originalController = state.textController;
      expect(originalController.text, 'initial');

      // Trigger rebuild/dependency change
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Formix(
              initialValue: {fieldId.key: 'initial'},
              child: TestTextField(key: fieldKey, fieldId: fieldId),
            ),
          ),
        ),
      );

      await tester.pump();

      final newState = tester.state<TestTextFieldState>(find.byKey(fieldKey));
      final newController = newState.textController;

      // Verify it's the same state object
      expect(newState, equals(state));
      // Verify it's the exact same controller instance (crucial for fix verification)
      expect(newController, same(originalController));
      // And text is preserved
      expect(newController.text, 'initial');
    });
  });
}
