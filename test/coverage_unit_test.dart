import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('sameTypes', () {
    test('true for identical types, false otherwise', () {
      expect(sameTypes<int, int>(), isTrue);
      expect(sameTypes<String, String>(), isTrue);
      expect(sameTypes<int, num>(), isFalse);
      expect(sameTypes<String, int>(), isFalse);
    });
  });

  group('LoggingFormAnalytics', () {
    test('all hooks run without throwing (enabled + disabled)', () {
      for (final analytics in [
        const LoggingFormAnalytics(),
        const LoggingFormAnalytics(prefix: 'X', enabled: false),
      ]) {
        analytics.onFormStarted('f');
        analytics.onFormStarted(null);
        analytics.onFieldChanged('f', 'k', 1);
        analytics.onFieldTouched('f', 'k');
        analytics.onSubmitAttempt('f', const {'k': 1});
        analytics.onSubmitSuccess('f');
        analytics.onSubmitFailure('f', const {'k': 'bad'});
        analytics.onFormAbandoned('f', const Duration(seconds: 3));
        analytics.onFormAbandoned(null, Duration.zero);
      }
      expect(const LoggingFormAnalytics().toString(), contains('LoggingFormAnalytics'));
    });
  });

  group('FormixValidators', () {
    test('string chain: required/email/minLength/maxLength/pattern (custom messages)', () {
      expect(FormixValidators.string().required('req').build()(null), 'req');
      expect(FormixValidators.string().required('req').build()('  '), 'req'); // whitespace trimmed
      expect(FormixValidators.string().email('mail').build()('notanemail'), 'mail');
      expect(FormixValidators.string().minLength(3, 'min').build()('ab'), 'min');
      expect(FormixValidators.string().maxLength(2, 'max').build()('abc'), 'max');
      expect(FormixValidators.string().pattern(RegExp(r'^\d+$'), 'pat').build()('abc'), 'pat');
      // A fully valid value passes the whole chain.
      expect(FormixValidators.string().required().email().minLength(5).maxLength(20).build()('a@b.com'), isNull);
    });

    test('string chain uses default keys when no message', () {
      expect(FormixValidators.string().required().build()(null), 'formix_key_required');
      expect(FormixValidators.string().email().build()('bad'), 'formix_key_invalid_email');
      expect(FormixValidators.string().minLength(5).build()('ab'), contains('formix_key_min_length'));
      expect(FormixValidators.string().maxLength(1).build()('ab'), contains('formix_key_max_length'));
      expect(FormixValidators.string().pattern(RegExp(r'^\d+$')).build()('x'), 'formix_key_invalid_format');
    });

    test('number chain: min/max/positive', () {
      expect(FormixValidators.number<int>().min(5).build()(3), contains('formix_key_min'));
      expect(FormixValidators.number<int>().max(5).build()(9), contains('formix_key_max'));
      expect(FormixValidators.number<int>().positive().build()(-1), isNotNull);
      expect(FormixValidators.number<int>().min(0).max(10).build()(5), isNull);
      expect(FormixValidators.number<double>().min(1.5).build()(null), isNull); // null skips
    });

    test('generic + custom + async + debounce chains', () async {
      final chain = FormixValidators.any<bool>().required('req').custom((v) => v == true ? null : 'must be true');
      expect(chain.build()(null), 'req');
      expect(chain.build()(false), 'must be true');
      expect(chain.build()(true), isNull);

      final asyncV = FormixValidators.string()
          .required()
          .async((v) async => v == 'taken' ? 'unavailable' : null)
          .debounce(const Duration(milliseconds: 10))
          .buildAsync();
      expect(await asyncV('taken'), 'unavailable');
      expect(await asyncV('free'), isNull);
      // sync failure short-circuits async
      expect(await asyncV(null), isNull);
    });
  });

  group('FormixBatch / FormixBatchResult', () {
    const a = FormixFieldID<String>('a');
    const b = FormixFieldID<int>('b');

    test('builder collects typed updates', () {
      final batch = FormixBatch()
        ..set(a, 'x')
        ..setField(const FormixField<int>(id: b, initialValue: 0), 2);
      batch.setValue(a).to('y');
      batch.addAll({'c': true});
      expect(batch.isEmpty, isFalse);
      expect(batch.updates, hasLength(3)); // a, b, c (a overwritten)
      expect(batch.updates.values, contains('y'));
    });

    test('result reports errors and toString', () {
      const ok = FormixBatchResult(success: true, updatedFields: {'a'});
      expect(ok.errors, isEmpty);
      expect(ok.toString(), contains('Success'));

      const bad = FormixBatchResult(
        success: false,
        typeMismatches: {'a': 'type error'},
        missingFields: {'z'},
      );
      expect(bad.errors['a'], 'type error');
      expect(bad.errors['z'], 'Field not registered');
      expect(bad.toString(), contains('Failed'));
    });
  });

  group('i18n messages (all locales)', () {
    final locales = <FormixMessages>[
      const DefaultFormixMessages(),
      const GermanFormixMessages(),
      const SpanishFormixMessages(),
      const FrenchFormixMessages(),
      const HindiFormixMessages(),
      const ChineseFormixMessages(),
    ];

    test('every message method returns a non-empty string', () {
      final date = DateTime(2020, 1, 2);
      for (final m in locales) {
        expect(m.required('Name'), isNotEmpty);
        expect(m.invalidFormat(), isNotEmpty);
        expect(m.minLength('Name', 3), isNotEmpty);
        expect(m.maxLength('Name', 8), isNotEmpty);
        expect(m.minValue('Age', 18), isNotEmpty);
        expect(m.maxValue('Age', 99), isNotEmpty);
        expect(m.minDate('Date', date), isNotEmpty);
        expect(m.maxDate('Date', date), isNotEmpty);
        expect(m.invalidSelection('Choice'), isNotEmpty);
        expect(m.validationFailed('boom'), isNotEmpty);
        expect(m.validating(), isNotEmpty);
        expect(m.format('{a}-{b}', {'a': 1, 'b': 2}), '1-2');
      }
    });
  });
}
