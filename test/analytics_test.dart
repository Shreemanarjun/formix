import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Manual Mock class for analytics
class FakeFormixAnalytics implements FormixAnalytics {
  final List<String> events = [];

  @override
  void onFormStarted(String? formId) {
    events.add('onFormStarted: $formId');
  }

  @override
  void onFieldChanged(String? formId, String fieldKey, dynamic newValue) {
    events.add('onFieldChanged: $formId, $fieldKey, $newValue');
  }

  @override
  void onFieldTouched(String? formId, String fieldKey) {
    events.add('onFieldTouched: $formId, $fieldKey');
  }

  @override
  void onSubmitAttempt(String? formId, Map<String, dynamic> values) {
    events.add('onSubmitAttempt: $formId');
  }

  @override
  void onSubmitSuccess(String? formId) {
    events.add('onSubmitSuccess: $formId');
  }

  @override
  void onSubmitFailure(String? formId, Map<String, dynamic> errors) {
    events.add('onSubmitFailure: $formId');
  }

  @override
  void onFormAbandoned(String? formId, Duration timeSpent) {
    events.add('onFormAbandoned: $formId');
  }
}

void main() {
  group('Form Analytics Tests', () {
    const fieldA = FormixFieldID<String>('fieldA');

    test('Tracks basic lifecycle events', () async {
      final analytics = FakeFormixAnalytics();
      final controller = FormixController(
        fields: [
          const FormixFieldConfig<String>(id: fieldA, initialValue: 'A').toField(),
        ],
        formId: 'test_form',
        analytics: analytics,
      );

      // 1. Started
      expect(analytics.events, contains('onFormStarted: test_form'));

      // 2. Value Change
      controller.setValue(fieldA, 'New Value');
      expect(
        analytics.events,
        contains('onFieldChanged: test_form, fieldA, New Value'),
      );

      // 3. Touch
      controller.markAsTouched(fieldA);
      expect(analytics.events, contains('onFieldTouched: test_form, fieldA'));

      // 4. Submit Success
      await controller.submit(onValid: (_) async {});
      expect(analytics.events, contains('onSubmitAttempt: test_form'));
      expect(analytics.events, contains('onSubmitSuccess: test_form'));

      // Dispose - should NOT call abandoned because submit succeeded
      controller.dispose();
      expect(analytics.events, isNot(contains('onFormAbandoned: test_form')));
    });

    test('Tracks abandonment', () async {
      final analytics = FakeFormixAnalytics();
      final controller = FormixController(
        fields: [
          const FormixFieldConfig<String>(id: fieldA, initialValue: 'A').toField(),
        ],
        formId: 'test_form_aband',
        analytics: analytics,
      );

      // Clean dispose without submit
      controller.dispose();

      // Verify abandoned called
      expect(analytics.events, contains('onFormAbandoned: test_form_aband'));
    });

    test('Tracks submission failure', () async {
      final analytics = FakeFormixAnalytics();
      final controller = FormixController(
        fields: [
          FormixFieldConfig<String>(
            id: fieldA,
            initialValue: '',
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ).toField(),
        ],
        formId: 'test_form_fail',
        analytics: analytics,
      );

      await controller.submit(onValid: (_) async {}, onError: (_) {});

      expect(analytics.events, contains('onSubmitAttempt: test_form_fail'));
      expect(analytics.events, contains('onSubmitFailure: test_form_fail'));
      expect(
        analytics.events,
        isNot(contains('onSubmitSuccess: test_form_fail')),
      );
    });
  });
}
