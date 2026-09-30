import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
import 'package:formix/src/widgets/formix_controller_host.dart';

/// A runtime (non-const) analytics subclass so the abstract base constructor
/// (`const FormixAnalytics()`) is exercised through a real subclass instance.
class _CountingAnalytics extends FormixAnalytics {
  _CountingAnalytics();

  int started = 0;
  int changed = 0;
  int touched = 0;
  int submitAttempts = 0;
  int successes = 0;
  int failures = 0;
  int abandoned = 0;

  @override
  void onFormStarted(String? formId) => started++;
  @override
  void onFieldChanged(String? formId, String key, dynamic v) => changed++;
  @override
  void onFieldTouched(String? formId, String key) => touched++;
  @override
  void onSubmitAttempt(String? formId, Map<String, dynamic> values) => submitAttempts++;
  @override
  void onSubmitSuccess(String? formId) => successes++;
  @override
  void onSubmitFailure(String? formId, Map<String, dynamic> errors) => failures++;
  @override
  void onFormAbandoned(String? formId, Duration d) => abandoned++;
}

void main() {
  group('small unit getters / branches', () {
    test('FormixBatch.length and FormixBatchUpdate.to', () {
      const id = FormixFieldID<int>('n');
      final batch = FormixBatch();
      batch.setValue(id).to(5);
      expect(batch.length, 1);
      expect(batch.updates[id], 5);
    });

    test('FormixFieldConfig.chain builds validators (line 48)', () {
      const id = FormixFieldID<String>('email');
      final config = FormixFieldConfig<String>.chain(
        id: id,
        rules: FormixValidators.string().required().minLength(3),
      );
      // Exercise the generated sync validator closure.
      expect(config.validator!(''), isNotNull);
      expect(config.validator!('abcd'), isNull);
    });

    test('InMemoryFormPersistence.toString (lines 52/53)', () async {
      final p = InMemoryFormPersistence();
      await p.saveFormState('f1', {'a': 1});
      expect(p.toString(), contains('InMemoryFormPersistence'));
      expect(p.toString(), contains('f1'));
    });

    test('FormixThemeData hashCode / equality (lines 32/33)', () {
      const a = FormixThemeData(enabled: true);
      const b = FormixThemeData(enabled: true);
      expect(a.hashCode, b.hashCode);
      expect(a, b);
    });

    test('LoggingFormAnalytics const constructor (line 9)', () {
      const analytics = LoggingFormAnalytics(prefix: 'X', enabled: false);
      expect(analytics.prefix, 'X');
      expect(analytics.toString(), contains('LoggingFormAnalytics'));
    });
  });

  group('FormixLocalizations', () {
    testWidgets('delegate load + of() resolve non-english locale', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: [FormixLocalizations.delegate],
        supportedLocales: [Locale('es'), Locale('en')],
        home: _LocaleProbe(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(_LocaleProbe), findsOneWidget);
    });

    test('forLocale exact country-code match (line 157)', () {
      FormixLocalizations.registerLocale(
        'en_US',
        () => const DefaultFormixMessages(),
      );
      addTearDown(() => FormixLocalizations.unregisterLocale('en_US'));
      final m = FormixLocalizations.forLocale(const Locale('en', 'US'));
      expect(m, isA<FormixMessages>());
    });

    testWidgets('updateShouldNotify true when messages differ (212/214)', (tester) async {
      const delegate = FormixLocalizations.delegate;
      final loc1 = await delegate.load(const Locale('en'));
      final loc2 = await delegate.load(const Locale('es'));
      expect(loc1.updateShouldNotify(loc2), isTrue);
      expect(loc1.updateShouldNotify(loc1), isFalse);
      expect(delegate.isSupported(const Locale('xx')), isTrue);
      expect(delegate.shouldReload(delegate as dynamic), isFalse);
    });
  });

  group('FormixControllerHost mixin', () {
    testWidgets('detach + reattach fires host lifecycle hooks', (tester) async {
      final c1 = FormixController();
      final c2 = FormixController();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(MaterialApp(
        home: _HostWidget(key: key, controller: c1),
      ));
      await tester.pump();
      expect(key.currentState!.attached, contains(c1));

      // Swap the controller -> onControllerDetached(c1) + onControllerChanged(c2).
      await tester.pumpWidget(MaterialApp(
        home: _HostWidget(key: key, controller: c2),
      ));
      await tester.pump();
      key.currentState!.refresh();
      expect(key.currentState!.detached, contains(c1));
      expect(key.currentState!.attached, contains(c2));
      expect(key.currentState!.controllerOrNull, c2);
      expect(key.currentState!.hasController, isTrue);
      expect(key.currentState!.controller, c2);
    });

    testWidgets('no controller -> formixErrorOrNull returns error widget', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _HostWidget()));
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('FormixScope step / pending wrappers', () {
    testWidgets('watchCurrentStep, isFieldPending, step navigation, validateStep', (tester) async {
      const a = FormixFieldID<String>('a');
      final c = FormixController(
        initialValue: const {'a': 'ok'},
        fields: [const FormixField<String>(id: a, initialValue: 'ok')],
      );
      addTearDown(c.dispose);

      late FormixScope captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Formix(
            controller: c,
            child: FormixBuilder(
              builder: (context, scope) {
                captured = scope;
                return Text('step ${scope.watchCurrentStep}');
              },
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(captured.isFieldPending(a), isFalse);
      captured.goToStep(1);
      await tester.pump();
      expect(c.currentStepSignal.value, 1);
      expect(captured.validateStep([a]), isTrue);
      captured.previousStep();
      await tester.pump();
      final moved = captured.nextStep(fields: [a]);
      expect(moved, isTrue);
    });
  });

  group('form schema submit failure path', () {
    test('submitForm catches thrown submit error (lines 649/650)', () async {
      final schema = FormSchema(
        fields: [
          const TextFieldSchema(
            id: FormixFieldID<String>('name'),
            initialValue: 'x',
          ),
        ],
        onSubmit: (values) async => throw StateError('boom'),
      );
      final controller = SchemaBasedFormController(schema: schema);
      addTearDown(controller.dispose);

      final result = await controller.submitForm();
      expect(result.success, isFalse);
    });
  });

  group('analytics driven through controller', () {
    testWidgets('runtime analytics subclass receives events', (tester) async {
      final analytics = _CountingAnalytics();
      const name = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [const FormixField<String>(id: name, initialValue: '')],
        analytics: analytics,
        formId: 'form-a',
      );
      addTearDown(c.dispose);

      c.setValue(name, 'John');
      c.markAsTouched(name);
      await c.submit(onValid: (_) async {});

      expect(analytics.changed, greaterThan(0));
      expect(analytics.submitAttempts, greaterThan(0));
    });
  });

  group('formix errors widget documentation button', () {
    testWidgets('tapping the docs button runs its callback (line 83)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FormixConfigurationErrorWidget(
            message: 'msg',
            details: 'details',
          ),
        ),
      ));
      await tester.tap(find.text('View Documentation'));
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('FormixFormStatus renders submitting branch (form_status:60)', () {
    testWidgets('shows Submitting... when form is submitting', (tester) async {
      final c = FormixController();
      addTearDown(c.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Formix(
            controller: c,
            child: const FormixFormStatus(),
          ),
        ),
      ));
      await tester.pump();

      // Trigger submitting state while onValid is in flight.
      final future = c.submit(
        onValid: (_) => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.text('Submitting...'), findsOneWidget);
      await future;
      await tester.pump();
    });
  });
}

class _LocaleProbe extends StatelessWidget {
  const _LocaleProbe();
  @override
  Widget build(BuildContext context) {
    final messages = FormixLocalizations.of(context);
    return Text(messages.required('Field'), textDirection: TextDirection.ltr);
  }
}

class _HostWidget extends StatefulWidget {
  const _HostWidget({super.key, this.controller});
  final FormixController? controller;
  @override
  State<_HostWidget> createState() => _HostState();
}

class _HostState extends State<_HostWidget> with FormixControllerHost<_HostWidget> {
  final attached = <FormixController>[];
  final detached = <FormixController>[];

  @override
  FormixController? get explicitController => widget.controller;

  @override
  String get formixWidgetName => 'TestHost';

  @override
  void onControllerChanged(FormixController controller) => attached.add(controller);

  @override
  void onControllerDetached(FormixController oldController) => detached.add(oldController);

  void refresh() => refreshControllerHost();

  @override
  Widget build(BuildContext context) {
    return formixErrorOrNull() ?? const SizedBox.shrink();
  }
}
