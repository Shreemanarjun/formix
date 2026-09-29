import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../enums.dart';
import 'base_form_field.dart';
import 'form_theme.dart';
import '../controllers/validation.dart';

/// A Formix-based text form field that uses Cupertino styling.
class FormixCupertinoTextFormField extends FormixFieldWidget<String> {
  /// Creates a [FormixCupertinoTextFormField].
  const FormixCupertinoTextFormField({
    super.key,
    required super.fieldId,
    super.controller,
    super.validator,
    super.initialValue,
    super.focusNode,
    super.onChanged,
    this.placeholder,
    this.prefix,
    this.padding = const EdgeInsets.all(6.0),
    this.keyboardType,
    this.maxLength,
    this.textInputAction,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.obscureText = false,
    this.style,
    this.loadingIcon,
    this.decoration,
    this.inputFormatters,
    super.enabled = true,
    super.onSaved,
    super.onReset,
    super.forceErrorText,
    super.errorBuilder,
    super.autovalidateMode,
    super.initialValueStrategy,
    super.restorationId,
  });

  /// The placeholder text to show when the field is empty.
  final String? placeholder;

  /// The widget to show before the text input.
  final Widget? prefix;

  /// The padding around the text field.
  final EdgeInsetsGeometry padding;

  /// The type of keyboard to use for editing the text.
  final TextInputType? keyboardType;

  /// The maximum number of characters to allow in the text field.
  final int? maxLength;

  /// The type of action button to use for the keyboard.
  final TextInputAction? textInputAction;

  /// Whether the text field is read-only.
  final bool readOnly;

  /// The maximum number of lines for the text field.
  final int? maxLines;

  /// The minimum number of lines for the text field.
  final int? minLines;

  /// Whether the text field should expand to fill its parent.
  final bool expands;

  /// Whether to hide the text being edited.
  final bool obscureText;

  /// The style to use for the text being edited.
  final TextStyle? style;

  /// Widget to show while validating.
  final Widget? loadingIcon;

  /// Cupertino-specific decoration.
  final BoxDecoration? decoration;

  /// Optional input formatters.
  final List<TextInputFormatter>? inputFormatters;

  @override
  FormixCupertinoTextFormFieldState createState() => FormixCupertinoTextFormFieldState();
}

/// State for [FormixCupertinoTextFormField].
class FormixCupertinoTextFormFieldState extends FormixFieldWidgetState<String> with FormixFieldTextMixin<String> {
  @override
  String valueToString(String? value) => value ?? '';

  @override
  String? stringToValue(String text) => text;

  @override
  Widget build(BuildContext context) {
    final fieldWidget = widget as FormixCupertinoTextFormField;

    // Read the controller's signal slices inside a SignalBuilder so this field
    // rebuilds only when one of the slices it reads changes.
    return SignalBuilder(
      builder: (context) => _buildCupertinoField(
        fieldWidget,
        controller.validationSignal(widget.fieldId).value,
        controller.touchedSignal(widget.fieldId).value,
        controller.dirtySignal(widget.fieldId).value,
        controller.isSubmittingSignal.value,
        controller.getValidationMode(widget.fieldId),
      ),
    );
  }

  Widget _buildCupertinoField(
    FormixCupertinoTextFormField fieldWidget,
    ValidationResult validation,
    bool isTouched,
    bool isDirty,
    bool isSubmitting,
    FormixAutovalidateMode validationMode,
  ) {
    final showImmediate = validationMode == FormixAutovalidateMode.always;
    final shouldShowError = (isTouched || isSubmitting || showImmediate) && !validation.isValid;

    final formTheme = FormixTheme.of(context);

    Widget? suffix;
    if (validation.isValidating) {
      suffix =
          fieldWidget.loadingIcon ??
          (formTheme.enabled ? formTheme.loadingIcon : null) ??
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: CupertinoActivityIndicator(radius: 8),
          );
    } else if (isDirty) {
      suffix =
          (formTheme.enabled ? formTheme.editIcon : null) ??
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(CupertinoIcons.pencil, size: 16),
          );
    }

    return CupertinoFormRow(
      prefix: fieldWidget.prefix,
      padding: fieldWidget.padding,
      error: shouldShowError
          ? (widget.errorBuilder?.call(context, validation.errorMessage!) ??
                Text(
                  validation.errorMessage!,
                  style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                ))
          : null,
      helper: validation.isValidating ? const Text('Validating...', style: TextStyle(fontSize: 13)) : null,
      child: CupertinoTextField(
        controller: textController,
        focusNode: focusNode,
        placeholder: fieldWidget.placeholder,
        keyboardType: fieldWidget.keyboardType,
        maxLength: fieldWidget.maxLength,
        textInputAction: fieldWidget.textInputAction,
        readOnly: fieldWidget.readOnly,
        maxLines: fieldWidget.maxLines,
        minLines: fieldWidget.minLines,
        expands: fieldWidget.expands,
        obscureText: fieldWidget.obscureText,
        style: fieldWidget.style,
        enabled: fieldWidget.enabled,
        onChanged: (val) {
          didChange(val);
        },
        suffix: suffix,
        decoration: fieldWidget.decoration,
        inputFormatters: [
          ...?controller.getField(widget.fieldId)?.inputFormatters,
          ...?fieldWidget.inputFormatters,
        ],
      ),
    );
  }
}
