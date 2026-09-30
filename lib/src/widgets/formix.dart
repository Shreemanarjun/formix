import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../analytics/form_analytics.dart';
import '../controllers/formix_base_controller.dart';
import '../persistence/form_persistence.dart';
import '../enums.dart';
import '../i18n.dart';
import 'form_theme.dart';

/// A form container widget that owns a [FormixController] and provides it to
/// descendant widgets via an [InheritedWidget].
///
/// Features:
/// *   **State Management**: Holds a single signal-backed [FormixController].
/// *   **Auto-Registration**: Fields register themselves with the controller on mount.
/// *   **Persistence**: Can automatically save and restore form state.
/// *   **Validation**: Supports global and per-field validation configurations.
/// *   **Analytics**: Integrated hooks for tracking form interactions.
///
/// No `ProviderScope` is required — Formix is self-contained.
///
/// Example:
/// ```dart
/// Formix(
///   initialValue: {'email': 'test@example.com'},
///   onChanged: (values) => print('Form changed: $values'),
///   child: Column(
///     children: [
///       FormixTextFormField(fieldId: FormixFieldID('email')),
///       ElevatedButton(
///         onPressed: () => Formix.controllerOf(context)?.submit(
///           onValid: (data) => print('Success: $data'),
///         ),
///         child: Text('Submit'),
///       ),
///     ],
///   ),
/// )
/// ```
class Formix extends StatefulWidget {
  /// Creates a [Formix].
  const Formix({
    super.key,
    this.controller,
    this.initialValue = const {},
    this.fields = const [],
    this.persistence,
    this.formId,
    this.onChanged,
    this.onChangedData,
    this.analytics,
    this.keepAlive = false,
    this.autovalidateMode = FormixAutovalidateMode.always,
    this.theme,
    this.initialData,
    this.messages,
    required this.child,
  });

  /// Optional explicit controller. When provided, [Formix] does not own its
  /// lifecycle (it will not dispose it).
  final FormixController? controller;

  /// Optional analytics hook
  final FormixAnalytics? analytics;

  /// initial values for the form fields.
  final Map<String, dynamic> initialValue;

  /// Configuration for the fields in this form.
  final List<FormixFieldConfig<dynamic>> fields;

  /// Optional persistence handler.
  final FormixPersistence? persistence;

  /// Unique identifier for this form (required for persistence).
  final String? formId;

  /// Callback triggered whenever any value in the form changes.
  final void Function(Map<String, dynamic> values)? onChanged;

  /// Callback triggered whenever the entire form data changes.
  final void Function(FormixData data)? onChangedData;

  /// If true, keeps this form's state alive when it is inside a paging widget
  /// such as [TabBarView] or [PageView] (via [AutomaticKeepAliveClientMixin]).
  final bool keepAlive;

  /// The autovalidate mode for the form.
  final FormixAutovalidateMode autovalidateMode;

  /// Optional visual theme for the form fields.
  final FormixThemeData? theme;

  /// Optional initial state for the form.
  final FormixData? initialData;

  /// Optional custom messages for validation errors.
  final FormixMessages? messages;

  /// The widget subtree.
  final Widget child;

  @override
  State<Formix> createState() => FormixState();

  /// Get the [FormixController] from the nearest [Formix] ancestor, or null.
  static FormixController? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FormixControllerScope>();
    return scope?.controller;
  }

  /// Get the [FormixController] instance from the nearest [Formix] ancestor.
  static FormixController? controllerOf(BuildContext context) => of(context);
}

/// State for [Formix], allowing external control via [GlobalKey].
///
/// Uses [AutomaticKeepAliveClientMixin] so that when [Formix] is placed inside
/// a [TabBarView], [PageView], or similar paging widget, its controller is kept
/// alive rather than being disposed mid-frame.
class FormixState extends State<Formix> with AutomaticKeepAliveClientMixin {
  late final String _internalFormId;
  late FormixController _controller;
  bool _ownsController = false;
  VoidCallback? _removeChangeListener;

  @override
  void initState() {
    super.initState();
    final typeName = widget.runtimeType.toString();
    _internalFormId = widget.formId ?? '${typeName}_${identityHashCode(this)}';
    _controller = _resolveController();
    _wireCallbacks();
  }

  FormixParameter _createParameter() {
    return FormixParameter(
      initialValue: widget.initialValue,
      fields: widget.fields,
      persistence: widget.persistence,
      formId: widget.formId,
      namespace: _internalFormId,
      analytics: widget.analytics,
      keepAlive: widget.keepAlive,
      autovalidateMode: widget.autovalidateMode,
      initialData: widget.initialData,
      messages: widget.messages,
    );
  }

  FormixController _resolveController() {
    final external = widget.controller;
    if (external != null) {
      _ownsController = false;
      // Register this form's fields onto the externally-owned controller.
      if (widget.fields.isNotEmpty) {
        external.registerFields(widget.fields.map((f) => f.toField()).toList());
      }
      if (widget.messages != null) external.updateMessages(widget.messages);
      return external;
    }
    _ownsController = true;
    return FormixController.fromParameter(_createParameter());
  }

  void _wireCallbacks() {
    if (widget.onChanged == null && widget.onChangedData == null) return;
    var previous = _controller.state;
    _removeChangeListener = _controller.addFormListener((next) {
      if (widget.onChangedData != null && previous != next) {
        widget.onChangedData!(next);
      }
      if (widget.onChanged != null && !const MapEquality().equals(previous.values, next.values)) {
        widget.onChanged!(next.values);
      }
      previous = next;
    });
  }

  @override
  void didUpdateWidget(Formix oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.keepAlive != oldWidget.keepAlive) {
      updateKeepAlive();
    }

    // Swap controllers if the external controller identity changed.
    if (widget.controller != oldWidget.controller) {
      _removeChangeListener?.call();
      if (_ownsController) _controller.dispose();
      _controller = _resolveController();
      _wireCallbacks();
      return;
    }

    if (widget.messages != oldWidget.messages) {
      _controller.updateMessages(widget.messages);
    }

    if (!const ListEquality().equals(widget.fields, oldWidget.fields)) {
      _controller.registerFields(widget.fields.map((f) => f.toField()).toList());
    }
  }

  @override
  void dispose() {
    _removeChangeListener?.call();
    // Dispose only a controller we own. With keepAlive, ownership transfers to
    // the caller (retain it via a GlobalKey/controller ref) so its state
    // survives this widget being unmounted (e.g. navigating away).
    if (_ownsController && !widget.keepAlive) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// Access the controller to perform actions like `submit` or `reset`.
  FormixController get controller => _controller;

  /// Access the current immutable state of the form.
  ///
  /// Note: This is a snapshot. To watch state reactively, use [FormixBuilder].
  FormixData get data => _controller.state;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin.
    super.build(context);

    final content = _FormixControllerScope(
      controller: _controller,
      fields: widget.fields,
      child: widget.child,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.form,
      child: widget.theme != null ? FormixTheme(data: widget.theme!, child: content) : content,
    );
  }
}

/// [InheritedWidget] that exposes the current [FormixController] to descendants.
///
/// Prefer [Formix.of] / [Formix.controllerOf] to read it.
class _FormixControllerScope extends InheritedWidget {
  const _FormixControllerScope({
    required super.child,
    required this.controller,
    this.fields = const [],
  });

  final FormixController controller;
  final List<FormixFieldConfig<dynamic>> fields;

  @override
  bool updateShouldNotify(_FormixControllerScope oldWidget) {
    return controller != oldWidget.controller || !const ListEquality().equals(fields, oldWidget.fields);
  }
}
