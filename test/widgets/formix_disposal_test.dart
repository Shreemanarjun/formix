import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

class TestFormixController extends FormixController {
  bool isDisposed = false;

  @override
  void dispose() {
    if (preventDisposal) return;
    isDisposed = true;
    super.dispose();
  }
}

void main() {
  const navigatorKey = Key('nestedNavigator');

  testWidgets('FormixController is disposed when navigating away (keepAlive: false)', (tester) async {
    final controller = TestFormixController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Navigator(
            key: navigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => Formix(
                  controller: controller, // Inject our test controller
                  keepAlive: false, // Default behavior
                  child: const SizedBox(),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Initial check: not disposed
    expect(controller.isDisposed, isFalse);

    // Push a new route to simulate navigation
    final navigator = tester.state<NavigatorState>(find.byKey(navigatorKey));
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => const Text('Page B')));

    // Pump to trigger cleanup
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // In the new ownership model, Formix DOES NOT dispose controllers it didn't create.
    // The caller who provided the controller is now responsible for its disposal.
    expect(controller.isDisposed, isFalse);
  });

  testWidgets('FormixController is NOT disposed when navigating away if keepAlive: true (External Controller)', (tester) async {
    final controller = TestFormixController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Navigator(
            key: navigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => Formix(
                  controller: controller,
                  keepAlive: true,
                  child: const SizedBox(),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(controller.isDisposed, isFalse);

    // Navigate away
    final navigator = tester.state<NavigatorState>(find.byKey(navigatorKey));
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => const Text('Page B')));

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // Check if NOT disposed: an externally-owned controller is preserved.
    expect(controller.isDisposed, isFalse);
  });

  testWidgets('Internal FormixController is disposed when navigating away (keepAlive: false)', (tester) async {
    final GlobalKey<FormixState> formKey = GlobalKey<FormixState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Navigator(
            key: navigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => Formix(
                  key: formKey,
                  keepAlive: false,
                  child: const SizedBox(),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Capture the internally-owned controller before navigating away.
    final controller = formKey.currentState?.controller;
    expect(controller, isNotNull);
    expect(controller!.mounted, isTrue);

    // Navigate away
    final navigator = tester.state<NavigatorState>(find.byKey(navigatorKey));
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => const Text('Page B')));

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // The internally-owned controller should have been disposed on unmount.
    expect(controller.mounted, isFalse);
  });

  testWidgets('Internal FormixController is NOT disposed when navigating away if keepAlive: true', (tester) async {
    final GlobalKey<FormixState> formKey = GlobalKey<FormixState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Navigator(
            key: navigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => Formix(
                  key: formKey,
                  keepAlive: true,
                  child: const SizedBox(),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Capture the internally-owned controller before navigating away.
    final controller = formKey.currentState?.controller;
    expect(controller, isNotNull);
    expect(controller!.mounted, isTrue);

    // Navigate away
    final navigator = tester.state<NavigatorState>(find.byKey(navigatorKey));
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => const Text('Page B')));

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // With keepAlive: true the controller should be preserved.
    expect(controller.mounted, isTrue);
  });
}
