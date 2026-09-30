import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Field ids reused across tests.
final _a = FormixFieldID<String>('a');
final _b = FormixFieldID<String>('b');
final _upper = FormixFieldID<String>('upper');
final _derived = FormixFieldID<String>('derived');

Widget _inFormix(Widget child, {FormixController? controller, List<FormixFieldConfig> fields = const []}) {
  return MaterialApp(
    home: Scaffold(
      body: Formix(
        controller: controller,
        fields: fields.cast<FormixFieldConfig<dynamic>>(),
        child: child,
      ),
    ),
  );
}

void main() {
  group('logic widgets error out when used outside Formix', () {
    testWidgets('FormixFieldDerivation shows config error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FormixFieldDerivation(
          dependencies: [_a],
          targetField: _derived,
          derive: (_) => 'x',
        ),
      ));
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });

    testWidgets('FormixFieldDerivations shows config error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FormixFieldDerivations(
          derivations: [
            FieldDerivationConfig(
              dependencies: [_a],
              targetField: _derived,
              derive: (_) => 'x',
            ),
          ],
        ),
      ));
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });

    testWidgets('FormixFieldTransformer shows config error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FormixFieldTransformer<String, String>(
          sourceField: _a,
          targetField: _upper,
          transform: (v) => (v ?? '').toUpperCase(),
        ),
      ));
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });

    testWidgets('FormixFieldRegistry shows config error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FormixFieldRegistry(
          fields: [
            FormixFieldConfig<String>(id: _a, initialValue: ''),
          ],
          child: const SizedBox(),
        ),
      ));
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('FormixFieldDerivation', () {
    testWidgets('derives on mount and when a selected dependency part changes',
        (tester) async {
      await tester.pumpWidget(_inFormix(
        FormixFieldDerivation(
          dependencies: [_a],
          targetField: _derived,
          selectors: {_a: (v) => (v as String?)?.length},
          derive: (values) => 'len=${(values[_a] as String? ?? '').length}',
        ),
        fields: [
          FormixFieldConfig<String>(id: _a, initialValue: ''),
          FormixFieldConfig<String>(id: _derived, initialValue: ''),
        ],
      ));
      await tester.pump(); // register + first derive
      await tester.pump(); // microtask setValue
      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixFieldDerivation)),
      )!;
      expect(controller.getValue(_derived), 'len=0');

      controller.setValue(_a, 'ab');
      await tester.pump();
      await tester.pump();
      expect(controller.getValue(_derived), 'len=2');
    });

    testWidgets('derive throwing is swallowed (no crash)', (tester) async {
      await tester.pumpWidget(_inFormix(
        FormixFieldDerivation(
          dependencies: [_a],
          targetField: _derived,
          derive: (_) => throw StateError('bad derive'),
        ),
        fields: [
          FormixFieldConfig<String>(id: _a, initialValue: ''),
          FormixFieldConfig<String>(id: _derived, initialValue: ''),
        ],
      ));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('FormixFieldDerivations (multi)', () {
    testWidgets('runs multiple derivations independently', (tester) async {
      final c1 = FormixFieldID<String>('c1');
      final c2 = FormixFieldID<String>('c2');
      final out1 = FormixFieldID<String>('out1');
      final out2 = FormixFieldID<String>('out2');
      await tester.pumpWidget(_inFormix(
        FormixFieldDerivations(
          derivations: [
            FieldDerivationConfig(
              dependencies: [c1],
              targetField: out1,
              selectors: {c1: (v) => v},
              derive: (values) => 'a:${values[c1]}',
            ),
            FieldDerivationConfig(
              dependencies: [c2],
              targetField: out2,
              derive: (values) => 'b:${values[c2]}',
            ),
          ],
        ),
        fields: [
          FormixFieldConfig<String>(id: c1, initialValue: '1'),
          FormixFieldConfig<String>(id: c2, initialValue: '2'),
          FormixFieldConfig<String>(id: out1, initialValue: ''),
          FormixFieldConfig<String>(id: out2, initialValue: ''),
        ],
      ));
      await tester.pump();
      await tester.pump();
      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixFieldDerivations)),
      )!;
      expect(controller.getValue(out1), 'a:1');
      expect(controller.getValue(out2), 'b:2');
    });
  });

  group('FormixFieldTransformer', () {
    testWidgets('transforms source into target on change', (tester) async {
      await tester.pumpWidget(_inFormix(
        FormixFieldTransformer<String, String>(
          sourceField: _a,
          targetField: _upper,
          select: (v) => v,
          transform: (v) => (v ?? '').toUpperCase(),
        ),
        fields: [
          FormixFieldConfig<String>(id: _a, initialValue: 'hi'),
          FormixFieldConfig<String>(id: _upper, initialValue: ''),
        ],
      ));
      await tester.pump();
      await tester.pump();
      final controller = Formix.controllerOf(
        tester.element(find.byType(FormixFieldTransformer<String, String>)),
      )!;
      controller.setValue(_a, 'bye');
      await tester.pump();
      await tester.pump();
      expect(controller.getValue(_upper), 'BYE');
    });
  });

  group('FormixDependentField', () {
    testWidgets('rebuilds when the watched field changes and honors select',
        (tester) async {
      final controller = FormixController(
        fields: [FormixField<String>(id: _a, initialValue: 'x')],
      );
      addTearDown(controller.dispose);

      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: FormixDependentField<String>(
          fieldId: _a,
          controller: controller,
          select: (v) => v?.length,
          builder: (context, value) {
            builds++;
            return Text('v=$value', textDirection: TextDirection.ltr);
          },
        ),
      ));
      await tester.pump();
      final buildsAfterMount = builds;

      // Same length -> select gates the rebuild.
      controller.setValue(_a, 'y');
      await tester.pump();
      expect(builds, buildsAfterMount);

      // Different length -> rebuild.
      controller.setValue(_a, 'zzz');
      await tester.pump();
      expect(builds, greaterThan(buildsAfterMount));
    });

    testWidgets('didUpdateWidget rewires when fieldId changes', (tester) async {
      final controller = FormixController(fields: [
        FormixField<String>(id: _a, initialValue: 'aaa'),
        FormixField<String>(id: _b, initialValue: 'bbb'),
      ]);
      addTearDown(controller.dispose);

      Widget build(FormixFieldID<String> id) => MaterialApp(
            home: FormixDependentField<String>(
              fieldId: id,
              controller: controller,
              builder: (context, value) =>
                  Text('v=$value', textDirection: TextDirection.ltr),
            ),
          );

      await tester.pumpWidget(build(_a));
      await tester.pump();
      expect(find.text('v=aaa'), findsOneWidget);

      await tester.pumpWidget(build(_b));
      await tester.pump();
      expect(find.text('v=bbb'), findsOneWidget);
    });
  });

  group('FormixListener', () {
    testWidgets('external key: listens, select gates, formKey change rewires',
        (tester) async {
      final key1 = GlobalKey<FormixState>();
      final key2 = GlobalKey<FormixState>();
      final notifications = <bool>[];

      Widget build(GlobalKey<FormixState> key) => MaterialApp(
            home: Column(
              children: [
                Formix(
                  key: key1,
                  fields: [FormixFieldConfig<String>(id: _a, initialValue: '')],
                  child: const SizedBox(),
                ),
                Formix(
                  key: key2,
                  fields: [FormixFieldConfig<String>(id: _b, initialValue: '')],
                  child: const SizedBox(),
                ),
                FormixListener(
                  formKey: key,
                  select: (s) => s.isValid,
                  listener: (context, state) => notifications.add(state.isValid),
                  child: const SizedBox(),
                ),
              ],
            ),
          );

      await tester.pumpWidget(build(key1));
      await tester.pump(); // post-frame subscribe

      // Change a value that does not change the selected value (isValid).
      key1.currentState!.controller.setValue(_a, 'changed');
      await tester.pump();
      // select gates: isValid did not flip, so no new notification necessarily.

      // Swap the formKey -> didUpdateWidget rewires.
      await tester.pumpWidget(build(key2));
      await tester.pump();
      key2.currentState!.controller.setValue(_b, 'y');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing key shows config error', (tester) async {
      final orphan = GlobalKey<FormixState>();
      await tester.pumpWidget(MaterialApp(
        home: FormixListener(
          formKey: orphan,
          listener: (_, __) {},
          child: const SizedBox(),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('FormixFieldRegistry lazy fields', () {
    testWidgets('registers on mount and reacts to fields prop changes',
        (tester) async {
      final controller = FormixController();
      addTearDown(controller.dispose);
      final f1 = FormixFieldConfig<String>(id: _a, initialValue: '');
      final f2 = FormixFieldConfig<String>(id: _b, initialValue: '');

      Widget build(List<FormixFieldConfig<dynamic>> fields) => MaterialApp(
            home: Formix(
              controller: controller,
              child: FormixFieldRegistry(
                fields: fields,
                child: const SizedBox(),
              ),
            ),
          );

      await tester.pumpWidget(build([f1]));
      await tester.pump();
      expect(controller.isFieldRegistered(_a), isTrue);

      // Change fields: drop _a, add _b.
      await tester.pumpWidget(build([f2]));
      await tester.pump();
      await tester.pump(); // microtask unregister
      expect(controller.isFieldRegistered(_b), isTrue);
      expect(controller.isFieldRegistered(_a), isFalse);
    });
  });

  group('Formix.didUpdateWidget', () {
    testWidgets('keepAlive toggle and external controller swap', (tester) async {
      final c1 = FormixController(fields: [
        FormixField<String>(id: _a, initialValue: 'one'),
      ]);
      final c2 = FormixController(fields: [
        FormixField<String>(id: _a, initialValue: 'two'),
      ]);
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      Widget build(FormixController controller, bool keepAlive) => MaterialApp(
            home: Formix(
              controller: controller,
              keepAlive: keepAlive,
              child: FormixDependentField<String>(
                fieldId: _a,
                builder: (context, value) =>
                    Text('v=$value', textDirection: TextDirection.ltr),
              ),
            ),
          );

      await tester.pumpWidget(build(c1, false));
      await tester.pump();
      expect(find.text('v=one'), findsOneWidget);

      // Toggle keepAlive -> updateKeepAlive branch.
      await tester.pumpWidget(build(c1, true));
      await tester.pump();

      // Swap external controller -> controller-swap branch.
      await tester.pumpWidget(build(c2, true));
      await tester.pump();
      expect(find.text('v=two'), findsOneWidget);
    });
  });

  group('FormixThemeData', () {
    test('equality and hashCode', () {
      const a = FormixThemeData();
      const b = FormixThemeData();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      const c = FormixThemeData(enabled: false);
      expect(a == c, isFalse);
    });
  });
}
