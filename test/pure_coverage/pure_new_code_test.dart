@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:formix/src/validators/validators.dart';
import 'package:formix/src/validators/validation_keys.dart';
import 'package:formix/src/controllers/submission.dart';

void main() {
  group('type-scoped validators (pure)', () {
    test('string chain', () {
      final v = FormixValidators.string().required().email().minLength(3).maxLength(5).pattern(RegExp(r'^\w+$')).build();
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('ab'), isNotNull); // too short
      expect(v('abcdef'), isNotNull); // too long
      expect(v('a@b'), isNotNull); // not email but also passes length? email fails
      expect(v('abcd'), isNotNull); // not an email
    });

    test('number chain incl between/positive', () {
      final v = FormixValidators.number<int>().required().min(1).max(100).positive().between(10, 20).build();
      expect(v(null), isNotNull);
      expect(v(5), isNotNull); // below between
      expect(v(15), isNull);
      expect(v(25), isNotNull); // above between
      final b = FormixValidators.number<int>().between(10, 20).build();
      expect(b(9), isNotNull);
      expect(b(21), isNotNull);
      expect(b(10), isNull);
      expect(b(20), isNull);
      expect(b(null), isNull);
    });

    test('date chain after/before/between', () {
      final start = DateTime(2020), end = DateTime(2030);
      final a = FormixValidators.date().after(start).build();
      expect(a(DateTime(2019)), isNotNull);
      expect(a(DateTime(2021)), isNull);
      expect(a(null), isNull);
      final bf = FormixValidators.date().before(end).build();
      expect(bf(DateTime(2031)), isNotNull);
      expect(bf(DateTime(2025)), isNull);
      final bt = FormixValidators.date().between(start, end).build();
      expect(bt(DateTime(2019)), isNotNull);
      expect(bt(DateTime(2025)), isNull);
      expect(bt(DateTime(2031)), isNotNull);
    });

    test('generic oneOf + any + custom + async + debounce', () async {
      final v = FormixValidators.any<String>().oneOf(['a', 'b']).build();
      expect(v('a'), isNull);
      expect(v('c'), isNotNull);
      expect(v(null), isNull);

      final chain = FormixValidators.string()
          .custom((s) => s == 'bad' ? 'no' : null)
          .async((s) async => s == 'taken' ? 'taken!' : null)
          .debounce(const Duration(milliseconds: 10));
      expect(chain.debounceDuration, const Duration(milliseconds: 10));
      final sync = chain.build();
      expect(sync('bad'), 'no');
      final asyncV = chain.buildAsync();
      expect(await asyncV('taken'), 'taken!');
      expect(await asyncV('ok'), isNull);
      expect(await asyncV('bad'), isNull); // sync fails first -> async skipped
    });

    test('validation keys withParam', () {
      expect(FormixValidationKeys.withParam(FormixValidationKeys.min, 5), 'formix_key_min:5');
      expect(FormixValidationKeys.minDate, 'formix_key_min_date');
      expect(FormixValidationKeys.invalidSelection, 'formix_key_invalid_selection');
    });
  });

  group('sealed FormixSubmission (pure)', () {
    test('factories, equality, isInProgress', () {
      expect(const FormixSubmission.idle(), const FormixSubmissionIdle());
      expect(const FormixSubmission.submitting(), const FormixSubmissionSubmitting());
      expect(const FormixSubmission.success(), const FormixSubmissionSuccess());
      expect(const FormixSubmission.idle().isInProgress, isFalse);
      expect(const FormixSubmission.submitting().isInProgress, isTrue);

      final e1 = FormixSubmission.error('boom', StackTrace.current);
      const e2 = FormixSubmission.error('boom');
      expect(e1, e2); // equality by error
      expect(e1.hashCode, e2.hashCode);
      expect((e1 as FormixSubmissionError).error, 'boom');

      // hashCodes are stable/distinct per state
      expect(const FormixSubmissionIdle().hashCode, const FormixSubmissionIdle().hashCode);
      expect(const FormixSubmissionSuccess() == const FormixSubmissionIdle(), isFalse);
    });

    test('exhaustive switch', () {
      String label(FormixSubmission s) => switch (s) {
            FormixSubmissionIdle() => 'idle',
            FormixSubmissionSubmitting() => 'submitting',
            FormixSubmissionSuccess() => 'success',
            FormixSubmissionError() => 'error',
          };
      expect(label(const FormixSubmission.idle()), 'idle');
      expect(label(const FormixSubmission.submitting()), 'submitting');
      expect(label(const FormixSubmission.success()), 'success');
      expect(label(const FormixSubmission.error('x')), 'error');
    });
  });

  group('coverage gap-fillers (isolated branches)', () {
    test('each string/number rule hits its default-message branch', () {
      expect(FormixValidators.string().minLength(3).build()('ab'), isNotNull);
      expect(FormixValidators.string().maxLength(3).build()('abcd'), isNotNull);
      expect(FormixValidators.string().pattern(RegExp(r'^\\d+$')).build()('abc'), isNotNull);
      expect(FormixValidators.string().minLength(3).build()(null), isNull);
      expect(FormixValidators.number<int>().min(5).build()(1), isNotNull);
      expect(FormixValidators.number<int>().max(5).build()(9), isNotNull);
      expect(FormixValidators.number<int>().positive().build()(-1), isNotNull);
      expect(FormixValidators.number<int>().positive().build()(3), isNull);
    });

    test('submission ==/hashCode for every state', () {
      expect(const FormixSubmissionSubmitting() == const FormixSubmissionIdle(), isFalse);
      expect(const FormixSubmissionSubmitting().hashCode, const FormixSubmissionSubmitting().hashCode);
      expect(const FormixSubmissionSuccess() == const FormixSubmissionSubmitting(), isFalse);
      expect(const FormixSubmissionSuccess().hashCode, const FormixSubmissionSuccess().hashCode);
      expect(const FormixSubmissionIdle() == const FormixSubmissionSuccess(), isFalse);
      expect(const FormixSubmissionError('a') == const FormixSubmissionError('b'), isFalse);
    });
  });
}
