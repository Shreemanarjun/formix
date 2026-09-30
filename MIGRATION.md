# Migrating to formix 0.2.0 (Riverpod → Signals)

formix 0.2.0 replaces its Riverpod core with [signals](https://pub.dev/packages/signals_flutter).
The form logic, validation, widgets, and public widget API are unchanged — but the
reactivity engine and a few integration points changed. This is a breaking release.

## TL;DR

| Before (0.1.x, Riverpod)                                   | After (0.2.0, Signals)                                              |
| ---------------------------------------------------------- | ------------------------------------------------------------------ |
| Wrap app in `ProviderScope`                                | **Nothing** — `Formix` is self-contained                           |
| `flutter_riverpod` re-exported from `package:formix`       | removed — import `package:signals_flutter/...` yourself if needed  |
| `Formix.controllerOf(context)` → controller               | unchanged (still returns the `FormixController`)                   |
| `formControllerProvider(param)` + `container.read(...)`    | `FormixController.fromParameter(param)` (construct directly)        |
| `RiverpodFormController`                                   | `FormixBaseController` (base of `FormixController`)                 |
| `ref.watch(fieldValueProvider(id))`                        | `controller.valueSignal(id).value` inside a `SignalBuilder`        |
| `formixMessagesProvider` override                          | `formixGlobalMessages.value = MyMessages()`                        |

## 1. Remove `ProviderScope`

```dart
// before
void main() => runApp(ProviderScope(child: MyApp()));
// after
void main() => runApp(const MyApp());
```

`Formix` no longer requires (or uses) a `ProviderScope`. Remove `flutter_riverpod`
from your `pubspec.yaml` if you only had it for formix.

## 2. Reading form state reactively

The widget-facing API is unchanged. `FormixBuilder` still works:

```dart
FormixBuilder(
  builder: (context, scope) {
    final email = scope.watchValue(emailField);     // rebuilds only when email changes
    final isValid = scope.watchIsValid;
    return Text('$email / $isValid');
  },
)
```

If you watched providers directly, use the controller's signal slices instead — read
`.value` inside a `SignalBuilder` for surgical rebuilds:

```dart
// before
final email = ref.watch(fieldValueProvider(emailField));
// after
final controller = Formix.controllerOf(context)!;
SignalBuilder(builder: (context) => Text('${controller.valueSignal(emailField).value}'));
```

Slice map: `fieldValueProvider`→`valueSignal`, `fieldValidationProvider`→`validationSignal`,
`fieldErrorProvider`→`validationSignal(id).value.errorMessage`, `fieldDirtyProvider`→`dirtySignal`,
`fieldTouchedProvider`→`touchedSignal`, `fieldPendingProvider`→`pendingSignal`,
`formValidProvider`→`isValidSignal`, `formDirtyProvider`→`isDirtySignal`,
`formSubmittingProvider`→`isSubmittingSignal`, `formCurrentStepProvider`→`currentStepSignal`,
`groupValidProvider`→`groupValidSignal`, `groupDirtyProvider`→`groupDirtySignal`.

## 3. Getting a controller outside the widget tree

```dart
// before
final controller = container.read(formControllerProvider(param).notifier);
// after
final controller = FormixController.fromParameter(param); // or FormixController(...)
// ...remember to dispose it when done: controller.dispose();
```

In widget tests, attach a `GlobalKey<FormixState>` to `Formix` and read
`formKey.currentState!.controller`.

## 4. Custom validation messages / localization

```dart
// before: ProviderScope(overrides: [formixMessagesProvider.overrideWithValue(FrMessages())])
// after:
formixGlobalMessages.value = FrMessages(); // all forms re-validate reactively
```

Per-form override is unchanged: `Formix(messages: FrMessages())` /
`FormixController(messages: FrMessages())`.

## 5. Renamed / removed symbols

- `RiverpodFormController` → `FormixBaseController`.
- Removed: all `*Provider` globals (`formControllerProvider`, `currentControllerProvider`,
  `fieldValueProvider`, `fieldValidationProvider`, `fieldErrorProvider`, `fieldValidatingProvider`,
  `fieldIsValidProvider`, `fieldDirtyProvider`, `fieldTouchedProvider`, `fieldPendingProvider`,
  `formValidProvider`, `formDirtyProvider`, `formSubmittingProvider`, `formCurrentStepProvider`,
  `formDataProvider`, `groupValidProvider`, `groupDirtyProvider`, `fieldValidationModeProvider`,
  `formixMessagesProvider`) and `FormixParameter`-keyed family plumbing.
- `FormixAsyncField.asyncValue` now takes `AsyncState<T>?` (from signals) instead of Riverpod's `AsyncValue<T>`.

Everything else — `FormixFieldID`, `FormixField`, `FormixController`, `Formix`,
`FormixTextFormField`, `FormixValidators`, `FormixArray`, `FormixSection`, `FormixListener`,
undo/redo, persistence, analytics, i18n, headless widgets — keeps the same API.
