import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
import 'package:formix/formix_test.dart';

void main() {
  const name = FormixFieldID<String>('name');
  const email = FormixFieldID<String>('email');
  const age = FormixFieldID<int>('age');
  const city = FormixFieldID<String>('city');

  group('controller[] operators (Tier B#6)', () {
    test('get and set via subscript', () {
      final c = FormixController(initialValue: const {'name': 'Ada'});
      addTearDown(c.dispose);

      expect(c[name], 'Ada');
      c[name] = 'Grace';
      expect(c[name], 'Grace');
      expect(c.getValue(name), 'Grace');
    });
  });

  group('batchUpdate closure (Tier B#7)', () {
    test('applies multiple typed fields in one frame', () {
      final c = FormixController(initialValue: const {'name': '', 'age': 0});
      addTearDown(c.dispose);

      var notifications = 0;
      c.addListener((_) => notifications++, fireImmediately: false);

      c.batchUpdate(
        (b) => b
          ..set(name, 'Ada')
          ..set(age, 36),
      );

      expect(c.getValue(name), 'Ada');
      expect(c.getValue(age), 36);
      // A batch is a single state transition, not one per field.
      expect(notifications, 1);
    });
  });

  group('typed record groups (Tier C#12)', () {
    test('group2 returns a destructurable typed record', () {
      final c = FormixController(initialValue: const {'name': 'Ada', 'age': 36});
      addTearDown(c.dispose);

      final (String? n, int? a) = c.group2(name, age).value;
      expect(n, 'Ada');
      expect(a, 36);
    });

    test('group2 signal rebuilds only when a member changes and is cached', () {
      final c = FormixController(initialValue: const {'name': '', 'age': 0, 'city': ''});
      addTearDown(c.dispose);

      final g = c.group2(name, age);
      expect(identical(c.group2(name, age), g), isTrue, reason: 'cached per (keys, types)');

      var fires = 0;
      final dispose = g.subscribe((_) => fires++);
      final baseline = fires; // subscribe fires once immediately

      c.setValue(city, 'Paris'); // not a member → no fire
      expect(fires, baseline);

      c.setValue(name, 'Ada'); // member → one fire
      expect(fires, baseline + 1);
      expect(g.value, ('Ada', 0));
      dispose();
    });

    test('group3 and group4 compose typed records', () {
      final c = FormixController(
        initialValue: const {'name': 'Ada', 'age': 36, 'city': 'London', 'email': 'a@b.c'},
      );
      addTearDown(c.dispose);

      final (n, a, ct) = c.group3(name, age, city).value;
      expect([n, a, ct], ['Ada', 36, 'London']);

      final (n2, a2, ct2, e2) = c.group4(name, age, city, email).value;
      expect([n2, a2, ct2, e2], ['Ada', 36, 'London', 'a@b.c']);
    });
  });

  group('BuildContext extensions (Tier A#3)', () {
    testWidgets('context.formix and context.maybeFormix resolve the controller', (tester) async {
      late FormixController fromExt;
      FormixController? maybe;
      final c = await pumpFormix(
        tester,
        initialValue: const {'name': ''},
        child: Builder(
          builder: (context) {
            fromExt = context.formix;
            maybe = context.maybeFormix;
            return const SizedBox();
          },
        ),
      );

      expect(identical(fromExt, c), isTrue);
      expect(identical(maybe, c), isTrue);
    });

    testWidgets('maybeFormix is null with no ancestor', (tester) async {
      FormixController? maybe = FormixController(); // non-null sentinel
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              maybe = context.maybeFormix;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(maybe, isNull);
    });
  });

  group('FormixValue widget (Tier A#2)', () {
    testWidgets('rebuilds only when its field changes', (tester) async {
      final counter = RebuildCounter();
      final c = await pumpFormix(
        tester,
        initialValue: const {'name': '', 'email': ''},
        child: FormixValue<String>(
          name,
          builder: (context, value) => counter.wrap((_) => Text(value ?? '')),
        ),
      );
      final baseline = counter.count;

      c.setValue(email, 'x@y.com'); // unrelated
      await tester.pump();
      expect(counter, rebuiltExactly(baseline));

      c.setValue(name, 'Ada');
      await tester.pump();
      expect(counter, rebuiltExactly(baseline + 1));
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('shows a config error with no controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FormixValue<String>(name, builder: (context, value) => const SizedBox()),
        ),
      );
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('FormixSubmitButton widget (Tier A#4)', () {
    testWidgets('disabled while invalid, enabled + submits when valid', (tester) async {
      Map<String, dynamic>? submitted;
      final c = await pumpFormix(
        tester,
        fields: [
          FormixFieldConfig<String>(
            id: name,
            validationMode: FormixAutovalidateMode.always,
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
        child: FormixSubmitButton(
          onValid: (values) async => submitted = values,
          child: const Text('Save'),
        ),
      );
      await tester.pump();

      ElevatedButton btn() => tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      // Surface the required-field error, then the button disables.
      c.validate();
      await tester.pump();
      expect(btn().onPressed, isNull, reason: 'invalid → disabled');

      c.setValue(name, 'Ada');
      await tester.pump();
      expect(btn().onPressed, isNotNull, reason: 'valid → enabled');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(submitted, {'name': 'Ada'});
    });
  });

  group('scope.watch alias (Tier B#9)', () {
    testWidgets('watch(id) is an alias for watchValue(id)', (tester) async {
      final c = await pumpFormix(
        tester,
        initialValue: const {'name': 'Ada'},
        child: FormixBuilder(
          builder: (context, scope) => Text(scope.watch(name) ?? ''),
        ),
      );
      expect(find.text('Ada'), findsOneWidget);

      c.setValue(name, 'Grace');
      await tester.pump();
      expect(find.text('Grace'), findsOneWidget);
    });
  });
}
