import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// Fake persistence that returns a canned saved-state map so the load path in
/// [_loadPersistedState] is exercised.
class _FakePersistence implements FormixPersistence {
  _FakePersistence(this.saved);

  final Map<String, dynamic>? saved;
  final List<Map<String, dynamic>> writes = [];
  bool cleared = false;

  @override
  Future<Map<String, dynamic>?> getSavedState(String formId) async => saved;

  @override
  Future<void> saveFormState(String formId, Map<String, dynamic> values) async {
    writes.add(Map<String, dynamic>.from(values));
  }

  @override
  Future<void> clearSavedState(String formId) async {
    cleared = true;
  }
}

FormixController _make({
  Map<String, dynamic> initialValue = const {},
  List<FormixFieldDefinition> fields = const [],
  FormixAutovalidateMode mode = FormixAutovalidateMode.always,
  FormixPersistence? persistence,
  String? formId,
}) {
  return FormixController(
    initialValue: initialValue,
    fields: fields,
    autovalidateMode: mode,
    persistence: persistence,
    formId: formId,
  );
}

void main() {
  // ---- Undo / Redo ----
  group('undo / redo', () {
    const name = FormixFieldID<String>('name');

    test('records history, undo/redo walk the stack, canUndo/canRedo gate', () {
      final c = _make(
        initialValue: {'name': ''},
        fields: [const FormixField<String>(id: name, initialValue: '')],
      );
      addTearDown(c.dispose);

      expect(c.canUndo, isFalse);
      expect(c.canRedo, isFalse);

      c.setValue(name, 'a');
      c.setValue(name, 'ab');
      c.setValue(name, 'abc');

      expect(c.canUndo, isTrue);
      expect(c.canRedo, isFalse);

      c.undo();
      expect(c.getValue(name), 'ab');
      expect(c.canRedo, isTrue);

      c.undo();
      expect(c.getValue(name), 'a');

      c.redo();
      expect(c.getValue(name), 'ab');

      // undo/redo are no-ops when they cannot proceed
      c.undo();
      c.undo();
      expect(c.getValue(name), ''); // back to initial
      expect(c.canUndo, isFalse);
      c.undo(); // no-op, must not throw or move index
      expect(c.getValue(name), '');
    });

    test('history is capped at 50 entries', () {
      final c = _make(
        initialValue: {'name': ''},
        fields: [const FormixField<String>(id: name, initialValue: '')],
      );
      addTearDown(c.dispose);

      // Push far past the 50-entry cap.
      for (var i = 0; i < 80; i++) {
        c.setValue(name, 'v$i');
      }
      // We can only undo up to the retained window (< 50 steps).
      var undos = 0;
      while (c.canUndo && undos < 200) {
        c.undo();
        undos++;
      }
      expect(undos, lessThanOrEqualTo(50));
      expect(undos, greaterThan(0));
    });
  });

  // ---- Optimistic update ----
  group('optimisticUpdate', () {
    const email = FormixFieldID<String>('email');

    test('success keeps the new value and clears pending', () async {
      final c = _make(
        initialValue: {'email': 'old'},
        fields: [const FormixField<String>(id: email, initialValue: 'old')],
      );
      addTearDown(c.dispose);

      await c.optimisticUpdate<String>(
        fieldId: email,
        value: 'new',
        action: () async {},
      );

      expect(c.getValue(email), 'new');
      expect(c.state.pendingStates['email'] ?? false, isFalse);
    });

    test('revertOnError restores the previous value on failure', () async {
      final c = _make(
        initialValue: {'email': 'old'},
        fields: [const FormixField<String>(id: email, initialValue: 'old')],
      );
      addTearDown(c.dispose);

      await expectLater(
        c.optimisticUpdate<String>(
          fieldId: email,
          value: 'new',
          action: () async => throw Exception('boom'),
        ),
        throwsException,
      );
      expect(c.getValue(email), 'old');
      expect(c.state.pendingStates['email'] ?? false, isFalse);
    });

    test('revertOnError=false keeps optimistic value after failure', () async {
      final c = _make(
        initialValue: {'email': 'old'},
        fields: [const FormixField<String>(id: email, initialValue: 'old')],
      );
      addTearDown(c.dispose);

      await expectLater(
        c.optimisticUpdate<String>(
          fieldId: email,
          value: 'new',
          action: () async => throw Exception('boom'),
          revertOnError: false,
        ),
        throwsException,
      );
      expect(c.getValue(email), 'new');
    });
  });

  // ---- bindField ----
  group('bindField', () {
    const src = FormixFieldID<String>('a');
    const dst = FormixFieldID<String>('b');

    test('one-way binding propagates source -> target', () async {
      final source = _make(
        initialValue: {'a': ''},
        fields: [const FormixField<String>(id: src, initialValue: '')],
      );
      final target = _make(
        initialValue: {'b': ''},
        fields: [const FormixField<String>(id: dst, initialValue: '')],
      );
      addTearDown(source.dispose);
      addTearDown(target.dispose);

      final unbind = target.bindField<String>(
        dst,
        sourceController: source,
        sourceField: src,
      );

      source.setValue(src, 'hello');
      await Future<void>.delayed(Duration.zero);
      expect(target.getValue(dst), 'hello');

      unbind();
      source.setValue(src, 'world');
      await Future<void>.delayed(Duration.zero);
      expect(target.getValue(dst), 'hello'); // no longer bound
    });

    test('twoWay binding propagates target -> source and unbinds both', () async {
      final source = _make(
        initialValue: {'a': ''},
        fields: [const FormixField<String>(id: src, initialValue: '')],
      );
      final target = _make(
        initialValue: {'b': ''},
        fields: [const FormixField<String>(id: dst, initialValue: '')],
      );
      addTearDown(source.dispose);
      addTearDown(target.dispose);

      final unbind = target.bindField<String>(
        dst,
        sourceController: source,
        sourceField: src,
        twoWay: true,
      );

      target.setValue(dst, 'fromTarget');
      await Future<void>.delayed(Duration.zero);
      expect(source.getValue(src), 'fromTarget');

      unbind();
      target.setValue(dst, 'again');
      await Future<void>.delayed(Duration.zero);
      expect(source.getValue(src), 'fromTarget');
    });
  });

  // ---- debug helpers ----
  group('debug helpers', () {
    test('debugFillDummyData fills per initial type', () {
      const s = FormixFieldID<String>('s');
      const i = FormixFieldID<int>('i');
      const d = FormixFieldID<double>('d');
      const b = FormixFieldID<bool>('b');
      const dt = FormixFieldID<DateTime>('dt');
      final c = _make(
        fields: [
          const FormixField<String>(id: s, initialValue: ''),
          const FormixField<int>(id: i, initialValue: 0),
          const FormixField<double>(id: d, initialValue: 0.0),
          const FormixField<bool>(id: b, initialValue: false),
          FormixField<DateTime>(id: dt, initialValue: DateTime(2020)),
        ],
      );
      addTearDown(c.dispose);

      c.debugFillDummyData();
      expect(c.getValue(s), 'Sample Text');
      expect(c.getValue(i), 42);
      expect(c.getValue(d), 3.14);
      expect(c.getValue(b), isTrue);
      expect(c.getValue(dt), isA<DateTime>());
    });

    test('debugForceSubmit bypasses validation and toggles isSubmitting', () async {
      const name = FormixFieldID<String>('name');
      final c = _make(
        fields: [
          FormixField<String>(
            id: name,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.validate(), isFalse); // would normally block submit

      Map<String, dynamic>? received;
      await c.debugForceSubmit(
        onValid: (values) async {
          received = values;
        },
      );
      expect(received, isNotNull);
      expect(c.isSubmitting, isFalse);
    });
  });

  // ---- manual state setters ----
  group('manual setters', () {
    const f = FormixFieldID<String>('f');

    test('setFieldError sets and clears a manual error and error count', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      addTearDown(c.dispose);

      c.setFieldError(f, 'backend error');
      expect(c.getValidation(f).isValid, isFalse);
      expect(c.getValidation(f).errorMessage, 'backend error');
      expect(c.state.errorCount, 1);

      c.setFieldError(f, null);
      expect(c.getValidation(f).isValid, isTrue);
      expect(c.state.errorCount, 0);
    });

    test('setFieldValidating toggles validating & pending count', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      addTearDown(c.dispose);

      c.setFieldValidating(f);
      expect(c.getValidation(f).isValidating, isTrue);
      expect(c.state.pendingCount, 1);

      c.setFieldValidating(f, isValidating: false);
      expect(c.getValidation(f).isValidating, isFalse);
      expect(c.state.pendingCount, 0);
    });

    test('setPending increments and decrements the pending count', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      addTearDown(c.dispose);

      c.setPending(f, true);
      expect(c.state.pendingCount, 1);
      c.setPending(f, true); // no double-count
      expect(c.state.pendingCount, 1);
      c.setPending(f, false);
      expect(c.state.pendingCount, 0);
    });

    test('markAsTouched marks a registered field and is a no-op otherwise', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      addTearDown(c.dispose);

      c.markAsTouched(f);
      expect(c.isFieldTouched(f), isTrue);
      // second call is a no-op (already touched) -> exercises early return
      c.markAsTouched(f);
      expect(c.isFieldTouched(f), isTrue);
      // unregistered field is ignored
      c.markAsTouched(const FormixFieldID<String>('ghost'));
    });

    test('manual setters are no-ops after dispose', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: '')],
      );
      c.dispose();
      expect(c.mounted, isFalse);
      // These early-return on !mounted
      c.setFieldError(f, 'x');
      c.setFieldValidating(f);
      c.setPending(f, true);
    });
  });

  // ---- requireValue ----
  group('requireValue', () {
    const f = FormixFieldID<String>('f');

    test('returns the value when present, throws StateError when null', () {
      final c = _make(
        fields: [
          const FormixField<String>(id: f, initialValue: 'here'),
        ],
      );
      addTearDown(c.dispose);
      expect(c.requireValue(f), 'here');

      const nf = FormixFieldID<String>('nf');
      final c2 = _make(fields: [const FormixField<String>(id: nf, initialValue: null)]);
      addTearDown(c2.dispose);
      expect(() => c2.requireValue(nf), throwsStateError);
    });
  });

  // ---- reset variants ----
  group('reset variants', () {
    const f = FormixFieldID<String>('f');
    const g = FormixFieldID<String>('g');

    test('resetToValues sets new initial values and clears dirty', () {
      final c = _make(
        initialValue: {'f': 'a'},
        fields: [const FormixField<String>(id: f, initialValue: 'a')],
      );
      addTearDown(c.dispose);
      c.setValue(f, 'changed');
      expect(c.isFieldDirty(f), isTrue);

      c.resetToValues({'f': 'newInitial'});
      expect(c.getValue(f), 'newInitial');
      expect(c.isFieldDirty(f), isFalse);
    });

    test('resetFields with clearErrors removes validations', () {
      final c = _make(
        fields: [
          FormixField<String>(
            id: f,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'req' : null,
          ),
        ],
      );
      addTearDown(c.dispose);
      c.validate();
      expect(c.getValidation(f).isValid, isFalse);

      c.resetFields([f], clearErrors: true);
      expect(c.state.validations.containsKey('f'), isFalse);
    });

    test('resetFields with clear strategy uses empty default', () {
      final c = _make(
        fields: [
          const FormixField<String>(id: f, initialValue: 'x'),
        ],
      );
      addTearDown(c.dispose);
      c.setValue(f, 'y');
      c.resetFields([f], strategy: ResetStrategy.clear);
      expect(c.getValue(f), ''); // default empty for String
    });

    test('resetFields re-validates dependents', () {
      final c = _make(
        fields: [
          const FormixField<String>(id: f, initialValue: 'a'),
          FormixField<String>(
            id: g,
            initialValue: 'b',
            dependsOn: [f],
            crossFieldValidator: (v, state) => state.getValue(f) == 'a' ? null : 'f must be a',
          ),
        ],
      );
      addTearDown(c.dispose);
      c.setValue(f, 'z');
      expect(c.getValidation(g).isValid, isFalse);
      c.resetFields([f]);
      expect(c.getValidation(g).isValid, isTrue);
    });

    test('reset with clear strategy on whole form', () {
      final c = _make(
        fields: [
          const FormixField<int>(id: FormixFieldID<int>('n'), initialValue: 5),
        ],
      );
      addTearDown(c.dispose);
      c.reset(strategy: ResetStrategy.clear);
      expect(c.getValue(const FormixFieldID<int>('n')), 0);
    });
  });

  // ---- unregister ----
  group('unregister', () {
    const f = FormixFieldID<String>('f');
    const g = FormixFieldID<String>('g');

    test('unregisterField removes state unless preserveState', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: 'a')],
      );
      addTearDown(c.dispose);
      c.setValue(f, 'b');

      c.unregisterField(f);
      expect(c.isFieldRegistered(f), isFalse);
      expect(c.state.values.containsKey('f'), isFalse);
    });

    test('unregisterField preserveState keeps the value', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: 'a')],
      );
      addTearDown(c.dispose);
      c.setValue(f, 'b');

      c.unregisterField(f, preserveState: true);
      expect(c.isFieldRegistered(f), isFalse);
      expect(c.state.values['f'], 'b');
    });

    test('unregisterFields (bulk) with dependents cleans the graph', () {
      final c = _make(
        fields: [
          const FormixField<String>(id: f, initialValue: 'a'),
          const FormixField<String>(id: g, initialValue: 'b', dependsOn: [f]),
        ],
      );
      addTearDown(c.dispose);
      c.unregisterFields([f, g]);
      expect(c.isFieldRegistered(f), isFalse);
      expect(c.isFieldRegistered(g), isFalse);
    });

    test('unregisterFields with empty list is a no-op', () {
      final c = _make(
        fields: [const FormixField<String>(id: f, initialValue: 'a')],
      );
      addTearDown(c.dispose);
      c.unregisterFields([]);
      expect(c.isFieldRegistered(f), isTrue);
    });
  });

  // ---- array ops ----
  group('array ops', () {
    const list = FormixArrayID<String>('items');

    FormixController arrayController() {
      final c = _make(
        initialValue: {'items': <String>[]},
        fields: [
          const FormixField<List<String>>(
            id: list,
            initialValue: <String>[],
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('add / remove / replace / move / clear', () {
      final c = arrayController();

      c.addArrayItem(list, 'a');
      c.addArrayItem(list, 'b');
      c.addArrayItem(list, 'c');
      expect(c.getValue(list), ['a', 'b', 'c']);

      c.replaceArrayItem(list, 1, 'B');
      expect(c.getValue(list), ['a', 'B', 'c']);

      c.moveArrayItem(list, 0, 2);
      expect(c.getValue(list), ['B', 'c', 'a']);

      c.removeArrayItemAt(list, 1);
      expect(c.getValue(list), ['B', 'a']);

      c.clearArray(list);
      expect(c.getValue(list), <String>[]);
    });

    test('out-of-range ops are ignored', () {
      final c = arrayController();
      c.addArrayItem(list, 'a');
      c.removeArrayItemAt(list, 5); // ignored
      c.replaceArrayItem(list, -1, 'x'); // ignored
      c.moveArrayItem(list, 0, 9); // ignored
      expect(c.getValue(list), ['a']);
    });
  });

  // ---- updateFromMap / getChangedValues ----
  group('updateFromMap / getChangedValues', () {
    const a = FormixFieldID<String>('a');
    const b = FormixFieldID<String>('b');

    test('updateFromMap only touches registered fields', () {
      final c = _make(
        fields: [
          const FormixField<String>(id: a, initialValue: ''),
          const FormixField<String>(id: b, initialValue: ''),
        ],
      );
      addTearDown(c.dispose);

      final result = c.updateFromMap({'a': 'x', 'b': 'y', 'ghost': 'z'});
      expect(result.updatedFields, containsAll(['a', 'b']));
      expect(c.getValue(a), 'x');
      expect(c.getValue(b), 'y');
    });

    test('getChangedValues returns only dirty fields', () {
      final c = _make(
        fields: [
          const FormixField<String>(id: a, initialValue: 'a0'),
          const FormixField<String>(id: b, initialValue: 'b0'),
        ],
      );
      addTearDown(c.dispose);
      c.setValue(a, 'a1');
      final changed = c.getChangedValues();
      expect(changed, {'a': 'a1'});
    });
  });

  // ---- submit throttle/debounce/optimistic ----
  group('submit', () {
    const f = FormixFieldID<String>('f');

    FormixController valid() {
      final c = _make(
        fields: [
          FormixField<String>(
            id: f,
            initialValue: 'ok',
            validator: (v) => (v == null || v.isEmpty) ? 'req' : null,
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('onError is called on invalid submit', () async {
      final c = _make(
        fields: [
          FormixField<String>(
            id: f,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'req' : null,
          ),
        ],
      );
      addTearDown(c.dispose);

      Map<String, ValidationResult>? errors;
      await c.submit(
        onValid: (_) async {},
        onError: (e) => errors = e,
      );
      expect(errors, isNotNull);
      expect(errors!['f']!.isValid, isFalse);
    });

    test('throttle drops the second call inside the window', () async {
      final c = valid();
      var calls = 0;
      await c.submit(
        onValid: (_) async => calls++,
        throttle: const Duration(seconds: 1),
      );
      await c.submit(
        onValid: (_) async => calls++,
        throttle: const Duration(seconds: 1),
      );
      expect(calls, 1);
    });

    test('debounce coalesces to a single submit', () async {
      final c = valid();
      var calls = 0;
      // First call is cancelled by the second (its future is intentionally
      // orphaned by the package's debounce implementation); only await the last.
      unawaited(
        c.submit(
          onValid: (_) async => calls++,
          debounce: const Duration(milliseconds: 30),
        ),
      );
      await c.submit(
        onValid: (_) async => calls++,
        debounce: const Duration(milliseconds: 30),
      );
      expect(calls, 1);
    });

    test('optimistic submit clears dirty then succeeds', () async {
      final c = valid();
      c.setValue(f, 'changed');
      expect(c.isDirty, isTrue);
      await c.submit(onValid: (_) async {}, optimistic: true);
      expect(c.isDirty, isFalse);
    });

    test('optimistic submit reverts on error', () async {
      final c = valid();
      c.setValue(f, 'changed');
      await expectLater(
        c.submit(
          onValid: (_) async => throw Exception('server down'),
          optimistic: true,
        ),
        throwsException,
      );
      // reverted to dirty state (value preserved, initial restored)
      expect(c.getValue(f), 'changed');
      expect(c.isDirty, isTrue);
    });
  });

  // ---- validation modes ----
  group('validation modes', () {
    const f = FormixFieldID<String>('f');

    FormixField<String> reqField(FormixAutovalidateMode mode) => FormixField<String>(
      id: f,
      initialValue: '',
      validationMode: mode,
      validator: (v) => (v == null || v.isEmpty) ? 'req' : null,
    );

    test('disabled mode does not auto-validate on change', () {
      final c = _make(fields: [reqField(FormixAutovalidateMode.disabled)]);
      addTearDown(c.dispose);
      c.setValue(f, '');
      expect(c.getValidation(f).isValid, isTrue); // not validated
      expect(c.validate(), isFalse); // manual validate works
    });

    test('onUserInteraction validates only after change', () {
      final c = _make(fields: [reqField(FormixAutovalidateMode.onUserInteraction)]);
      addTearDown(c.dispose);
      c.setValue(f, 'x');
      c.setValue(f, '');
      expect(c.getValidation(f).isValid, isFalse);
    });

    test('onBlur validates after markAsTouched', () {
      final c = _make(fields: [reqField(FormixAutovalidateMode.onBlur)]);
      addTearDown(c.dispose);
      c.markAsTouched(f);
      c.setValue(f, '');
      expect(c.getValidation(f).isValid, isFalse);
    });

    test('getValidationMode resolves auto to the form default', () {
      final c = _make(
        mode: FormixAutovalidateMode.onBlur,
        fields: [reqField(FormixAutovalidateMode.auto)],
      );
      addTearDown(c.dispose);
      expect(c.getValidationMode(f), FormixAutovalidateMode.onBlur);
    });

    test('getValidationMode returns explicit field mode', () {
      final c = _make(fields: [reqField(FormixAutovalidateMode.always)]);
      addTearDown(c.dispose);
      expect(c.getValidationMode(f), FormixAutovalidateMode.always);
    });
  });

  // ---- multi-step ----
  group('multi-step navigation', () {
    const step1 = FormixFieldID<String>('s1');

    test('goToStep / nextStep / previousStep / validateStep', () {
      final c = _make(
        fields: [
          FormixField<String>(
            id: step1,
            initialValue: 'ok',
            validator: (v) => (v == null || v.isEmpty) ? 'req' : null,
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(c.state.currentStep, 0);
      expect(c.nextStep(fields: [step1]), isTrue);
      expect(c.state.currentStep, 1);

      c.previousStep();
      expect(c.state.currentStep, 0);

      c.goToStep(3);
      expect(c.state.currentStep, 3);

      c.previousStep(targetStep: 0);
      expect(c.state.currentStep, 0);

      expect(c.validateStep([step1]), isTrue);
    });

    test('nextStep returns false and stays when invalid', () {
      final c = _make(
        fields: [
          FormixField<String>(
            id: step1,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'req' : null,
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.nextStep(fields: [step1]), isFalse);
      expect(c.state.currentStep, 0);
    });
  });

  // ---- persistence load path ----
  group('persistence load', () {
    const f = FormixFieldID<String>('f');
    const ghost = 'ghost';

    test('loads saved state and marks fields dirty vs initial', () async {
      final persistence = _FakePersistence({'f': 'loaded', ghost: 'extra'});
      final c = FormixController.fromParameter(
        FormixParameter(
          formId: 'form1',
          initialValue: const {'f': 'initial'},
          persistence: persistence,
          fields: [
            const FormixField<String>(id: f, initialValue: 'initial').toConfig(),
          ],
        ),
      );
      addTearDown(c.dispose);

      // _loadPersistedState runs in a microtask.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.getValue(f), 'loaded');
      expect(c.isFieldDirty(f), isTrue);
      // unknown key gets stored with dirty=true
      expect(c.state.values[ghost], 'extra');
    });

    test('null saved state leaves initial values untouched', () async {
      final persistence = _FakePersistence(null);
      final c = FormixController.fromParameter(
        FormixParameter(
          formId: 'form2',
          initialValue: const {'f': 'initial'},
          persistence: persistence,
          fields: [
            const FormixField<String>(id: f, initialValue: 'initial').toConfig(),
          ],
        ),
      );
      addTearDown(c.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.getValue(f), 'initial');
    });
  });

  // ---- updateMessages ----
  group('updateMessages', () {
    test('re-validates and updates error strings; global signal drives it', () {
      const f = FormixFieldID<String>('f');
      final c = _make(
        fields: [
          FormixField<String>(
            id: f,
            initialValue: '',
            validator: FormixValidators.string().required().build(),
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(() => formixGlobalMessages.value = const DefaultFormixMessages());

      c.validate();
      final before = c.getValidation(f).errorMessage;

      // Same instance short-circuits (no-op branch).
      c.updateMessages(c.messages);

      // A different messages instance triggers re-validation.
      c.updateMessages(const _CustomMessages());
      final after = c.getValidation(f).errorMessage;
      expect(after, isNot(before));
      expect(after, contains('CUSTOM'));
    });
  });
}

class _CustomMessages extends DefaultFormixMessages {
  const _CustomMessages();
  @override
  String required(String field) => 'CUSTOM required: $field';
}
