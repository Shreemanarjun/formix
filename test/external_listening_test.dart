import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('External Listening Tests', () {
    late GlobalKey<FormixState> formKey;
    const nameField = FormixFieldID<String>('name');

    setUp(() {
      formKey = GlobalKey<FormixState>();
    });

    testWidgets('Stream emits state changes (Sync)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                initialValue: const {'name': ''},
                fields: const [
                  FormixFieldConfig<String>(id: nameField, initialValue: ''),
                ],
                child: const SizedBox(),
              ),
            ),
          ),
        );

        await tester.pump();
        final controller = formKey.currentState!.controller;
        final receivedValues = <String?>[];

        final subscription = controller.stream.listen((state) {
          receivedValues.add(state.values['name']);
        });

        // With sync: true, this should fire immediately
        controller.setValue(nameField, 'John');

        // Verification without pump!
        expect(receivedValues.last, 'John');

        await subscription.cancel();
      });
    });

    testWidgets('FormixListener Widget (Easy API)', (tester) async {
      await tester.runAsync(() async {
        final receivedStates = <FormixData>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FormixListener(
                formKey: formKey,
                listener: (context, state) {
                  receivedStates.add(state);
                },
                child: Formix(
                  key: formKey,
                  initialValue: const {'name': ''},
                  fields: const [
                    FormixFieldConfig<String>(
                      id: nameField,
                      initialValue: '',
                    ),
                  ],
                  child: const SizedBox(),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final controller = formKey.currentState!.controller;
        controller.setValue(nameField, 'EasyAPI');

        expect(receivedStates.length, greaterThan(0));
        expect(receivedStates.last.values['name'], 'EasyAPI');
      });
    });

    testWidgets('Performance Check (Many Listeners)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                initialValue: const {'name': ''},
                fields: const [
                  FormixFieldConfig<String>(id: nameField, initialValue: ''),
                ],
                child: const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump();

        final controller = formKey.currentState!.controller;
        const listenerCount = 50;
        var callbackCount = 0;
        final subscriptions = <StreamSubscription>[];

        // Add many listeners to stream
        for (var i = 0; i < listenerCount; i++) {
          subscriptions.add(
            controller.stream.listen((_) {
              callbackCount++;
            }),
          );
        }

        final stopwatch = Stopwatch()..start();
        controller.setValue(nameField, 'PerfTest');
        stopwatch.stop();

        expect(
          callbackCount,
          listenerCount,
          reason: 'All listeners should fire',
        );
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(300),
          reason: 'Update should be fast',
        );

        for (final sub in subscriptions) {
          await sub.cancel();
        }
      });
    });

    testWidgets('Stream closes on dispose (Memory Leak Check)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                initialValue: const {'name': ''},
                fields: const [],
                child: const SizedBox(),
              ),
            ),
          ),
        );

        await tester.pump();

        final controller = formKey.currentState!.controller;
        final completer = Completer<void>();

        final sub = controller.stream.listen(
          (_) {},
          onDone: () {
            completer.complete();
          },
        );

        // Dispose by removing widget
        await tester.pumpWidget(Container());
        await tester.pump();

        // Wait for stream to close using standard await on Future
        await completer.future.timeout(const Duration(seconds: 2));

        await sub.cancel();
      });
    });
  });
}
