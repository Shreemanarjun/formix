import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
// Not exported publicly; imported by src path to exercise register/unregister.
import 'package:formix/src/devtools/formix_devtools.dart';

// NOTE: The service-extension handler bodies in formix_devtools.dart
// (ext.formix.listForms, getFormDetails, updateFieldValue, etc.) can only be
// executed by the Flutter DevTools extension bridge over the VM service.
// `flutter test` runs with no VM service (dev.Service.getInfo().serverUri is
// null), so those closures are unreachable from a unit test. We cover the
// synchronously-reachable surface: registerController / unregisterController
// and the _latestActiveId bookkeeping.

void main() {
  group('FormixDevToolsService register/unregister', () {
    test('creating a controller with a formId registers it', () {
      // A controller with a formId sets _registeredDevToolsId and calls
      // registerController from _initialize().
      final c = FormixController(
        formId: 'devtools_form_a',
        initialValue: const {'x': 1},
        fields: [FormixField<int>(id: FormixFieldID<int>('x'), initialValue: 1)],
      );
      addTearDown(c.dispose);
      // No public getter; the fact it constructs and disposes cleanly (which
      // calls unregisterController) is the assertion here.
      expect(c.getValue(FormixFieldID<int>('x')), 1);
    });

    test('registering a second controller then disposing the latest reassigns latest', () {
      final a = FormixController(
        formId: 'devtools_form_1',
        fields: [FormixField<int>(id: FormixFieldID<int>('x'), initialValue: 1)],
      );
      final b = FormixController(
        formId: 'devtools_form_2',
        fields: [FormixField<int>(id: FormixFieldID<int>('y'), initialValue: 2)],
      );
      // Disposing b (the latest) hits the `_latestActiveId == id` branch that
      // reassigns _latestActiveId to the last remaining active controller.
      b.dispose();
      // Disposing a hits the branch where there are no remaining controllers,
      // so _latestActiveId becomes null (lastOrNull on empty).
      a.dispose();
      // Re-register something afterwards to prove the service is still usable.
      final c = FormixController(
        formId: 'devtools_form_3',
        fields: [FormixField<int>(id: FormixFieldID<int>('z'), initialValue: 3)],
      );
      addTearDown(c.dispose);
      expect(c.getValue(FormixFieldID<int>('z')), 3);
    });

    test('direct registerController / unregisterController with a namespace controller', () {
      // A controller using namespace (no formId) also registers under its
      // namespace via _registeredDevToolsId = formId ?? namespace.
      final c = FormixController(
        namespace: 'ns_devtools',
        fields: [FormixField<String>(id: FormixFieldID<String>('n'), initialValue: 'v')],
      );
      // Also exercise the static API directly for good measure.
      FormixDevToolsService.registerController('manual_id', c);
      FormixDevToolsService.unregisterController('manual_id');
      // Unregistering an id that isn't the latest active is a safe no-op path.
      FormixDevToolsService.unregisterController('never_registered');
      addTearDown(c.dispose);
      expect(c.getValue(FormixFieldID<String>('n')), 'v');
    });
  });
}
