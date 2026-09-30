import 'package:formix/src/controllers/field_id.dart';
import 'package:formix/src/controllers/formix_base_controller.dart';
import 'package:formix/src/widgets/field_selector.dart';
import 'package:formix/src/widgets/field_selector/formix_field_selector.dart';
import 'package:flutter/material.dart';

/// A widget that provides granular listening control with custom conditions
class FormixFieldConditionalSelector<T> extends StatelessWidget {
  /// Creates a [FormixFieldConditionalSelector].
  const FormixFieldConditionalSelector({
    super.key,
    required this.fieldId,
    required this.builder,
    required this.shouldRebuild,
    this.controller,
    this.child,
  });

  /// The ID of the field to listen to.
  final FormixFieldID<T> fieldId;

  /// Builder function that returns the widget tree.
  final Widget Function(
    BuildContext context,
    FieldChangeInfo<T> info,
    Widget? child,
  )
  builder;

  /// Custom condition function that determines if the widget should rebuild.
  final bool Function(FieldChangeInfo<T> info) shouldRebuild;

  /// Optional controller. If not provided, it will be looked up in the context.
  final FormixController? controller;

  /// Optional child widget that is passed to the builder.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return FormixFieldSelector<T>(
      fieldId: fieldId,
      controller: controller,
      builder: (context, info, child) {
        // Only rebuild if the condition is met
        if (shouldRebuild(info)) {
          return builder(context, info, child);
        }
        // Return a placeholder that doesn't rebuild
        return child ?? const SizedBox.shrink();
      },
      child: child,
    );
  }
}
