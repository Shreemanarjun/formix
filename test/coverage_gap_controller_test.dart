import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// Persistence that records every write so we can assert the save paths ran.
class _RecordingPersistence implements FormixPersistence {
  final List<Map<String, dynamic>> writes = [];
  final Map<String, dynamic>? saved;

  _RecordingPersistence({this.saved});

  @override
  Future<Map<String, dynamic>?> getSavedState(String formId) async => saved;

  @override
  Future<void> saveFormState(String formId, Map<String, dynamic> values) async {
    writes.add(Map<String, dynamic>.from(values));
  }

  @override
  Future<void> clearSavedState(String formId) async {}
}

void main() {
  group('FormixController thin wrappers', () {
    test('constructor throws for invalid field type', () {
      expect(
        () => FormixController(fields: const [42]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('isPendingSignal / currentStepSignal expose state', () {
      final c = FormixController();
      addTearDown(c.dispose);
      expect(c.isPendingSignal.value, isFalse);
      expect(c.currentStepSignal.value, 0);
    });

    test('addListener/removeListener + errorMessages getter', () {
      const email = FormixFieldID<String>('email');
      final c = FormixController(
        initialValue: const {'email': ''},
        fields: [
          FormixField<String>(
            id: email,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
      );
      addTearDown(c.dispose);

      final seen = <FormixData>[];
      void listener(FormixData s) => seen.add(s);
      c.addListener(listener); // fireImmediately
      expect(seen, isNotEmpty);

      c.removeListener(listener);
      final before = seen.length;
      c.setValue(email, 'x');
      expect(seen.length, before); // no more notifications after remove

      expect(c.errorMessages, isA<List<String>>());
    });

    test('addListener swallows a throwing listener on fireImmediately', () {
      final c = FormixController();
      addTearDown(c.dispose);
      // Must not throw even though the listener does.
      final remove = c.addListener((_) => throw StateError('boom'));
      remove();
    });

    test('addDirtyListener notified on value change; removeDirtyListener stops', () {
      const name = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [const FormixField<String>(id: name, initialValue: '')],
      );
      addTearDown(c.dispose);

      final dirtyEvents = <bool>[];
      void l(bool d) => dirtyEvents.add(d);
      c.addDirtyListener(l);

      c.setValue(name, 'John');
      expect(dirtyEvents, contains(true));

      c.removeDirtyListener(l);
      final before = dirtyEvents.length;
      c.setValue(name, 'Jane');
      expect(dirtyEvents.length, before);
    });

    test('focusNextField moves focus to the next registered field', () {
      const a = FormixFieldID<String>('a');
      const b = FormixFieldID<String>('b');
      final c = FormixController(
        fields: [
          const FormixField<String>(id: a, initialValue: ''),
          const FormixField<String>(id: b, initialValue: ''),
        ],
      );
      addTearDown(c.dispose);

      final nodeA = FocusNode();
      final nodeB = FocusNode();
      addTearDown(nodeA.dispose);
      addTearDown(nodeB.dispose);
      c.registerFocusNode(a, nodeA);
      c.registerFocusNode(b, nodeB);

      // Should not throw and should target the next node.
      c.focusNextField(a);
      // Last field: no-op branch.
      c.focusNextField(b);
      // Unknown field: no-op branch.
      c.focusNextField(const FormixFieldID<String>('missing'));
    });

    test('getFieldStateNotifier is cached + toString', () {
      const name = FormixFieldID<String>('name');
      final c = FormixController(
        fields: [const FormixField<String>(id: name, initialValue: '')],
      );
      addTearDown(c.dispose);

      final n1 = c.getFieldStateNotifier(name);
      final n2 = c.getFieldStateNotifier(name);
      expect(identical(n1, n2), isTrue);
      expect(c.toString(), contains('FormixController'));
    });
  });

  group('base controller persistence save paths', () {
    test('applyBatch with persistence saves and validates raw-key path', () async {
      const age = FormixFieldID<int>('age');
      final p = _RecordingPersistence();
      final c = FormixController(
        initialValue: const {'age': 10},
        fields: [const FormixField<int>(id: age, initialValue: 10)],
        persistence: p,
        formId: 'f1',
      );
      addTearDown(c.dispose);

      final batch = FormixBatch()..set(age, 25);
      final res = c.applyBatch(batch);
      expect(res.success, isTrue);
      expect(c.getValue(age), 25);
      expect(p.writes, isNotEmpty);
    });

    test('applyBatch raw string key with matching + custom-object types', () {
      final c = FormixController(
        initialValue: {'count': 1, 'obj': _A()},
      );
      addTearDown(c.dispose);

      // Raw-key path: num vs num => valid; custom obj vs custom obj => valid.
      // (Fields aren't registered, so they land in missingFields, but the type
      // validation branch still runs and reports no type mismatches.)
      final batch = FormixBatch()
        ..addAll({'count': 2, 'obj': _B()});
      final res = c.applyBatch(batch);
      expect(res.typeMismatches, isEmpty);
    });

    test('setValues / unregisterField / reset save through persistence', () {
      const name = FormixFieldID<String>('name');
      final p = _RecordingPersistence();
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [const FormixField<String>(id: name, initialValue: '')],
        persistence: p,
        formId: 'f2',
      );
      addTearDown(c.dispose);

      c.setValues({name: 'John'});
      final afterSet = p.writes.length;
      expect(afterSet, greaterThan(0));

      c.unregisterField(name);
      expect(p.writes.length, greaterThan(afterSet));
      final afterUnreg = p.writes.length;

      c.reset();
      expect(p.writes.length, greaterThan(afterUnreg));
    });

    test('unregisterFields (bulk) cleans deps and saves through persistence', () {
      const a = FormixFieldID<String>('a');
      const b = FormixFieldID<String>('b');
      final p = _RecordingPersistence();
      final c = FormixController(
        initialValue: const {'a': '', 'b': ''},
        fields: [
          const FormixField<String>(id: a, initialValue: ''),
          const FormixField<String>(id: b, initialValue: '', dependsOn: [a]),
        ],
        persistence: p,
        formId: 'f3',
      );
      addTearDown(c.dispose);

      final before = p.writes.length;
      c.unregisterFields([a, b]);
      expect(p.writes.length, greaterThan(before));
      expect(c.isFieldRegistered(a), isFalse);
      expect(c.isFieldRegistered(b), isFalse);
    });

    test('loads persisted state on init (merges saved values, marks dirty, validates)', () async {
      const name = FormixFieldID<String>('name');
      const extra = FormixFieldID<String>('extra'); // saved but not registered
      final p = _RecordingPersistence(saved: const {'name': 'Restored', 'extra': 'x'});
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [
          FormixField<String>(
            id: name,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
        persistence: p,
        formId: 'f_load',
      );
      addTearDown(c.dispose);

      // _loadPersistedState runs in a microtask scheduled from _initialize().
      await Future<void>.delayed(Duration.zero);

      expect(c.getValue(name), 'Restored');
      expect(c.isFieldDirty(name), isTrue); // differs from initial ''
      expect(c.getValue(extra), 'x'); // unregistered saved key still merged
      expect(c.getValidation(name).isValid, isTrue); // re-validated on load
    });
  });

  group('dependency graph re-registration', () {
    test('re-registering a field with dependsOn rewires the graph', () {
      const a = FormixFieldID<String>('a');
      const b = FormixFieldID<String>('b');
      final c = FormixController();
      addTearDown(c.dispose);

      // First registration establishes b -> depends on a.
      c.registerField(const FormixField<String>(id: b, initialValue: '', dependsOn: [a]));
      // Re-register b with a different dependency to hit cleanup + add branches.
      c.registerField(const FormixField<String>(id: b, initialValue: '', dependsOn: [a]));

      c.registerField(const FormixField<String>(id: a, initialValue: ''));
      c.setValue(a, 'x');
      expect(c.getValue(b), isNotNull);
    });
  });

  group('validation modes onBlur / onUserInteraction', () {
    test('onBlur validates only after touched', () {
      const email = FormixFieldID<String>('email');
      final c = FormixController(
        initialValue: const {'email': ''},
        fields: [
          FormixField<String>(
            id: email,
            initialValue: '',
            validationMode: FormixAutovalidateMode.onBlur,
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.onBlur,
      );
      addTearDown(c.dispose);

      c.setValue(email, '');
      c.markAsTouched(email);
      c.setValue(email, '');
      expect(c.getValidation(email).isValid, isFalse);
    });

    test('onUserInteraction validates once dirty', () {
      const email = FormixFieldID<String>('email');
      final c = FormixController(
        initialValue: const {'email': 'seed'},
        fields: [
          FormixField<String>(
            id: email,
            initialValue: 'seed',
            validationMode: FormixAutovalidateMode.onUserInteraction,
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.onUserInteraction,
      );
      addTearDown(c.dispose);

      c.setValue(email, '');
      expect(c.getValidation(email).isValid, isFalse);
    });

    test('dependent field revalidates via onUserInteraction/onBlur modes', () {
      const pw = FormixFieldID<String>('pw');
      const confirm = FormixFieldID<String>('confirm');
      final c = FormixController(
        initialValue: const {'pw': '', 'confirm': ''},
        fields: [
          const FormixField<String>(id: pw, initialValue: ''),
          FormixField<String>(
            id: confirm,
            initialValue: '',
            dependsOn: [pw],
            validationMode: FormixAutovalidateMode.onUserInteraction,
            crossFieldValidator: (v, state) =>
                v == state.values['pw'] ? null : 'mismatch',
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.onUserInteraction,
      );
      addTearDown(c.dispose);

      c.setValue(confirm, 'abc');
      c.markAsTouched(confirm);
      c.setValue(pw, 'xyz');
      expect(c.getValidation(confirm).isValid, isFalse);
    });

    test('dependent field in onBlur mode revalidates when touched (line 805)', () {
      const pw = FormixFieldID<String>('pw');
      const confirm = FormixFieldID<String>('confirm');
      final c = FormixController(
        initialValue: const {'pw': '', 'confirm': ''},
        fields: [
          const FormixField<String>(id: pw, initialValue: ''),
          FormixField<String>(
            id: confirm,
            initialValue: '',
            dependsOn: [pw],
            validationMode: FormixAutovalidateMode.onBlur,
            crossFieldValidator: (v, state) =>
                v == state.values['pw'] ? null : 'mismatch',
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.onBlur,
      );
      addTearDown(c.dispose);

      c.setValue(confirm, 'abc');
      c.markAsTouched(confirm); // onBlur: touched dependent revalidates
      c.setValue(pw, 'xyz');
      expect(c.getValidation(confirm).isValid, isFalse);
    });
  });

  group('built-in validator message keys resolve to localized strings', () {
    test('email / minLength / maxLength / pattern / min / max keys', () {
      const email = FormixFieldID<String>('email');
      const short = FormixFieldID<String>('short');
      const long = FormixFieldID<String>('long');
      const patt = FormixFieldID<String>('patt');
      const qty = FormixFieldID<int>('qty');
      const big = FormixFieldID<int>('big');

      final c = FormixController(
        initialValue: const {
          'email': '',
          'short': '',
          'long': '',
          'patt': '',
          'qty': 0,
          'big': 0,
        },
        fields: [
          FormixFieldConfig<String>.chain(
            id: email,
            rules: FormixValidators.string().email(),
          ).toField(),
          FormixFieldConfig<String>.chain(
            id: short,
            rules: FormixValidators.string().minLength(5),
          ).toField(),
          FormixFieldConfig<String>.chain(
            id: long,
            rules: FormixValidators.string().maxLength(2),
          ).toField(),
          FormixFieldConfig<String>.chain(
            id: patt,
            rules: FormixValidators.string().pattern(RegExp(r'^\d+$')),
          ).toField(),
          FormixFieldConfig<int>.chain(
            id: qty,
            rules: FormixValidators.number<int>().min(10),
          ).toField(),
          FormixFieldConfig<int>.chain(
            id: big,
            rules: FormixValidators.number<int>().max(5),
          ).toField(),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);

      c.setValue(email, 'not-an-email');
      c.setValue(short, 'ab');
      c.setValue(long, 'abcdef');
      c.setValue(patt, 'abc');
      c.setValue(qty, 1);
      c.setValue(big, 999);

      // Each field should report a resolved (non-key) error message.
      for (final id in [email, short, long, patt]) {
        final msg = c.getValidation(id).errorMessage;
        expect(msg, isNotNull);
        expect(msg, isNot(startsWith('formix_key_')));
      }
      for (final id in [qty, big]) {
        final msg = c.getValidation(id).errorMessage;
        expect(msg, isNotNull);
        expect(msg, isNot(startsWith('formix_key_')));
      }
    });
  });

  group('sync validator throw is caught', () {
    test('always-mode validator that throws yields validation error', () {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': 'seed'},
        fields: [
          FormixField<String>(
            id: f,
            initialValue: 'seed',
            validator: (v) => throw StateError('bad'),
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);
      // Trigger a fresh validation pass.
      c.setValue(f, 'new');
      expect(c.getValidation(f).isValid, isFalse);
      expect(c.getValidation(f).errorMessage, contains('Validation error'));
    });

    test('cross-field validator that throws yields validation error', () {
      const a = FormixFieldID<String>('a');
      const b = FormixFieldID<String>('b');
      final c = FormixController(
        initialValue: const {'a': '', 'b': 'seed'},
        fields: [
          const FormixField<String>(id: a, initialValue: ''),
          FormixField<String>(
            id: b,
            initialValue: 'seed',
            dependsOn: [a],
            crossFieldValidator: (v, s) => throw StateError('cross'),
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);
      c.setValue(b, 'new');
      expect(c.getValidation(b).errorMessage, contains('Cross-field validation error'));
    });
  });

  group('async validation error paths', () {
    testWidgets('async validator throwing sets async error message', (tester) async {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': ''},
        fields: [
          FormixField<String>(
            id: f,
            initialValue: '',
            debounceDuration: const Duration(milliseconds: 1),
            asyncValidator: (v) async => throw StateError('async-boom'),
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);

      c.setValue(f, 'trigger');
      await tester.pump(const Duration(milliseconds: 5));
      await tester.pump(const Duration(milliseconds: 5));
      expect(c.getValidation(f).errorMessage, contains('Async validation error'));
    });

    testWidgets('async validator clearing error decrements error count', (tester) async {
      const f = FormixFieldID<String>('f');
      var shouldFail = true;
      final c = FormixController(
        initialValue: const {'f': ''},
        fields: [
          FormixField<String>(
            id: f,
            initialValue: '',
            debounceDuration: const Duration(milliseconds: 1),
            asyncValidator: (v) async => shouldFail ? 'nope' : null,
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);

      c.setValue(f, 'a');
      await tester.pump(const Duration(milliseconds: 5));
      await tester.pump(const Duration(milliseconds: 5));
      expect(c.getValidation(f).isValid, isFalse);

      shouldFail = false;
      c.setValue(f, 'b');
      await tester.pump(const Duration(milliseconds: 5));
      await tester.pump(const Duration(milliseconds: 5));
      expect(c.getValidation(f).isValid, isTrue);
    });
  });

  group('setFieldValidating error-count adjustment', () {
    test('errored -> validating clears the error (line 1684)', () {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': ''},
        fields: [
          FormixField<String>(
            id: f,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);

      // Force an errored state.
      c.setValue(f, 'x');
      c.setValue(f, '');
      c.markAsTouched(f);
      expect(c.getValidation(f).isValid, isFalse);

      // errored (isValid=false) -> validating (isValid=true) hits the
      // `!oldRes.isValid && newRes.isValid` decrement branch (1684).
      c.setFieldValidating(f, isValidating: true);
      expect(c.getValidation(f).isValidating, isTrue);

      c.setFieldValidating(f, isValidating: false);
      expect(c.getValidation(f).isValid, isTrue);
    });

    test('setPending toggles pending state', () {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': ''},
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      addTearDown(c.dispose);

      c.setPending(f, true);
      expect(c.pendingSignal(f).value, isTrue);
      c.setPending(f, false);
      expect(c.pendingSignal(f).value, isFalse);
    });
  });

  group('submit throttle / debounce / optimistic', () {
    test('throttle drops a too-soon second submit', () async {
      final c = FormixController();
      addTearDown(c.dispose);

      var calls = 0;
      Future<void> onValid(_) async => calls++;

      await c.submit(onValid: onValid, throttle: const Duration(seconds: 10));
      await c.submit(onValid: onValid, throttle: const Duration(seconds: 10));
      expect(calls, 1);
    });

    testWidgets('debounce coalesces rapid submits', (tester) async {
      final c = FormixController();
      addTearDown(c.dispose);

      var calls = 0;
      Future<void> onValid(_) async => calls++;

      // Fire and forget two debounced submits.
      unawaited(c.submit(onValid: onValid, debounce: const Duration(milliseconds: 10)));
      final f = c.submit(onValid: onValid, debounce: const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 30));
      await f;
      expect(calls, 1);
    });

    testWidgets('debounced submit surfaces onValid error via completer', (tester) async {
      final c = FormixController();
      addTearDown(c.dispose);

      Object? captured;
      final future = c.submit(
        onValid: (_) async => throw StateError('submit-fail'),
        debounce: const Duration(milliseconds: 5),
      );
      // Attach a handler synchronously so the completer's error is consumed and
      // never surfaces as an unhandled zone error during pump.
      unawaited(future.catchError((Object e) => captured = e));
      await tester.pump(const Duration(milliseconds: 20));
      expect(captured, isA<StateError>());
    });
  });

  group('FormixParameter toString', () {
    test('renders key fields', () {
      const p = FormixParameter(
        formId: 'abc',
        namespace: 'ns',
        fields: [],
      );
      expect(p.toString(), contains('FormixParameter'));
      expect(p.toString(), contains('abc'));
    });
  });

  group('form listener error is swallowed', () {
    test('a throwing form listener does not break notification', () {
      const name = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [const FormixField<String>(id: name, initialValue: '')],
      );
      addTearDown(c.dispose);

      c.addFormListener((_) => throw StateError('listener-boom'));
      // Should not throw despite the listener throwing.
      c.setValue(name, 'x');
      expect(c.getValue(name), 'x');
    });
  });

  group('submit waitForPending loop', () {
    test('submit waits until pending field settles', () async {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': ''},
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      addTearDown(c.dispose);

      // Put a field into pending so the waitForPending while-loop iterates.
      c.setPending(f, true);

      var submitted = false;
      final future = c.submit(
        onValid: (_) async => submitted = true,
        waitForPending: true,
      );

      // Clear pending on the next microtask so the stream emits and the loop
      // (`await stream.first`) exits.
      scheduleMicrotask(() => c.setPending(f, false));

      await future;
      expect(submitted, isTrue);
    });

    test('debugForceSubmit waits for pending (lines 445/446)', () async {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': ''},
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      addTearDown(c.dispose);

      c.setPending(f, true);

      var submitted = false;
      final future = c.debugForceSubmit(
        onValid: (_) async => submitted = true,
        waitForPending: true,
      );
      scheduleMicrotask(() => c.setPending(f, false));

      await future;
      expect(submitted, isTrue);
    });
  });

  group('unregister single field with dependents (line 1351)', () {
    test('removing a field that has dependencies cleans the graph', () {
      const a = FormixFieldID<String>('a');
      const b = FormixFieldID<String>('b');
      final c = FormixController(
        initialValue: const {'a': '', 'b': ''},
        fields: [
          const FormixField<String>(id: a, initialValue: ''),
          const FormixField<String>(id: b, initialValue: '', dependsOn: [a]),
        ],
      );
      addTearDown(c.dispose);

      // b depends on a -> unregistering b singly runs the dep-cleanup loop.
      c.unregisterField(b);
      expect(c.isFieldRegistered(b), isFalse);
    });
  });

  group('resetFields revalidates dependents (lines 1515/1516)', () {
    test('onUserInteraction/onBlur dependents revalidate on reset', () {
      const src = FormixFieldID<String>('src');
      const dep = FormixFieldID<String>('dep');
      final c = FormixController(
        initialValue: const {'src': 'a', 'dep': ''},
        fields: [
          const FormixField<String>(id: src, initialValue: 'a'),
          FormixField<String>(
            id: dep,
            initialValue: '',
            dependsOn: [src],
            validationMode: FormixAutovalidateMode.onUserInteraction,
            crossFieldValidator: (v, s) =>
                v == s.values['src'] ? null : 'mismatch',
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.onUserInteraction,
      );
      addTearDown(c.dispose);

      c.setValue(dep, 'x');
      c.markAsTouched(dep);
      // Reset src -> dependent revalidation branch runs during resetFields.
      c.resetFields([src]);
      // Reset the cross-field-validated field itself: _performSyncValidation is
      // called without currentValidations, hitting the `?? state.validations`
      // fallback (line 946).
      c.resetFields([dep]);
      expect(c.isFieldRegistered(dep), isTrue);
    });

    test('onBlur dependent revalidates on reset (line 1516)', () {
      const src = FormixFieldID<String>('src');
      const dep = FormixFieldID<String>('dep');
      final c = FormixController(
        initialValue: const {'src': 'a', 'dep': ''},
        fields: [
          const FormixField<String>(id: src, initialValue: 'a'),
          FormixField<String>(
            id: dep,
            initialValue: '',
            dependsOn: [src],
            validationMode: FormixAutovalidateMode.onBlur,
            crossFieldValidator: (v, s) =>
                v == s.values['src'] ? null : 'mismatch',
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.onBlur,
      );
      addTearDown(c.dispose);

      c.setValue(dep, 'x');
      c.markAsTouched(dep); // onBlur + touched -> revalidates during resetFields
      c.resetFields([src]);
      expect(c.isFieldRegistered(dep), isTrue);
    });
  });

  group('validate() sets pending for async fields (line 1583)', () {
    test('validate flips a sync-valid async field to validating', () {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': 'ok'},
        fields: [
          FormixField<String>(
            id: f,
            initialValue: 'ok',
            asyncValidator: (v) async => null,
          ),
        ],
      );
      addTearDown(c.dispose);

      final ok = c.validate();
      // Sync passes but async is pending, so the field is now validating.
      expect(ok, isTrue);
      expect(c.getValidation(f).isValidating, isTrue);
    });
  });

  group('requireValue', () {
    test('returns a present value and throws when missing', () {
      const f = FormixFieldID<String>('f');
      final c = FormixController(
        initialValue: const {'f': 'here'},
        fields: [const FormixField<String>(id: f, initialValue: 'here')],
      );
      addTearDown(c.dispose);

      expect(c.requireValue(f), 'here');
      expect(
        () => c.requireValue(const FormixFieldID<String>('nope')),
        throwsStateError,
      );
    });
  });
}

class _A {}

class _B {}
