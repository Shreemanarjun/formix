import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('type-scoped validators (no codegen)', () {
    test('NumberValidator.between enforces inclusive bounds', () {
      final v = FormixValidators.number<int>().between(1, 10).build();
      expect(v(0), isNotNull);
      expect(v(1), isNull);
      expect(v(10), isNull);
      expect(v(11), isNotNull);
      expect(v(null), isNull); // null defers to required()
    });

    test('DateTimeValidator after/before/between', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final after = FormixValidators.date().after(start).build();
      expect(after(DateTime(2023, 6, 1)), isNotNull);
      expect(after(DateTime(2024, 6, 1)), isNull);

      final before = FormixValidators.date().before(end).build();
      expect(before(DateTime(2025, 1, 1)), isNotNull);
      expect(before(DateTime(2024, 6, 1)), isNull);

      final between = FormixValidators.date().between(start, end).build();
      expect(between(DateTime(2023, 12, 31)), isNotNull);
      expect(between(DateTime(2024, 6, 1)), isNull);
      expect(between(DateTime(2025, 1, 1)), isNotNull);
    });

    test('GenericValidator.oneOf restricts to allowed options', () {
      final v = FormixValidators.any<String>().oneOf(['a', 'b']).build();
      expect(v('a'), isNull);
      expect(v('c'), isNotNull);
      expect(v(null), isNull);
    });

    test('date validation message resolves via i18n (not the raw key)', () {
      const dob = FormixFieldID<DateTime>('dob');
      final c = FormixController(
        fields: [
          FormixFieldConfig<DateTime>(
            id: dob,
            validationMode: FormixAutovalidateMode.always,
            validator: FormixValidators.date().after(DateTime(2000, 1, 1)).build(),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.setValue(dob, DateTime(1990, 1, 1));
      c.validate();
      final msg = c.getValidation(dob).errorMessage;
      expect(msg, isNotNull);
      expect(msg, isNot(startsWith('formix_key_')), reason: 'key must resolve to a message');
    });
  });

  group('typed record writes (setGroup)', () {
    const email = FormixFieldID<String>('email');
    const age = FormixFieldID<int>('age');
    const city = FormixFieldID<String>('city');

    test('setGroup2 writes both fields in one batch', () {
      final c = FormixController(initialValue: const {'email': '', 'age': 0});
      addTearDown(c.dispose);

      var notifications = 0;
      c.addListener((_) => notifications++, fireImmediately: false);

      c.setGroup2(email, age, ('a@b.c', 42));
      expect(c.getValue(email), 'a@b.c');
      expect(c.getValue(age), 42);
      expect(notifications, 1, reason: 'single state transition');
    });

    test('setGroup3 round-trips with group3 read', () {
      final c = FormixController(initialValue: const {'email': '', 'age': 0, 'city': ''});
      addTearDown(c.dispose);
      c.setGroup3(email, age, city, ('x@y.z', 7, 'Paris'));
      expect(c.group3(email, age, city).value, ('x@y.z', 7, 'Paris'));
    });
  });

  group('duplicate-key guard (debug assert)', () {
    test('registering two fields with the same key throws in debug', () {
      const a = FormixFieldID<String>('dup');
      const b = FormixFieldID<int>('dup');
      expect(
        () => FormixController(fields: const [
          FormixFieldConfig<String>(id: a),
          FormixFieldConfig<int>(id: b),
        ]),
        throwsA(isA<FlutterError>()),
      );
    });

    test('unique keys register fine', () {
      final c = FormixController(fields: const [
        FormixFieldConfig<String>(id: FormixFieldID<String>('a')),
        FormixFieldConfig<int>(id: FormixFieldID<int>('b')),
      ]);
      addTearDown(c.dispose);
      expect(c.getValue(const FormixFieldID<String>('a')), isNull);
    });
  });

  group('sealed submission state', () {
    const sname = FormixFieldID<String>('name');

    FormixController makeForm() => FormixController(
          fields: [
            FormixFieldConfig<String>(
              id: sname,
              validationMode: FormixAutovalidateMode.always,
              validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
            ),
          ],
        );

    test('idle → submitting → success on a valid submit', () async {
      final c = makeForm();
      addTearDown(c.dispose);
      c.setValue(sname, 'Ada');

      expect(c.submissionSignal.value, const FormixSubmission.idle());

      final states = <FormixSubmission>[];
      final dispose = c.submissionSignal.subscribe(states.add);
      await c.submit(onValid: (_) async {});
      dispose();

      expect(c.submissionSignal.value, const FormixSubmission.success());
      expect(states.any((s) => s is FormixSubmissionSubmitting), isTrue);
    });

    test('error state carries the thrown object', () async {
      final c = makeForm();
      addTearDown(c.dispose);
      c.setValue(sname, 'Ada');

      await expectLater(
        c.submit(onValid: (_) async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      final s = c.submissionSignal.value;
      expect(s, isA<FormixSubmissionError>());
      expect((s as FormixSubmissionError).error, isA<StateError>());
    });

    test('invalid submit stays idle', () async {
      final c = makeForm(); // name empty → invalid
      addTearDown(c.dispose);
      await c.submit(onValid: (_) async {}, onError: (_) {});
      expect(c.submissionSignal.value, const FormixSubmission.idle());
    });

    test('states are exhaustively switchable', () {
      String label(FormixSubmission s) => switch (s) {
            FormixSubmissionIdle() => 'idle',
            FormixSubmissionSubmitting() => 'submitting',
            FormixSubmissionSuccess() => 'success',
            FormixSubmissionError() => 'error',
          };
      expect(label(const FormixSubmission.idle()), 'idle');
      expect(label(const FormixSubmission.error('x')), 'error');
    });
  });

  group('async generation guard (perf/correctness)', () {
    test('a superseded in-flight async result is dropped', () async {
      const q = FormixFieldID<String>('q');
      final completers = <String, Completer<String?>>{};
      final c = FormixController(
        fields: [
          FormixFieldConfig<String>(
            id: q,
            validationMode: FormixAutovalidateMode.always,
            debounceDuration: const Duration(milliseconds: 1),
            asyncValidator: (v) {
              final comp = Completer<String?>();
              completers[v ?? ''] = comp;
              return comp.future;
            },
          ),
        ],
      );
      addTearDown(c.dispose);

      c.setValue(q, 'a');
      await Future<void>.delayed(const Duration(milliseconds: 20)); // 'a' debounce fires, awaits
      c.setValue(q, 'b');
      await Future<void>.delayed(const Duration(milliseconds: 20)); // 'b' debounce fires, awaits

      // Resolve the STALE 'a' with an error first, then the current 'b' as valid.
      completers['a']!.complete('stale error');
      await Future<void>.delayed(Duration.zero);
      completers['b']!.complete(null);
      await Future<void>.delayed(Duration.zero);

      // The stale 'a' error must not stick; the current 'b' result wins.
      expect(c.getValidation(q).isValid, isTrue);
      expect(c.getValidation(q).errorMessage, isNull);
    });
  });

  group('no-op write does not notify (perf guard)', () {
    test('re-setting the same value triggers no state notification', () {
      const name = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': 'Ada'},
        fields: [
          FormixFieldConfig<String>(
            id: name,
            validationMode: FormixAutovalidateMode.always,
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
      );
      addTearDown(c.dispose);
      c.validate(); // establish a validation entry

      var notifications = 0;
      c.addListener((_) => notifications++, fireImmediately: false);

      c.setValue(name, 'Ada'); // same value → no-op
      c.setValue(name, 'Ada');
      expect(notifications, 0, reason: 'unchanged value must not allocate/notify');

      c.setValue(name, 'Grace'); // real change → one notification
      expect(notifications, 1);
    });
  });
}
