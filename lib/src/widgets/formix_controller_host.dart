import 'package:flutter/widgets.dart';
import 'formix.dart';
import 'formix_errors.dart';
import '../controllers/formix_controller.dart';

/// Shared boilerplate for stateful widgets that need a [FormixController].
///
/// Mix this into a [State] to get, for free:
/// * controller resolution — an [explicitController] if the widget provides one,
///   otherwise the nearest [Formix] ancestor via [Formix.controllerOf];
/// * re-resolution in [didChangeDependencies] with an [onControllerChanged] hook;
/// * a consistent configuration-error widget via [formixErrorOrNull].
///
/// This removes the controller-lookup + error-widget code that would otherwise
/// be copy-pasted across every "logic" widget (transformers, derivations,
/// dependent fields, sections, registries, listeners).
mixin FormixControllerHost<W extends StatefulWidget> on State<W> {
  FormixController? _controller;

  /// The resolved controller. Only call when [hasController] is true.
  FormixController get controller => _controller!;

  /// Whether a controller has been resolved.
  bool get hasController => _controller != null;

  /// Override to supply an explicit controller (e.g. `widget.controller`).
  /// Return null to always resolve from the nearest [Formix] ancestor.
  FormixController? get explicitController => null;

  /// A human-readable name for this widget, used in error messages.
  String get formixWidgetName;

  /// Called when a (new, non-null) controller is attached — including the first
  /// resolution and whenever the ancestor/explicit controller changes. Wire
  /// effects and listeners here.
  void onControllerChanged(FormixController controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveController();
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pick up a changed [explicitController] (e.g. widget.controller swapped).
    _resolveController();
  }

  void _resolveController() {
    final next = explicitController ?? Formix.controllerOf(context);
    if (identical(next, _controller)) return;
    _controller = next;
    if (next != null) onControllerChanged(next);
  }

  /// Returns a [FormixConfigurationErrorWidget] if no controller is available,
  /// otherwise null. Call at the top of `build`.
  Widget? formixErrorOrNull() {
    if (_controller != null) return null;
    return FormixConfigurationErrorWidget(
      message: 'Failed to initialize $formixWidgetName',
      details: '$formixWidgetName must be used inside a Formix widget or given an explicit controller.',
    );
  }
}
