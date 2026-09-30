import 'package:flutter/widgets.dart';
import '../../formix.dart';

/// A utility class to validate the presence of a [Formix] ancestor.
class FormixAncestorValidator {
  /// Validates that a [Formix] ancestor (or an explicit controller) is available.
  ///
  /// Returns a [FormixConfigurationErrorWidget] if a required ancestor is
  /// missing, otherwise returns null.
  static Widget? validate(
    BuildContext context, {
    required String widgetName,
    FormixController? explicitController,
    bool hasExplicitController = false,
    bool requireFormix = true,
  }) {
    if (!requireFormix || hasExplicitController || explicitController != null) {
      return null;
    }

    final controller = Formix.maybeOf(context);
    if (controller == null) {
      return FormixConfigurationErrorWidget(
        message: 'Missing Formix Ancestor',
        details: '$widgetName must be used inside a Formix widget.\n\nExample:\nFormix(\n  child: $widgetName(...),\n)',
      );
    }

    return null;
  }
}
