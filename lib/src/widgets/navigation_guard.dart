import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'formix.dart';
import 'formix_errors.dart';

/// A widget that prevents navigation if the form is dirty.
///
/// This widget wraps [PopScope] and checks the form's dirty state before allowing
/// a pop action. If the form is dirty, it can show a confirmation dialog.
class FormixNavigationGuard extends StatefulWidget {
  /// The child widget.
  final Widget child;

  /// Whether to enable the guard. Defaults to true.
  final bool enabled;

  /// Callback to execute when a pop is attempted while the form is dirty.
  ///
  /// Should return `true` to allow the pop, or `false` to prevent it.
  /// If null, [showDirtyDialog] is used by default.
  final Future<bool> Function(BuildContext context)? onDirtyPop;

  /// Custom implementation for showing a dirty dialog.
  ///
  /// If provided, this replaces the default dialog.
  /// Should return `true` if the user confirms discarding changes.
  final Future<bool> Function(BuildContext context)? showDirtyDialog;

  /// Creates a [FormixNavigationGuard].
  const FormixNavigationGuard({
    super.key,
    required this.child,
    this.enabled = true,
    this.onDirtyPop,
    this.showDirtyDialog,
  });

  @override
  State<FormixNavigationGuard> createState() => _FormixNavigationGuardState();
}

class _FormixNavigationGuardState extends State<FormixNavigationGuard> {
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final controller = Formix.controllerOf(context);
    if (controller == null) {
      return const FormixConfigurationErrorWidget(
        message: 'FormixNavigationGuard used without a Formix ancestor',
        details: 'FormixNavigationGuard must be used inside a Formix widget.',
      );
    }

    // Rebuild the PopScope only when the form's dirty state changes.
    return SignalBuilder(
      builder: (context) {
        final isDirty = controller.isDirtySignal.value;
        return PopScope(
          canPop: _isExiting || !isDirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            final shouldPop = await _handleDirtyPop(context);
            if (shouldPop && context.mounted) {
              setState(() {
                _isExiting = true;
              });
              // Use a microtask to ensure the state update is processed before the next pop
              Future.microtask(() {
                if (context.mounted) {
                  Navigator.of(context).pop(result);
                }
              });
            }
          },
          child: widget.child,
        );
      },
    );
  }

  Future<bool> _handleDirtyPop(BuildContext context) async {
    if (widget.onDirtyPop != null) {
      return widget.onDirtyPop!(context);
    }
    return (widget.showDirtyDialog ?? showDefaultDirtyDialog)(context);
  }

  /// Shows a default platform-adaptive dialog asking to discard changes.
  static Future<bool> showDefaultDirtyDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to leave?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
