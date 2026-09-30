// Compile-check for README code snippets. Not a runnable test (no `_test`
// suffix) — `dart analyze` type-checks it against the real API so the docs
// can't drift. ignore unused: snippets are illustrative fragments.
// ignore_for_file: unused_local_variable, unused_element

// Only the formix import — proves README snippets are self-contained
// (SignalBuilder etc. come through formix's re-export).
import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

const emailId = FormixFieldID<String>('email');
const nameId = FormixFieldID<String>('name');
const ageId = FormixFieldID<int>('age');
const passwordId = FormixFieldID<String>('password');

enum Role { admin, user }

class _Api {
  Future<void> save(Map<String, dynamic> values) async {}
}

final _api = _Api();

// --- Fluent API (README "Fluent API" section) ---
final _vNum = FormixValidators.number<int>().required().positive().min(18, 'Must be an adult').max(99).between(1, 100).build();

final _vDate = FormixValidators.date().after(DateTime(2000)).before(DateTime.now()).between(DateTime(2000), DateTime.now()).build();

final _vRole = FormixValidators.any<Role>().oneOf([Role.admin, Role.user]).build();

// --- Owned-controller pattern: no InheritedWidget, signals-native access ---
// You hold the controller (it's just a bag of signals), read its signals
// directly, and pass it explicitly — so seeding in initState works and never
// throws. No `Formix` ancestor, no `context.formix`, no timing rules.
class _OwnedForm extends StatefulWidget {
  const _OwnedForm();
  @override
  State<_OwnedForm> createState() => _OwnedFormState();
}

class _OwnedFormState extends State<_OwnedForm> {
  late final FormixController form = FormixController(
    fields: const [
      FormixFieldConfig<String>(id: emailId),
      FormixFieldConfig<int>(id: ageId),
    ],
    initialValue: const {'email': ''}, // declarative seed
  );

  @override
  void initState() {
    super.initState();
    // Imperative seed is safe here — you own `form`, no InheritedWidget involved.
    form.batchUpdate((b) => b..set(ageId, 18));
  }

  @override
  void dispose() {
    form.dispose(); // you own it → you dispose it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fields take the controller explicitly — no Formix ancestor needed.
        FormixTextFormField(fieldId: emailId, controller: form),
        FormixValue<int>(ageId, controller: form, builder: (context, age) => Text('${age ?? 0}')),
        // Read any signal directly — the signals way, zero context lookup.
        SignalBuilder(builder: (context) => Text(form.isValidSignal.value ? 'Ready' : 'Fill it in')),
        FormixSubmitButton(controller: form, onValid: (v) => _api.save(v), child: const Text('Save')),
      ],
    );
  }
}

// --- Ergonomic shortcuts + Submission state (README snippets) ---
// NOTE: reads (valueSignal/group2/subscript-get) belong in build()/SignalBuilder;
// WRITES (subscript-set, batchUpdate, setGroup2) belong in lifecycle/handlers —
// never in build(), which reruns on every rebuild.
class _SnippetWidget extends StatefulWidget {
  const _SnippetWidget();

  @override
  State<_SnippetWidget> createState() => _SnippetWidgetState();
}

class _SnippetWidgetState extends State<_SnippetWidget> {
  // WRITES go in event handlers / async callbacks — never build(), and not
  // initState() either (it can't read the Formix InheritedWidget yet).
  // For one-time seeding, prefer `Formix(initialValue: {...})`.
  void _onPrefill() {
    final c = context.formix;
    c[nameId] = 'Ada'; // subscript write
    c.batchUpdate(
      (b) => b
        ..set(nameId, 'Ada')
        ..set(ageId, 36),
    );
    c.setGroup2(emailId, passwordId, ('a@b.c', 'secret'));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.formix;
    final name = controller[nameId]; // subscript read — fine in build

    return Column(
      children: [
        TextButton(onPressed: _onPrefill, child: const Text('Prefill')),

        // React to ONE field.
        FormixValue<String>(emailId, builder: (context, value) => Text(value ?? '')),

        // Auto-disabling submit button.
        FormixSubmitButton(
          onValid: (values) => _api.save(values),
          child: const Text('Save'),
        ),

        // Read several typed fields as one destructurable record.
        SignalBuilder(
          builder: (context) {
            final (email, password) = controller.group2(emailId, passwordId).value;
            return Text('$email / $password');
          },
        ),

        // Sealed submission state, exhaustively switched.
        SignalBuilder(
          builder: (context) {
            return switch (controller.submissionSignal.value) {
              FormixSubmissionIdle() => const Text('Ready'),
              FormixSubmissionSubmitting() => const CircularProgressIndicator(),
              FormixSubmissionSuccess() => const Text('Saved!'),
              FormixSubmissionError(:final error) => Text('Failed: $error'),
            };
          },
        ),
      ],
    );
  }
}
