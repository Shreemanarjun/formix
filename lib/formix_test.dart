/// Test utilities for `formix`.
///
/// Import this ONLY from test files:
/// ```dart
/// import 'package:formix/formix_test.dart';
/// ```
/// It depends on `flutter_test`, so it is a separate entry point and is not
/// re-exported by `package:formix/formix.dart` (keeping `flutter_test` out of
/// your production dependency graph).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

/// Pumps [child] inside a `MaterialApp` + `Formix` and returns the resolved
/// [FormixController], removing the boilerplate from widget tests.
///
/// By default it pumps one extra frame so declaratively-declared fields have
/// registered before you assert (`settle: false` to skip). Pass an existing
/// [controller] to drive the form externally.
///
/// ```dart
/// final c = await pumpFormix(tester,
///   child: FormixTextFormField(fieldId: emailField),
/// );
/// c.setValue(emailField, 'a@b.com');
/// ```
Future<FormixController> pumpFormix(
  WidgetTester tester, {
  required Widget child,
  FormixController? controller,
  Map<String, dynamic> initialValue = const {},
  List<FormixFieldConfig<dynamic>> fields = const [],
  FormixMessages? messages,
  FormixAutovalidateMode autovalidateMode = FormixAutovalidateMode.always,
  ThemeData? theme,
  bool settle = true,
}) async {
  final key = GlobalKey<FormixState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Formix(
          key: key,
          controller: controller,
          initialValue: initialValue,
          fields: fields,
          messages: messages,
          autovalidateMode: autovalidateMode,
          child: child,
        ),
      ),
    ),
  );
  if (settle) await tester.pump();
  return key.currentState!.controller;
}

/// Counts how many times its wrapped subtree rebuilds — the essential tool for
/// asserting Formix's surgical-rebuild behaviour.
///
/// ```dart
/// final counter = RebuildCounter();
/// await pumpFormix(tester, child: FormixBuilder(
///   builder: (context, scope) => counter.wrap(() => Text('${scope.watchValue(id)}')),
/// ));
/// // ... change an unrelated field ...
/// expect(counter, rebuiltExactly(1));
/// ```
class RebuildCounter {
  /// Number of times [wrap]'s builder has run since creation (or last [reset]).
  int count = 0;

  /// Wraps [builder] in a [Builder] that increments [count] on every build.
  Widget wrap(WidgetBuilder builder) {
    return Builder(
      builder: (context) {
        count++;
        return builder(context);
      },
    );
  }

  /// Resets [count] to zero.
  void reset() => count = 0;

  @override
  String toString() => 'RebuildCounter(count: $count)';
}

/// Matches a [RebuildCounter] (or a raw `int`) whose rebuild count equals [n].
Matcher rebuiltExactly(int n) => _RebuiltMatcher(n, exact: true);

/// Matches a [RebuildCounter] (or a raw `int`) whose rebuild count is at most [n].
Matcher rebuiltAtMost(int n) => _RebuiltMatcher(n, exact: false);

class _RebuiltMatcher extends Matcher {
  const _RebuiltMatcher(this.n, {required this.exact});
  final int n;
  final bool exact;

  int? _countOf(dynamic item) {
    if (item is RebuildCounter) return item.count;
    if (item is int) return item;
    return null;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    final c = _countOf(item);
    if (c == null) return false;
    return exact ? c == n : c <= n;
  }

  @override
  Description describe(Description description) => description.add(exact ? 'rebuilt exactly $n time(s)' : 'rebuilt at most $n time(s)');

  @override
  Description describeMismatch(dynamic item, Description mismatch, Map matchState, bool verbose) {
    final c = _countOf(item);
    if (c == null) return mismatch.add('was not a RebuildCounter or int');
    return mismatch.add('rebuilt $c time(s)');
  }
}
