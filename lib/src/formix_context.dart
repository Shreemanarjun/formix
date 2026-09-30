import 'package:flutter/widgets.dart';
import 'controllers/formix_controller.dart';
import 'widgets/formix.dart';

/// Ergonomic [BuildContext] access to the nearest [Formix].
///
/// ```dart
/// onPressed: () => context.formix.submit(onValid: save);
/// final email = context.maybeFormix?.getValue(emailField);
/// ```
extension FormixContext on BuildContext {
  /// The nearest [FormixController]. Throws if there is no [Formix] ancestor
  /// (see [Formix.of]). Use [maybeFormix] when a form may be absent.
  FormixController get formix => Formix.of(this);

  /// The nearest [FormixController], or null if there is no [Formix] ancestor.
  FormixController? get maybeFormix => Formix.maybeOf(this);
}
