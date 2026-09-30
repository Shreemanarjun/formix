import 'package:formix/src/controllers/field_id.dart';
import 'package:formix/src/controllers/formix_base_controller.dart';
import 'package:formix/src/widgets/field_selector.dart';
import 'package:formix/src/widgets/field_selector/formix_field_selector.dart';
import 'package:flutter/material.dart';

/// A widget that shows performance metrics for field rebuilding
class FormixFieldPerformanceMonitor<T> extends StatefulWidget {
  /// Creates a [FormixFieldPerformanceMonitor].
  const FormixFieldPerformanceMonitor({
    super.key,
    required this.fieldId,
    required this.builder,
    this.controller,
  });

  /// The ID of the field to monitor.
  final FormixFieldID<T> fieldId;

  /// Builder function that returns the widget tree and rebuild count.
  final Widget Function(
    BuildContext context,
    FieldChangeInfo<T> info,
    int rebuildCount,
  )
  builder;

  /// Optional controller.
  final FormixController? controller;

  @override
  State<FormixFieldPerformanceMonitor<T>> createState() => _FormixFieldPerformanceMonitorState<T>();
}

class _FormixFieldPerformanceMonitorState<T> extends State<FormixFieldPerformanceMonitor<T>> {
  int _rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    return FormixFieldSelector<T>(
      fieldId: widget.fieldId,
      controller: widget.controller,
      builder: (context, info, child) {
        _rebuildCount++;
        return widget.builder(context, info, _rebuildCount);
      },
    );
  }
}
