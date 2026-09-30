import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
import 'package:signals_flutter/signals_flutter.dart' show AsyncState;

void main() {
  group('FormixFieldSelector rebinding (didUpdateWidget)', () {
    testWidgets('changing fieldId rebinds listeners; select refresh path', (tester) async {
      const a = FormixFieldID<String>('a');
      const b = FormixFieldID<String>('b');
      final c = FormixController(
        initialValue: const {'a': 'A0', 'b': 'B0'},
        fields: const [
          FormixField<String>(id: a, initialValue: 'A0'),
          FormixField<String>(id: b, initialValue: 'B0'),
        ],
      );
      addTearDown(c.dispose);

      var useA = true;
      Object? sel(String? v) => v;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixFieldSelector<String>(
                        fieldId: useA ? a : b,
                        select: sel,
                        builder: (context, info, child) => Text('v=${info.value}'),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => useA = !useA),
                        child: const Text('swap'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('v=A0'), findsOneWidget);

      // Change fieldId -> hits didUpdateWidget rebind branch.
      await tester.tap(find.text('swap'));
      await tester.pump();
      expect(find.text('v=B0'), findsOneWidget);

      // Change value and confirm the selector responds.
      c.setValue(b, 'B1');
      await tester.pump();
      expect(find.text('v=B1'), findsOneWidget);
    });

    testWidgets('changing only the select callback refreshes state', (tester) async {
      const a = FormixFieldID<String>('a');
      final c = FormixController(
        initialValue: const {'a': 'hello'},
        fields: const [FormixField<String>(id: a, initialValue: 'hello')],
      );
      addTearDown(c.dispose);

      var upper = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixFieldSelector<String>(
                        fieldId: a,
                        select: upper ? (v) => v?.toUpperCase() : (v) => v?.toLowerCase(),
                        builder: (context, info, child) => Text('sel=${info.value}'),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => upper = !upper),
                        child: const Text('toggle'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Toggle select only (fieldId unchanged) -> hits the select-only branch.
      await tester.tap(find.text('toggle'));
      await tester.pump();
      c.setValue(a, 'World');
      await tester.pump();
      expect(find.text('sel=World'), findsOneWidget);
    });
  });

  group('FormixListener', () {
    testWidgets('ancestor listener fires with select gating', (tester) async {
      const a = FormixFieldID<String>('a');
      final c = FormixController(
        initialValue: const {'a': ''},
        fields: const [FormixField<String>(id: a, initialValue: '')],
      );
      addTearDown(c.dispose);

      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: FormixListener(
                select: (state) => state.values['a'],
                listener: (context, state) => calls++,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(); // post-frame subscribe

      c.setValue(a, 'x');
      await tester.pump();
      expect(calls, greaterThan(0));

      final before = calls;
      // Change something the selector ignores -> listener must NOT fire.
      c.markAsTouched(a);
      await tester.pump();
      expect(calls, before);
    });

    testWidgets('external formKey that is missing shows config error', (tester) async {
      final key = GlobalKey<FormixState>();
      await tester.pumpWidget(
        MaterialApp(
          home: FormixListener(
            formKey: key,
            listener: (_, __) {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });

    testWidgets('swapping to an available formKey clears the init error (97/98)', (tester) async {
      final missingKey = GlobalKey<FormixState>();
      final realKey = GlobalKey<FormixState>();
      var useMissing = true;
      late StateSetter setOuter;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return Column(
                children: [
                  // A real Formix mounted under realKey elsewhere in the tree.
                  Formix(
                    key: realKey,
                    fields: const [
                      FormixFieldConfig<String>(
                        id: FormixFieldID<String>('a'),
                        initialValue: '',
                      ),
                    ],
                    child: const SizedBox.shrink(),
                  ),
                  FormixListener(
                    formKey: useMissing ? missingKey : realKey,
                    listener: (_, __) {},
                    child: const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(); // post-frame subscribe -> error set (missing key)
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);

      // Swap to the real key via the captured setter (the button would be hidden
      // behind the error widget) -> didUpdateWidget re-subscribes -> resolves the
      // controller and clears the previously-set init error (lines 97/98).
      setOuter(() => useMissing = false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsNothing);
    });
  });

  group('FormixFieldDerivations lifecycle', () {
    testWidgets('derive runs, catches errors, and rewires on prop change', (tester) async {
      const src = FormixFieldID<String>('src');
      const dst = FormixFieldID<String>('dst');
      const dst2 = FormixFieldID<String>('dst2');
      final c = FormixController(
        initialValue: const {'src': 'a', 'dst': '', 'dst2': ''},
        fields: const [
          FormixField<String>(id: src, initialValue: 'a'),
          FormixField<String>(id: dst, initialValue: ''),
          FormixField<String>(id: dst2, initialValue: ''),
        ],
      );
      addTearDown(c.dispose);

      // `swapped` changes the derivation's targetField so the new derivations
      // list is NOT listEquals to the old -> didUpdateWidget rewires (line 276),
      // which disposes the prior effect (line 218).
      var swapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixFieldDerivations(
                        derivations: [
                          FieldDerivationConfig(
                            dependencies: const [src],
                            targetField: swapped ? dst2 : dst,
                            derive: (values) {
                              final v = values[src] as String?;
                              if (v == 'boom') throw StateError('derive-boom');
                              return '$v!';
                            },
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => swapped = true),
                        child: const Text('swap'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      c.setValue(src, 'b');
      await tester.pump();
      await tester.pump();
      expect(c.getValue(dst), 'b!');

      // Make the derive throw -> caught (debugPrint) branch (line 264).
      c.setValue(src, 'boom');
      await tester.pump();
      await tester.pump();

      // Swap the derivation target -> different list -> rewire (276) + dispose (218).
      c.setValue(src, 'ok');
      await tester.tap(find.text('swap'));
      await tester.pump();
      await tester.pump();
      expect(c.getValue(dst2), 'ok!');
    });
  });

  group('FormixDependentAsyncField onRetry via reset', () {
    testWidgets('resetting the field triggers onRetry (refetch)', (tester) async {
      const dep = FormixFieldID<String>('country');
      const field = FormixFieldID<List<String>>('cities');
      final c = FormixController(
        initialValue: const {'country': 'US'},
        fields: const [FormixField<String>(id: dep, initialValue: 'US')],
      );
      addTearDown(c.dispose);

      var fetches = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: FormixDependentAsyncField<List<String>, String>(
                fieldId: field,
                dependency: dep,
                future: (country) async {
                  fetches++;
                  return ['$country-city'];
                },
                builder: (context, state) => Text('data=${state.asyncState.value}'),
                loadingBuilder: (context) => const Text('loading'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final initialFetches = fetches;

      // Reset the field -> inner FormixAsyncField.onReset -> refresh -> onRetry.
      c.resetFields([field], strategy: ResetStrategy.clear);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(fetches, greaterThan(initialFetches));
    });
  });

  group('FormixAsyncField no-future + didUpdateWidget asyncValue', () {
    testWidgets('null future settles pending; asyncValue change reinitialises', (tester) async {
      const field = FormixFieldID<String>('async');
      final c = FormixController();
      addTearDown(c.dispose);

      AsyncState<String> state = AsyncState.data('one');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      FormixAsyncField<String>(
                        fieldId: field,
                        asyncValue: state,
                        builder: (context, s) => Text('a=${s.asyncState.value}'),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => state = AsyncState.data('two')),
                        child: const Text('change'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('a=one'), findsOneWidget);

      // Change asyncValue -> didUpdateWidget reinit branch.
      await tester.tap(find.text('change'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('a=two'), findsOneWidget);
    });
  });

  group('SliverFormixArray', () {
    testWidgets('renders items inside a CustomScrollView', (tester) async {
      const arr = FormixArrayID<String>('items');
      final c = FormixController(
        initialValue: const {
          'items': <String>['x', 'y'],
        },
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arr,
                    itemBuilder: (context, index, itemId, scope) => Text('item $index'),
                    emptyBuilder: (context, scope) => const Text('empty'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('item 0'), findsOneWidget);

      // Mutate the array so the field listener rebuilds the sliver.
      c.addArrayItem(arr, 'z');
      await tester.pump();
      expect(find.text('item 2'), findsOneWidget);
    });

    testWidgets('shows config error outside Formix', (tester) async {
      const arr = FormixArrayID<String>('items');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverFormixArray<String>(
                  id: arr,
                  itemBuilder: (context, index, itemId, scope) => const Text('x'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('FormixSection', () {
    testWidgets('registers its fields under a Formix', (tester) async {
      const a = FormixFieldID<String>('sectionField');
      final c = FormixController();
      addTearDown(c.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              child: const FormixSection(
                fields: [
                  FormixFieldConfig<String>(id: a, initialValue: 'seeded'),
                ],
                child: FormixTextFormField(fieldId: a),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(c.isFieldRegistered(a), isTrue);
    });

    testWidgets('shows config error when used outside a Formix', (tester) async {
      const a = FormixFieldID<String>('x');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormixSection(
              fields: [FormixFieldConfig<String>(id: a, initialValue: '')],
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('FormixFieldSelector explicit controller swap (line 70)', () {
    testWidgets('changing the controller prop rebinds field listeners', (tester) async {
      const a = FormixFieldID<String>('a');
      final c1 = FormixController(
        initialValue: const {'a': 'one'},
        fields: const [FormixField<String>(id: a, initialValue: 'one')],
      );
      final c2 = FormixController(
        initialValue: const {'a': 'two'},
        fields: const [FormixField<String>(id: a, initialValue: 'two')],
      );
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      var useFirst = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  // Explicit controller -> no Formix ancestor needed.
                  FormixFieldSelector<String>(
                    controller: useFirst ? c1 : c2,
                    fieldId: a,
                    builder: (context, info, child) => Text('v=${info.value}'),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => useFirst = false),
                    child: const Text('swap-ctrl'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('v=one'), findsOneWidget);

      // Swap controller -> _updateController removes the old field listener (70).
      await tester.tap(find.text('swap-ctrl'));
      await tester.pump();
      expect(find.text('v=two'), findsOneWidget);
    });
  });

  group('const-constructor widgets instantiated at runtime', () {
    testWidgets('adaptive text field + FormixWidget subclass build', (tester) async {
      const a = FormixFieldID<String>('a');
      final c = FormixController(
        initialValue: const {'a': ''},
        fields: const [FormixField<String>(id: a, initialValue: '')],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              controller: c,
              // Non-const so the const constructors run at runtime.
              // ignore: prefer_const_constructors
              child: Column(
                children: [
                  // ignore: prefer_const_constructors
                  FormixAdaptiveTextFormField(fieldId: a),
                  _RuntimeFormixWidget(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FormixAdaptiveTextFormField), findsOneWidget);
      expect(find.text('from-widget'), findsOneWidget);
    });
  });
}

/// A minimal [FormixWidget] subclass instantiated non-const so its const
/// constructor (form_builder.dart) executes at runtime.
class _RuntimeFormixWidget extends FormixWidget {
  // ignore: prefer_const_constructors_in_immutables
  _RuntimeFormixWidget();
  @override
  Widget buildForm(BuildContext context, FormixScope scope) => const Text('from-widget');
}
