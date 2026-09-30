import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

const _src = FormixFieldID<String>('src');
const _src2 = FormixFieldID<String>('src2');
const _dst = FormixFieldID<String>('dst');

void main() {
  testWidgets('shows config error when used outside Formix', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FormixFieldAsyncTransformer<String, String>(
          sourceField: _src,
          targetField: _dst,
          transform: (v) async => (v ?? '').toUpperCase(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
  });

  testWidgets('retransformOnSubmit re-runs transform on submit', (tester) async {
    final controller = FormixController(
      fields: [
        const FormixField<String>(id: _src, initialValue: 'a'),
        const FormixField<String>(id: _dst, initialValue: ''),
      ],
    );
    addTearDown(controller.dispose);

    var transformCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Formix(
          controller: controller,
          child: FormixFieldAsyncTransformer<String, String>(
            sourceField: _src,
            targetField: _dst,
            retransformOnSubmit: true,
            transform: (v) async {
              transformCount++;
              return (v ?? '').toUpperCase();
            },
          ),
        ),
      ),
    );
    await tester.pump(); // initial transform scheduled
    await tester.pumpAndSettle();
    final afterMount = transformCount;
    expect(controller.getValue(_dst), 'A');

    // Submitting flips isSubmitting true -> _onSubmitChanged re-runs transform.
    await controller.submit(onValid: (_) async {});
    await tester.pumpAndSettle();
    expect(transformCount, greaterThan(afterMount));
  });

  testWidgets('didUpdateWidget: debounce, retransform toggle, source change', (tester) async {
    final controller = FormixController(
      fields: [
        const FormixField<String>(id: _src, initialValue: 'a'),
        const FormixField<String>(id: _src2, initialValue: 'b'),
        const FormixField<String>(id: _dst, initialValue: ''),
      ],
    );
    addTearDown(controller.dispose);

    Widget build({
      required Duration? debounce,
      required bool retransform,
      required FormixFieldID<String> source,
    }) => MaterialApp(
      home: Formix(
        controller: controller,
        child: FormixFieldAsyncTransformer<String, String>(
          sourceField: source,
          targetField: _dst,
          debounce: debounce,
          retransformOnSubmit: retransform,
          transform: (v) async => (v ?? '').toUpperCase(),
        ),
      ),
    );

    await tester.pumpWidget(
      build(
        debounce: null,
        retransform: false,
        source: _src,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.getValue(_dst), 'A');

    // Change debounce -> subscription rebuilt; enable retransform -> listener added.
    await tester.pumpWidget(
      build(
        debounce: const Duration(milliseconds: 10),
        retransform: true,
        source: _src,
      ),
    );
    await tester.pumpAndSettle();

    // Disable retransform -> listener removed; change source field -> effect rewired.
    await tester.pumpWidget(
      build(
        debounce: const Duration(milliseconds: 10),
        retransform: false,
        source: _src2,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.getValue(_dst), 'B');
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal clears pending on the target field', (tester) async {
    final controller = FormixController(
      fields: [
        const FormixField<String>(id: _src, initialValue: 'a'),
        const FormixField<String>(id: _dst, initialValue: ''),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Formix(
          controller: controller,
          child: FormixFieldAsyncTransformer<String, String>(
            sourceField: _src,
            targetField: _dst,
            transform: (v) async => (v ?? '').toUpperCase(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Remove the transformer -> dispose() schedules setPending(false) microtask.
    await tester.pumpWidget(
      MaterialApp(
        home: Formix(controller: controller, child: const SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.state.isFieldPending(_dst), isFalse);
  });
}
