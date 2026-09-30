import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixFieldID', () {
    test('withPrefix, parentKey, localName', () {
      const id = FormixFieldID<String>('name');
      final prefixed = id.withPrefix('user');
      expect(prefixed.key, 'user.name');
      expect(prefixed.parentKey, 'user');
      expect(prefixed.localName, 'name');
      // top-level field: no parent, localName == key
      expect(id.parentKey, isNull);
      expect(id.localName, 'name');
      expect(id.type, String);
    });

    test('isTypeValid & isNullableType for nullable and non-nullable', () {
      const nonNull = FormixFieldID<int>('n');
      expect(nonNull.isTypeValid(1), isTrue);
      expect(nonNull.isTypeValid('s'), isFalse);
      expect(nonNull.isNullableType, isFalse);

      const nullable = FormixFieldID<int?>('n2');
      expect(nullable.isNullableType, isTrue);
      expect(nullable.isTypeValid(null), isTrue);
    });

    test('equality and hashCode key on the string key', () {
      expect(const FormixFieldID<String>('a'), const FormixFieldID<int>('a'));
      expect(
        const FormixFieldID<String>('a').hashCode,
        const FormixFieldID<String>('a').hashCode,
      );
    });
  });

  group('FormixArrayID', () {
    test('item indexes into the array key', () {
      const arr = FormixArrayID<String>('tags');
      expect(arr.item(2).key, 'tags[2]');
      expect(arr.item(0).type, String);
    });

    test('withPrefix returns an array id', () {
      final arr = const FormixArrayID<String>('tags').withPrefix('post');
      expect(arr, isA<FormixArrayID<String>>());
      expect(arr.key, 'post.tags');
    });
  });

  group('FormixField', () {
    test('wrappedTransformer wraps and null returns null', () {
      final withT = FormixField<int>(
        id: const FormixFieldID<int>('n'),
        initialValue: 0,
        transformer: (dynamic v) => int.parse(v.toString()),
      );
      expect(withT.wrappedTransformer!('42'), 42);

      const withoutT = FormixField<int>(
        id: FormixFieldID<int>('n'),
        initialValue: 0,
      );
      expect(withoutT.wrappedTransformer, isNull);
    });

    test('isTypeValid and isNullableType', () {
      const f = FormixField<int>(id: FormixFieldID<int>('n'), initialValue: 0);
      expect(f.isTypeValid(1), isTrue);
      expect(f.isTypeValid('x'), isFalse);
      expect(f.isNullableType, isFalse);
      expect(f.toString(), contains('FormixField<int>'));
    });

    test('toConfig preserves the wrapped validator', () {
      final f = FormixField<String>(
        id: const FormixFieldID<String>('s'),
        initialValue: '',
        validator: (v) => (v == null || v.isEmpty) ? 'req' : null,
      );
      final cfg = f.toConfig();
      expect(cfg.validator!(''), 'req');
      expect(cfg.validator!('x'), isNull);
    });
  });

  group('FormixFieldConfig.chain', () {
    test('builds sync validator from a chain', () {
      final cfg = FormixFieldConfig<String>.chain(
        id: const FormixFieldID<String>('s'),
        rules: FormixValidators.string().required().minLength(3),
      );
      // Invoke the wrapped validator to exercise the chain closures.
      expect(cfg.validator!(''), isNotNull);
      expect(cfg.validator!('ab'), isNotNull); // too short
      expect(cfg.validator!('abcd'), isNull);
      expect(cfg.toString(), contains('FormixFieldConfig<String>'));
    });
  });
}
