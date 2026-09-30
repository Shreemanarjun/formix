// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// Demonstrates the signals-core advantage: updating a single field among many
/// rebuilds ONLY that field's reactive builder — not the whole form.
void main() {
  testWidgets('updating one field of 1000 rebuilds exactly one builder', (tester) async {
    const count = 1000;
    final ids = List.generate(count, (i) => FormixFieldID<String>('f$i'));
    final rebuilds = List.filled(count, 0);
    final formKey = GlobalKey<FormixState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            key: formKey,
            initialValue: {for (final id in ids) id.key: ''},
            child: ListView.builder(
              itemCount: count,
              itemBuilder: (context, i) => FormixBuilder(
                builder: (context, scope) {
                  rebuilds[i]++;
                  return Text('${scope.watchValue(ids[i])}', key: ValueKey('t$i'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Only the first screenful is built by ListView; capture their baseline.
    final baseline = List.of(rebuilds);

    // Update field 0 (which is on-screen).
    formKey.currentState!.controller.setValue(ids[0], 'changed');
    await tester.pump();

    // Field 0 rebuilt exactly once more; no other visible builder rebuilt.
    expect(rebuilds[0], baseline[0] + 1);
    for (var i = 1; i < count; i++) {
      expect(rebuilds[i], baseline[i], reason: 'field $i must not rebuild when field 0 changes');
    }

    expect(find.byKey(const ValueKey('t0')), findsOneWidget);
  });

  testWidgets('bulk update of 1000 fields completes quickly', (tester) async {
    const count = 1000;
    final ids = List.generate(count, (i) => FormixFieldID<int>('n$i'));
    final c = FormixController(initialValue: {for (final id in ids) id.key: 0});
    addTearDown(c.dispose);

    final sw = Stopwatch()..start();
    c.setValues({for (final id in ids) id: 1});
    sw.stop();

    expect(c.getValue(ids[0]), 1);
    expect(c.getValue(ids[count - 1]), 1);
    // Generous ceiling; the batch is a single state transition.
    expect(sw.elapsedMilliseconds, lessThan(1000));
    print('Bulk update of $count fields: ${sw.elapsedMilliseconds}ms');
  });
}
