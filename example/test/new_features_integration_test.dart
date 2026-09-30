import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// A realistic signup form built entirely from the new 0.2.0 APIs, driven
/// end-to-end through the widget tree — the "works on app" proof for:
/// FormixValue, FormixSubmitButton, context.formix, type-scoped validators,
/// group2/setGroup records, and the sealed submission state.
class SignupDemo extends StatelessWidget {
  const SignupDemo({super.key, required this.onSubmit});

  final Future<void> Function(Map<String, dynamic> values) onSubmit;

  static const email = FormixFieldID<String>('email');
  static const age = FormixFieldID<int>('age');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Formix(
          fields: [
            FormixFieldConfig<String>(
              id: email,
              validationMode: FormixAutovalidateMode.always,
              validator: FormixValidators.string().required().email().build(),
            ),
            FormixFieldConfig<int>(
              id: age,
              validationMode: FormixAutovalidateMode.always,
              validator: FormixValidators.number<int>()
                  .required()
                  .between(18, 99)
                  .build(),
            ),
          ],
          child: Builder(
            builder: (context) => Column(
              children: [
                const FormixTextFormField(
                  fieldId: email,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                FormixNumberFormField<int>(
                  fieldId: age,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),

                // FormixValue: live single-field read.
                FormixValue<String>(
                  email,
                  builder: (context, v) => Text('echo:${v ?? ''}'),
                ),

                // Sealed submission state rendered exhaustively.
                FormixBuilder(
                  builder: (context, scope) =>
                      switch (scope.controller.submissionSignal.value) {
                        FormixSubmissionIdle() => const Text('status:idle'),
                        FormixSubmissionSubmitting() => const Text(
                          'status:submitting',
                        ),
                        FormixSubmissionSuccess() => const Text(
                          'status:success',
                        ),
                        FormixSubmissionError() => const Text('status:error'),
                      },
                ),

                // context.formix + typed record write.
                TextButton(
                  onPressed: () => context.formix.setGroup2(email, age, (
                    'prefilled@x.io',
                    25,
                  )),
                  child: const Text('Prefill'),
                ),

                FormixSubmitButton(
                  onValid: onSubmit,
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'signup form: validators, FormixValue, setGroup, submit lifecycle',
    (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(SignupDemo(onSubmit: (v) async => submitted = v));
      await tester.pumpAndSettle();

      ElevatedButton submitBtn() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      // FormixValue echoes the email field live.
      await tester.enterText(find.byType(TextField).first, 'not-an-email');
      await tester.pump();
      expect(find.text('echo:not-an-email'), findsOneWidget);

      // Invalid form (bad email, empty age): validate surfaces errors → submit disabled.
      final ctx = tester.element(find.byType(FormixSubmitButton));
      ctx.formix.validate();
      await tester.pump();
      expect(submitBtn().onPressed, isNull, reason: 'invalid → disabled');
      expect(
        find.textContaining('valid'),
        findsWidgets,
        reason: 'email validator message resolved via i18n',
      );

      // Typed record write fills both fields with valid values in one batch.
      await tester.tap(find.text('Prefill'));
      await tester.pumpAndSettle();
      expect(find.text('echo:prefilled@x.io'), findsOneWidget);
      expect(submitBtn().onPressed, isNotNull, reason: 'valid → enabled');

      // Submit runs the lifecycle to success (asserted on the live controller).
      expect(ctx.formix.submissionSignal.value, const FormixSubmission.idle());
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(submitted, {'email': 'prefilled@x.io', 'age': 25});
      expect(
        ctx.formix.submissionSignal.value,
        const FormixSubmission.success(),
      );
    },
  );

  testWidgets('age between-validator rejects out-of-range values on the app', (
    tester,
  ) async {
    await tester.pumpWidget(SignupDemo(onSubmit: (_) async {}));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(FormixSubmitButton));
    ctx.formix.setGroup2(SignupDemo.email, SignupDemo.age, (
      'a@b.io',
      5,
    )); // under 18
    ctx.formix.validate();
    await tester.pump();

    expect(ctx.formix.getValidation(SignupDemo.age).isValid, isFalse);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });
}
