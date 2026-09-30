import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'base_form_field.dart';
import '../enums.dart';
import 'form_theme.dart';
import 'ancestor_validator.dart';

/// A Formix-based text form field that is lifecycle aware.
class FormixTextFormField extends FormixFieldWidget<String> {
  /// Creates a [FormixTextFormField].
  const FormixTextFormField({
    super.key,
    required super.fieldId,
    super.controller,
    super.validator,
    super.initialValue,
    super.focusNode,
    super.onChanged,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.textInputAction,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.obscureText = false,
    this.style,
    this.loadingIcon,
    super.enabled = true,
    super.onSaved,
    super.onReset,
    super.forceErrorText,
    super.errorBuilder,
    super.autovalidateMode,
    super.initialValueStrategy,
    super.restorationId,
    this.autocorrect = true,
    this.autofillHints,
    this.autofocus = false,
    this.buildCounter,
    this.cursorColor,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorWidth = 2.0,
    this.enableInteractiveSelection = true,
    this.enableSuggestions = true,
    this.keyboardAppearance,
    this.maxLengthEnforcement,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.scrollController,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.scrollPhysics,
    this.selectionControls,
    this.showCursor,
    this.smartDashesType,
    this.smartQuotesType,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
    this.mouseCursor,
  });

  /// The decoration to show around the text field.
  final InputDecoration decoration;

  /// The type of keyboard to use for editing the text.
  final TextInputType? keyboardType;

  /// The maximum number of characters to allow in the text field.
  final int? maxLength;

  /// Optional input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// The type of action button to use for the keyboard.
  final TextInputAction? textInputAction;

  /// Callback when the user finishes editing.
  final void Function(String)? onFieldSubmitted;

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

  /// Whether to enable autocorrect.
  final bool autocorrect;

  /// Autofill hints for the text field.
  final Iterable<String>? autofillHints;

  /// Whether to autofocus this field.
  final bool autofocus;

  /// Custom builder for the counter.
  final InputCounterWidgetBuilder? buildCounter;

  /// The color of the cursor.
  final Color? cursorColor;

  /// The height of the cursor.
  final double? cursorHeight;

  /// The radius of the cursor corners.
  final Radius? cursorRadius;

  /// The width of the cursor.
  final double cursorWidth;

  /// Whether to enable interactive selection.
  final bool enableInteractiveSelection;

  /// Whether to show suggestions.
  final bool enableSuggestions;

  /// The appearance of the keyboard.
  final Brightness? keyboardAppearance;

  /// Strategy for enforcing the maximum length.
  final MaxLengthEnforcement? maxLengthEnforcement;

  /// Callback when editing is complete.
  final VoidCallback? onEditingComplete;

  /// Callback when the field is tapped.
  final GestureTapCallback? onTap;

  /// Callback when the user taps outside.
  final TapRegionCallback? onTapOutside;

  /// Optional scroll controller.
  final ScrollController? scrollController;

  /// Padding around the text field when scrolling into view.
  final EdgeInsets scrollPadding;

  /// Physics for the scrollable.
  final ScrollPhysics? scrollPhysics;

  /// Custom selection controls.
  final TextSelectionControls? selectionControls;

  /// Whether to show the cursor.
  final bool? showCursor;

  /// Type of smart dashes to use.
  final SmartDashesType? smartDashesType;

  /// Type of smart quotes to use.
  final SmartQuotesType? smartQuotesType;

  /// Strut style for the text.
  final StrutStyle? strutStyle;

  /// Alignment of the text.
  final TextAlign textAlign;

  /// Vertical alignment of the text.
  final TextAlignVertical? textAlignVertical;

  /// Capitalization strategy for the text.
  final TextCapitalization textCapitalization;

  /// Directionality of the text.
  final TextDirection? textDirection;

  /// The mouse cursor to use.
  final MouseCursor? mouseCursor;

  @override
  FormixTextFormFieldState createState() => FormixTextFormFieldState();
}

/// State for [FormixTextFormField].
class FormixTextFormFieldState extends FormixFieldWidgetState<String> with FormixFieldTextMixin<String> {
  // Cache for InputDecoration to avoid rebuilding on every frame
  InputDecoration? _cachedBaseDecoration;
  InputDecoration? _lastWidgetDecoration;
  FormixThemeData? _lastFormTheme;
  InputDecorationTheme? _lastDecorationTheme;

  // Cache for suffix icon to avoid rebuilding
  Widget? _cachedSuffixIcon;
  bool _lastIsDirty = false;
  bool _lastIsValidating = false;

  // Cache for final decoration
  InputDecoration? _cachedEffectiveDecoration;
  String? _lastErrorText;
  Widget? _lastSuffixIcon;
  String? _lastHelperText;

  // Cache for formatters
  List<TextInputFormatter>? _cachedFormatters;
  List<TextInputFormatter>? _lastFieldFormatters;
  List<TextInputFormatter>? _lastWidgetFormatters;

  @override
  String valueToString(String? value) => value ?? '';

  @override
  String? stringToValue(String text) => text;

  Widget? _getSuffixIcon(bool isDirty, bool isValidating, FormixThemeData formTheme, FormixTextFormField fieldWidget) {
    if (_lastIsDirty == isDirty && _lastIsValidating == isValidating) {
      return _cachedSuffixIcon;
    }

    _lastIsDirty = isDirty;
    _lastIsValidating = isValidating;

    if (isValidating) {
      _cachedSuffixIcon =
          fieldWidget.loadingIcon ??
          (formTheme.enabled ? formTheme.loadingIcon : null) ??
          const SizedBox(
            width: 16,
            height: 16,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    } else if (isDirty) {
      _cachedSuffixIcon = (formTheme.enabled ? formTheme.editIcon : null) ?? const Icon(Icons.edit, size: 16);
    } else {
      _cachedSuffixIcon = null;
    }

    return _cachedSuffixIcon;
  }

  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'FormixTextFormField',
      requireFormix: true,
      hasExplicitController: widget.controller != null,
    );
    if (errorWidget != null) return errorWidget;

    final fieldWidget = widget as FormixTextFormField;

    // Reactive enabled/readOnly via the controller's signals; validation/touched/
    // dirty/submitting via the combined field-state notifier.
    return SignalBuilder(
      builder: (context) {
        final effEnabled = effectiveEnabled;
        final effReadOnly = fieldWidget.readOnly || effectiveReadOnly;
        return AnimatedBuilder(
          animation: controller.getFieldStateNotifier(widget.fieldId),
          builder: (context, _) {
            final validation = this.validation;
            final isTouched = this.isTouched;
            final isDirty = this.isDirty;
            final isSubmitting = controller.isSubmitting;
            final validationMode = controller.getValidationMode(widget.fieldId);

            final showImmediate = validationMode == FormixAutovalidateMode.always;

            final shouldShowError = (isTouched || isSubmitting || showImmediate) && !validation.isValid;

            final formTheme = FormixTheme.of(context);

            // Cache base decoration to avoid repeated theme resolution
            if (_cachedBaseDecoration == null ||
                fieldWidget.decoration != _lastWidgetDecoration ||
                formTheme != _lastFormTheme ||
                (formTheme.enabled && formTheme.decorationTheme != _lastDecorationTheme)) {
              _lastWidgetDecoration = fieldWidget.decoration;
              _lastFormTheme = formTheme;
              _lastDecorationTheme = formTheme.decorationTheme;

              _cachedBaseDecoration = formTheme.enabled
                  ? fieldWidget.decoration.applyDefaults(
                      formTheme.decorationTheme ?? Theme.of(context).inputDecorationTheme,
                    )
                  : fieldWidget.decoration;

              // Invalidate effective decoration cache when base changes
              _cachedEffectiveDecoration = null;
            }

            final suffixIcon = _getSuffixIcon(isDirty, validation.isValidating, formTheme, fieldWidget);

            // Cache formatters list
            final fieldFormatters = controller.getField(widget.fieldId)?.inputFormatters;
            final widgetFormatters = fieldWidget.inputFormatters;

            if (_cachedFormatters == null || fieldFormatters != _lastFieldFormatters || widgetFormatters != _lastWidgetFormatters) {
              _lastFieldFormatters = fieldFormatters;
              _lastWidgetFormatters = widgetFormatters;
              _cachedFormatters = [
                ...?fieldFormatters,
                ...?widgetFormatters,
              ];
            }

            // Cache effective decoration
            final errorText = shouldShowError ? validation.errorMessage : null;
            final helperText = validation.isValidating ? 'Validating...' : null;

            if (_cachedEffectiveDecoration == null || errorText != _lastErrorText || suffixIcon != _lastSuffixIcon || helperText != _lastHelperText) {
              _lastErrorText = errorText;
              _lastSuffixIcon = suffixIcon;
              _lastHelperText = helperText;

              _cachedEffectiveDecoration = _cachedBaseDecoration!.copyWith(
                errorText: errorText,
                suffixIcon: suffixIcon,
                helperText: helperText,
              );
            }

            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              decoration: _cachedEffectiveDecoration,
              mouseCursor: fieldWidget.mouseCursor ?? (effReadOnly ? SystemMouseCursors.basic : null),
              keyboardType: fieldWidget.keyboardType,
              maxLength: fieldWidget.maxLength,
              inputFormatters: _cachedFormatters,
              textInputAction: fieldWidget.textInputAction,
              onFieldSubmitted: (val) {
                fieldWidget.onFieldSubmitted?.call(val);
              },
              readOnly: effReadOnly,
              maxLines: fieldWidget.maxLines,
              minLines: fieldWidget.minLines,
              expands: fieldWidget.expands,
              obscureText: fieldWidget.obscureText,
              style: fieldWidget.style,
              enabled: effEnabled,
              autocorrect: fieldWidget.autocorrect,
              autofillHints: fieldWidget.autofillHints,
              autofocus: fieldWidget.autofocus,
              buildCounter: fieldWidget.buildCounter,
              cursorColor: fieldWidget.cursorColor,
              cursorHeight: fieldWidget.cursorHeight,
              cursorRadius: fieldWidget.cursorRadius,
              cursorWidth: fieldWidget.cursorWidth,
              enableInteractiveSelection: fieldWidget.enableInteractiveSelection,
              enableSuggestions: fieldWidget.enableSuggestions,
              keyboardAppearance: fieldWidget.keyboardAppearance,
              maxLengthEnforcement: fieldWidget.maxLengthEnforcement,
              onChanged: (val) {
                didChange(val);
              },
              onEditingComplete: fieldWidget.onEditingComplete,
              onTap: fieldWidget.onTap,
              onTapOutside: fieldWidget.onTapOutside,
              scrollController: fieldWidget.scrollController,
              scrollPadding: fieldWidget.scrollPadding,
              scrollPhysics: fieldWidget.scrollPhysics,
              selectionControls: fieldWidget.selectionControls,
              showCursor: fieldWidget.showCursor,
              smartDashesType: fieldWidget.smartDashesType,
              smartQuotesType: fieldWidget.smartQuotesType,
              strutStyle: fieldWidget.strutStyle,
              textAlign: fieldWidget.textAlign,
              textAlignVertical: fieldWidget.textAlignVertical,
              textCapitalization: fieldWidget.textCapitalization,
              textDirection: fieldWidget.textDirection,
              restorationId: fieldWidget.restorationId,
            );
          },
        );
      },
    );
  }
}
