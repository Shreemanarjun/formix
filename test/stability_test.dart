import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Rebuild and Stability Tests', () {
    testWidgets('FormixController instance is preserved when localization messages change', (tester) async {
      addTearDown(() => formixGlobalMessages.value = const DefaultFormixMessages());
      formixGlobalMessages.value = const DefaultFormixMessages();

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            child: Builder(
              builder: (context) {
                final controller = Formix.controllerOf(context);
                return Text('Hash: ${identityHashCode(controller)}');
              },
            ),
          ),
        ),
      );

      final text1 = tester.widget<Text>(find.byType(Text)).data!;

      // Trigger a message change via the global messages signal.
      formixGlobalMessages.value = const CustomMessages();

      await tester.pump();

      final text2 = tester.widget<Text>(find.byType(Text)).data!;

      expect(text1, text2, reason: 'Controller instance should be preserved when messages change');
    });

    testWidgets('FormixController is preserved when parent rebuilds with identical initialValue map instance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rebuild'),
                  ),
                  Formix(
                    // Pass a NEW map instance every build, but with same content
                    initialValue: Map<String, dynamic>.from({'a': 1}),
                    child: Builder(
                      builder: (context) {
                        final controller = Formix.controllerOf(context);
                        return Text('Hash: ${identityHashCode(controller)}');
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

      final text1 = tester.widget<Text>(find.byType(Text).last).data!;

      await tester.tap(find.text('Rebuild'));
      await tester.pump();

      final text2 = tester.widget<Text>(find.byType(Text).last).data!;

      expect(text1, text2, reason: 'Controller should be preserved even if initialValue map is a new instance with same content');
    });

    testWidgets('Field registration is NOT triggered if fields list is identical', (tester) async {
      final fields = [
        const FormixFieldConfig<String>(id: FormixFieldID<String>('name'), initialValue: ''),
      ];

      late FormixData stateBefore;
      late FormixData stateAfter;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rebuild'),
                  ),
                  Formix(
                    fields: List.from(fields), // New list instance every time
                    child: Builder(
                      builder: (context) {
                        final controller = Formix.of(context)!;
                        stateAfter = controller.state; // Keep track of latest state
                        return const Text('Watching');
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.pump();
      stateBefore = stateAfter;

      await tester.tap(find.text('Rebuild'));
      await tester.pump();

      expect(identical(stateBefore, stateAfter), isTrue, reason: 'State instance should be identical if no registration occurred');
    });

    testWidgets('FormixParameter equality handles nulls and deep maps correctly', (tester) async {
      const p1 = FormixParameter(initialValue: {'a': 1}, formId: 'test');
      const p2 = FormixParameter(initialValue: {'a': 1}, formId: 'test');
      final p3 = FormixParameter(initialValue: Map.from({'a': 1}), formId: 'test');

      expect(p1 == p2, isTrue);
      expect(p1 == p3, isTrue);
      expect(p1.hashCode, p3.hashCode);

      const p4 = FormixParameter(initialValue: {'a': 2}, formId: 'test');
      // Even with different initialValue, if formId is same, they are equal (prioritizing stable formId)
      expect(p1 == p4, isTrue);
    });
  });
}

class CustomMessages extends DefaultFormixMessages {
  const CustomMessages();
  @override
  String required(String label) => 'Custom Required: $label';
}
