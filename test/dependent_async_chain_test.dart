import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets(
    'FormixDependentAsyncField chain A->B->C re-execution behavior',
    (tester) async {
      int aFetchCount = 0;
      int bFetchCount = 0;
      int cFetchCount = 0;

      Future<String> fetchA() async {
        aFetchCount++;
        await Future.delayed(const Duration(milliseconds: 10));
        return 'A_Value';
      }

      Future<String> fetchB(String? aValue) async {
        bFetchCount++;
        await Future.delayed(const Duration(milliseconds: 10));
        return 'B_Value_from_$aValue';
      }

      Future<String> fetchC(String? bValue) async {
        cFetchCount++;
        await Future.delayed(const Duration(milliseconds: 10));
        return 'C_Value_from_$bValue';
      }

      const fieldA = FormixFieldID<String>('fieldA');
      const fieldB = FormixFieldID<String>('fieldB');
      const fieldC = FormixFieldID<String>('fieldC');
      const fieldbOptions = FormixFieldID<String>('fieldB_Options'); // Placeholder for async result
      const fieldcOptions = FormixFieldID<String>('fieldC_Options'); // Placeholder for async result

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              onChanged: (_) {},
              child: Column(
                children: [
                  // Field A (Async Source)
                  FormixAsyncField<String>(
                    fieldId: fieldA,
                    future: fetchA(),
                    builder: (context, state) {
                      return Text('A: ${state.asyncState.value}');
                    },
                  ),
                  // Field B (Depends on A)
                  FormixDependentAsyncField<String, String>(
                    fieldId: fieldbOptions,
                    dependency: fieldA,
                    resetField: fieldB,
                    future: fetchB,
                    onData: (context, controller, data) {
                      controller.setValue(fieldB, data);
                    },
                    builder: (context, state) => Text('B Options: ${state.asyncState.value}'),
                  ),
                  // Field C (Depends on B)
                  FormixDependentAsyncField<String, String>(
                    fieldId: fieldcOptions,
                    dependency: fieldB,
                    resetField: fieldC,
                    future: fetchC,
                    onData: (context, controller, data) {
                      controller.setValue(fieldC, data);
                    },
                    builder: (context, state) => Text('C Options: ${state.asyncState.value}'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Initial pump
      await tester.pump();
      expect(find.textContaining('Loading'), findsNothing); // Or whatever default

      // Wait for A to resolve
      await tester.pumpAndSettle();

      // Check fetch counts
      // A fetches once.
      // A resolves -> sets value 'A_Value'.
      // B dependency changes (null -> 'A_Value') -> B fetches.
      // B resolves -> sets value 'B_Value_from_A_Value'.
      // C dependency changes (null -> 'B_Value_from_A_Value') -> C fetches.
      // C resolves -> sets value 'C_Value_from_...'.

      expect(aFetchCount, 1, reason: 'A should fetch once');
      expect(bFetchCount, greaterThanOrEqualTo(1), reason: 'B should fetch at least once (initial null + update)'); // B might fetch for null first?
      // Actually:
      // Initial state: A=null, B=null, C=null.
      // A future starts.
      // B future starts (dependency A=null). fetchB(null).
      // C future starts (dependency B=null). fetchC(null).
      // So counts should be 1, 1, 1 initially.

      // Then A resolves to 'A_Value'.
      // B sees A=A_Value. B re-fetches. count=2.
      // B resolves to 'B_Value...'.
      // C sees B=B_Value... C re-fetches. count=2.

      // So we expect: A=1, B=2, C=2.
      // Wait, A's future is passed as `fetchA()`. If `build` is called again (due to setting values), `fetchA()` is called again?
      // FormixAsyncField builder uses `future` argument.
      // If we pass `fetchA()` call in build, it creates a NEW future every build.
      // FormixAsyncField logic: if future changes, checks `dependencies`.
      // If dependencies is null (default), it updates future and re-executes effectively?
      // Wait.
      // `FormixAsyncField`:
      // if (widget.future != oldWidget.future) {
      //   final changed = widget.dependencies == null || ...
      //   if (changed) { _initAsyncState(); }
      // }
      // Since we didn't pass dependencies for A, and we passed `fetchA()` (which returns new Future), A WILL re-execute on every parent rebuild!
      // This is BAD practice but common user error.
      // However, for B and C, `FormixDependentAsyncField` passes explicit `dependencies: [dependencyValue]`.
      // So B and C should ONLY re-execute if dependencyValue changes, even if `future` instance differs.

      // Let's verify B and C don't loop infinitely or re-execute unnecessarily.

      // Rebuild widget tree by interacting or simplified pump
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              onChanged: (_) {},
              child: Column(
                children: [
                  // Field A (Async Source) - Use same future to avoid A re-fetching loop for now?
                  // Or let's see if A re-fetches.
                  FormixAsyncField<String>(
                    fieldId: fieldA,
                    // We need to keep A stable or dependent tests will be noisy?
                    // Actually, if A re-fetches, it sets value 'A_Value' again.
                    // controller.setValue('fieldA', 'A_Value').
                    // If value is identical, does it notify?
                    // FormixController checks for equality.
                    // If equal, no notification. A doesn't "change".
                    // So B dependency "value" doesn't change.
                    // So B should NOT re-fetch.
                    future: fetchA(),
                    builder: (context, state) {
                      return Text('A: ${state.asyncState.value}');
                    },
                    onData: (context, controller, data) {
                      controller.setValue(fieldA, data);
                    },
                  ),
                  FormixDependentAsyncField<String, String>(
                    fieldId: fieldbOptions,
                    dependency: fieldA,
                    resetField: fieldB,
                    future: fetchB,
                    onData: (context, controller, data) {
                      controller.setValue(fieldB, data);
                    },
                    builder: (context, state) => Text('B Options: ${state.asyncState.value}'),
                  ),
                  FormixDependentAsyncField<String, String>(
                    fieldId: fieldcOptions,
                    dependency: fieldB,
                    resetField: fieldC,
                    future: fetchC,
                    onData: (context, controller, data) {
                      controller.setValue(fieldC, data);
                    },
                    builder: (context, state) => Text('C Options: ${state.asyncState.value}'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bCountAfter = bFetchCount;
      final cCountAfter = cFetchCount;

      // Pump again to trigger rebuilds
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              onChanged: (_) {},
              child: Column(
                children: [
                  FormixAsyncField<String>(
                    fieldId: fieldA,
                    future: fetchA(), // This passes a NEW future
                    builder: (context, state) {
                      return Text('A: ${state.asyncState.value}');
                    },
                    onData: (context, controller, data) {
                      controller.setValue(fieldA, data);
                    },
                  ),
                  // ... B and C (same code)
                  FormixDependentAsyncField<String, String>(
                    fieldId: fieldbOptions,
                    dependency: fieldA,
                    resetField: fieldB,
                    future: fetchB,
                    onData: (context, controller, data) {
                      controller.setValue(fieldB, data);
                    },
                    builder: (context, state) => Text('B Options: ${state.asyncState.value}'),
                  ),
                  FormixDependentAsyncField<String, String>(
                    fieldId: fieldcOptions,
                    dependency: fieldB,
                    resetField: fieldC,
                    future: fetchC,
                    onData: (context, controller, data) {
                      controller.setValue(fieldC, data);
                    },
                    builder: (context, state) => Text('C Options: ${state.asyncState.value}'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A should re-fetch because we passed a new future and no dependencies list (default behavior).
      // B and C should NOT re-fetch because A's value ('A_Value') didn't change (even if A re-fetched).
      // Equality check in controller prevents notification.

      expect(bFetchCount, bCountAfter, reason: 'B should not re-fetch if dependency value is unchanged');
      expect(cFetchCount, cCountAfter, reason: 'C should not re-fetch if dependency value is unchanged');
    },
  );
}
