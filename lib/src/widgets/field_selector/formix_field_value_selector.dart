import 'package:formix/src/controllers/field_id.dart';
import 'package:formix/src/controllers/formix_base_controller.dart';
import 'package:formix/src/widgets/field_selector/formix_field_selector.dart';
import 'package:flutter/material.dart';

/// A simplified version that only listens to value changes
class FormixFieldValueSelector<T> extends StatelessWidget {
  /// Creates a [FormixFieldValueSelector].
  const FormixFieldValueSelector({
    super.key,
    required this.fieldId,
    required this.builder,
    this.controller,
    this.select,
    this.child,
  });

  /// The ID of the field to listen to.
  final FormixFieldID<T> fieldId;

  /// Builder function that returns the widget tree based on the field value.
  final Widget Function(BuildContext context, T? value, Widget? child) builder;

  /// Optional controller. If not provided, it will be looked up in the context.
  final FormixController? controller;

  /// Optional child widget that is passed to the builder.
  final Widget? child;

  /// Optional selector to pick a specific part of the field value.
  final Object? Function(T? value)? select;

  @override
  Widget build(BuildContext context) {
    return FormixFieldSelector<T>(
      fieldId: fieldId,
      controller: controller,
      listenToValue: true,
      listenToValidation: false,
      listenToDirty: false,
      select: select,
      builder: (context, info, child) => builder(context, info.value, child),
      child: child,
    );
  }
}
