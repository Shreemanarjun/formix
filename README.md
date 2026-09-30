<p align="center">
  <img src="https://zmozkivkhopoeutpnnum.supabase.co/storage/v1/object/public/images/formix_banner.svg" alt="Formix Logo" />
</p>



**An elite, type-safe, and ultra-reactive form engine for Flutter.**

Powered by **[Signals](https://pub.dev/packages/signals_flutter)**, Formix delivers lightning-fast surgical rebuilds, zero boilerplate, and effortless state management — with **no `ProviderScope` or other setup required**. Whether it's a simple login screen or a complex multi-step wizard, Formix scales with you.

> **Upgrading from 0.1.x (Riverpod)?** See [`MIGRATION.md`](MIGRATION.md).



<p align="center">
<a href="https://pub.dev/packages/formix"><img src="https://img.shields.io/pub/v/formix.svg" alt="Pub"></a>
<a href="https://github.com/Shreemanarjun/formix/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
<img src="https://img.shields.io/badge/coverage-93%25-brightgreen" alt="Code Coverage">
<img src="https://img.shields.io/badge/tests-passed-brightgreen" alt="Tests">
</p>

---

## 📑 Table of Contents
- [📦 Installation](#-installation)
- [⚡ Quick Start](#-quick-start)
- [🎮 Usage Guide](#-usage-guide)
    - [Basic Login Form](#basic-login-form)
    - [Using Dropdowns & Checkboxes](#using-dropdowns--checkboxes)
    - [Conditional Fields](#conditional-fields)
- [🎮 Core Concepts](#-core-concepts)
- [🧱 Widget Reference](#-widget-reference)
    - [Standard Fields](#standard-fields)
    - [Form Organization](#form-organization)
    - [Reactive UI & Logic](#reactive-ui--logic)
    - [Headless & Custom Widgets](#headless--custom-widgets)
- [🚥 Validation](#-validation)
- [🏗️ Initialization Strategies](#-initialization-strategies)
- [🕹️ Controlling the Form](#-controlling-the-form)
- [🧪 Advanced Features](#-advanced-features)
- [👨‍🍳 Cookbook](#-cookbook)
    - [Multi-step Form (Wizard)](#multi-step-form-wizard)
    - [Dependent Fields](#dependent-fields)
    - [Complex Object Array](#complex-object-array)
    - [Custom Field Implementation](#custom-field-implementation)
    - [Headless Widgets](#headless-widgets)
- [⚡ Performance](#-performance)
- [📊 Analytics & Debugging](#-analytics--debugging)

---

## 📦 Installation

```bash
flutter pub add formix
```

---

## ⚡ Quick Start

### 1. Define Fields
Always use `FormixFieldID<T>` for type-safe field identification.

```dart
final emailField = FormixFieldID<String>('email');
final ageField = FormixFieldID<int>('age');
```

### 2. Build Form
```dart
Formix(
  child: Column(
    children: [
      FormixTextFormField(fieldId: emailField),
      FormixNumberFormField(fieldId: ageField),

      FormixBuilder(
        builder: (context, scope) => ElevatedButton(
          onPressed: scope.watchIsValid ? () => scope.submit(onValid: _submit) : null,
          child: Text('Submit'),
        ),
      ),
    ],
  ),
)
```

---

## 🎮 Usage Guide

### Basic Login Form
Here is a complete, real-world example of a login form with validation and loading state.

```dart
class LoginForm extends StatelessWidget {
  static final emailField = FormixFieldID<String>('email');
  static final passwordField = FormixFieldID<String>('password');

  @override
  Widget build(BuildContext context) {
    return Formix(
      child: Column(
        children: [
          FormixTextFormField(
            fieldId: emailField,
            decoration: InputDecoration(labelText: 'Email'),
            validator: FormixValidators.string().required().email().build(),
          ),
          FormixTextFormField(
            fieldId: passwordField,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
            validator: FormixValidators.string().required().minLength(8).build(),
          ),
          SizedBox(height: 20),
          FormixBuilder(
            builder: (context, scope) {
              if (scope.watchIsSubmitting) {
                return CircularProgressIndicator();
              }
              return ElevatedButton(
                onPressed: scope.watchIsValid
                    ? () => scope.submit(onValid: (values) async {
                        await authService.login(
                          values[emailField.key],
                          values[passwordField.key]
                        );
                      })
                    : null,
                child: Text('Login'),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Using Dropdowns & Checkboxes

```dart
final roleField = FormixFieldID<String>('role');
final termsField = FormixFieldID<bool>('terms');

// ... inside Formix
FormixDropdownFormField<String>(
  fieldId: roleField,
  items: [
    DropdownMenuItem(value: 'admin', child: Text('Admin')),
    DropdownMenuItem(value: 'user', child: Text('User')),
  ],
  decoration: InputDecoration(labelText: 'Select Role'),
),

FormixCheckboxFormField(
  fieldId: termsField,
  title: Text('I agree to terms'),
  validator: (val) => val == true ? null : 'Required',
),
```

### Conditional Fields
Formix makes it easy to show or hide fields based on other values. Use **`FormixSection`** with `keepAlive: false` to ensure that data is automatically cleared from the form state when fields are hidden.

```dart
FormixBuilder(
  builder: (context, scope) {
    // 1. Watch the controlling field
    final type = scope.watchValue<String>(accountTypeField);

    // 2. Conditionally render
    if (type == 'business') {
      return FormixSection(
        // 3. Drop state when removed from the tree
        keepAlive: false,
        child: Column(
          children: [
            FormixTextFormField(
              fieldId: companyNameField,
              decoration: InputDecoration(labelText: 'Company Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            FormixTextFormField(fieldId: taxIdField),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  },
)
```

### Async Data & Dependent Dropdowns
Use `FormixAsyncField` and `FormixDependentAsyncField` for fields that require asynchronous data fetching or depend on other field values. They automatically manage loading states, race conditions, and integrate with the form's `isPending` status.

#### FormixDependentAsyncField
Perfect for parent-child field relationships (e.g., Country -> City).

```dart
FormixDependentAsyncField<List<String>, String>(
  fieldId: cityOptionsField,
  dependency: countryField,
  resetField: cityField, // Automatically clear selected city when country changes
  future: (country) => api.fetchCities(country),
  keepPreviousData: true,
  loadingBuilder: (context) => LinearProgressIndicator(),
  builder: (context, state) {
    final cities = state.asyncState.value ?? [];
    return FormixDropdownFormField<String>(
      fieldId: cityField,
      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      decoration: InputDecoration(labelText: 'City'),
    );
  },
)
```

#### FormixAsyncField
Use this when you have a future that doesn't depend on other form fields.

```dart
FormixAsyncField<List<String>>(
  fieldId: categoryField,
  future: api.fetchCategories(),
  builder: (context, state) {
    return FormixDropdownFormField<String>(
      fieldId: categoryField,
      items: (state.asyncState.value ?? []).map(...).toList(),
    );
  },
)
```

### Computed Fields & Transformers
Synchronize or transform data between fields automatically.

#### FormixFieldTransformer
Synchronously maps a value from a source field to a target field.

```dart
FormixFieldTransformer<String, int>(
  sourceField: bioField,
  targetField: bioLengthField,
  transform: (bio) => bio?.length ?? 0,
)
```

#### FormixFieldAsyncTransformer
Asynchronously transforms values with built-in **debounce** and race condition protection.

```dart
FormixFieldAsyncTransformer<String, String>(
  sourceField: promoCodeField,
  targetField: discountLabelField,
  debounce: Duration(milliseconds: 500),
  transform: (code) => api.verifyPromoCode(code),
)
```


> **Pro Tip**: `controller.submit()` automatically waits for all `FormixAsyncField` widgets to finish loading before executing your `onValid` callback.

---

## 🎮 Core Concepts

### The Three Pillars

| Pattern | Best For | Usage |
| :--- | :--- | :--- |
| **Reactive UI** | Updating buttons, labels, or visibility. | `FormixBuilder(builder: (c, scope) => ...)` |
| **External Control** | Logic outside the widget tree (AppBar buttons). | `Formix.controllerOf(context)` or a `GlobalKey<FormixState>` |
| **Side Effects** | Navigation, Snackbars, Logging. | `FormixListener` |

### Side Effects (`FormixListener`)
Use `FormixListener` to execute one-off actions (like showing a dialog, navigation, or logging) in response to state changes. **It does not rebuild the UI.**

```dart
FormixListener(
  formKey: _formKey,
  listener: (context, state) {
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form has ${state.errorCount} errors!')),
      );
    }
  },
  child: Formix(key: _formKey, ...),
)
```

---

## 🧱 Widget Reference

### Standard Fields
Formix includes high-performance widgets out of the box:

- **`FormixTextFormField`**: Full-featured text input with auto-validation and focus management.
- **`FormixNumberFormField<T>`**: Type-safe numeric input (`int` or `double`).
- **`FormixCheckboxFormField`**: Boolean selection with label.
- **`FormixDropdownFormField<T>`**: Generic dropdown for selections.
- **`FormixCupertinoTextFormField`**: iOS-style text input.
- **`FormixAdaptiveTextFormField`**: Auto-switches between Material/Cupertino based on platform.

### Layout & Logic
- **`FormixSection`**: Group fields. Use `keepAlive: false` to clear data when hidden (e.g. specialized steps).
- **`FormixGroup`**: Namespaces fields (e.g. `user.address` -> `{user: {address: ...}}`).
- **`FormixArray<T>`**: Manage dynamic lists (add/remove items).
- **`SliverFormixArray<T>`**: Dynamic lists optimized for `CustomScrollView`.
- **`FormixFieldRegistry`**: Lazily registers fields (vital for PageViews/Tabs).

### Reactive & Transformers
- **`FormixBuilder`**: Access `FormixScope` for reactive UI (isSubmitting, isValid).
- **`FormixListener`**: Execute side effects (navigation, snackbars) on state change.
- **`FormixFormStatus`**: Debug dashboard showing dirty/error counts.
- **`FormixFieldSelector<T>`**: High-performance widget that rebuilding ONLY when specific field properties change (value, valid, dirty).
- **`FormixFieldValueSelector<T>`**: Simplified selector that listens *only* to value changes.
- **`FormixFieldConditionalSelector<T>`**: Rebuilds only if a custom condition is met.
- **`FormixFieldPerformanceMonitor<T>`**: Debug tool to count rebuilds of a field.
- **`FormixDependentField<T>`**: Rebuilds only when dependency changes.
- **`FormixDependentAsyncField`**: Fetches async options dependent on another field (Country -> City).
- **`FormixFieldDerivation`**: Computes value from dependencies (Qty * Price).
- **`FormixFieldTransformer`**: Sync 1-to-1 transform (String -> Int).
- **`FormixFieldAsyncTransformer`**: Async 1-to-1 transform (User ID -> User Profile).

### Headless & Custom (Raw)
Build completely custom UI while keeping Formix state management.
- **`FormixRawFormField<T>`**: The base headless widget.
- **`FormixRawTextField`**: Specialized for text inputs (manages `TextEditingController`).
- **`FormixRawStringField`**: Convenience for String-only text inputs.
- **`FormixRawNotifierField`**: Semantic alias for optimization using `valueNotifier`.
- **`FormixFieldWidget`**: Base class for creating reusable custom fields.

### Utilities
- **`FormixThemeData`**: Global styling configuration.
- **`FormixNavigationGuard`**: Prevents accidental pops with unsaved changes.
- **`RestorableFormixData`**: Integration with Flutter `RestorationMixin`.

**Complete Real-World Example:**

```dart
class CustomEmailField extends StatelessWidget {
  static final emailField = FormixFieldID<String>('email');

  @override
  Widget build(BuildContext context) {
    return FormixRawFormField<String>(
      fieldId: emailField,
      validator: FormixValidators.string()
        .required('Email is required')
        .email('Please enter a valid email')
        .build(),
      initialValue: '',
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom input with all state integration
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: state.hasError && state.isTouched
                    ? Colors.red
                    : state.focusNode.hasFocus
                      ? Colors.blue
                      : Colors.grey,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                focusNode: state.focusNode,
                enabled: state.enabled,
                onChanged: state.didChange,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  suffixIcon: state.isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : state.validation.isValid && state.isDirty
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                // Use ValueListenableBuilder for text updates without rebuilds
                controller: TextEditingController(text: state.value ?? ''),
              ),
            ),

            // Show error only when appropriate
            if (state.shouldShowError && state.validation.errorMessage != null)
              Padding(
                padding: EdgeInsets.only(top: 8, left: 16),
                child: Text(
                  state.validation.errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            // Show field state for debugging
            if (state.isDirty)
              Padding(
                padding: EdgeInsets.only(top: 4, left: 16),
                child: Text(
                  'Modified',
                  style: TextStyle(color: Colors.orange, fontSize: 10),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

**Using with Third-Party UI Libraries (e.g., Shadcn):**

```dart
FormixRawFormField<String>(
  fieldId: usernameField,
  validator: FormixValidators.string().required().minLength(3).build(),
  builder: (context, state) => ShadInput(
    value: state.value,
    enabled: state.enabled,
    focusNode: state.focusNode,
    onChanged: state.didChange,
    error: state.shouldShowError ? state.validation.errorMessage : null,
    decoration: ShadInputDecoration(
      label: Text('Username'),
      suffix: state.validation.isValidating
        ? ShadSpinner(size: 16)
        : null,
    ),
  ),
)
```

#### `FormixFieldWidget` (Base Class)
Extend this to build your own reusable Formix-enabled components. It handles all controller wiring and focus management automatically. See also `FormixFieldTextMixin` for text fields.

#### `FormixWidget`
Base class for non-field components (like summaries) that need access to `FormixScope`.

---

## 🚥 Validation

### Fluent API (`FormixValidators`)
Define readable, type-safe validation rules. Use `.build()` for synchronous and `.buildAsync()` for asynchronous rules.

```dart
// String Validation
FormixValidators.string()
  .required('Email is mandatory')
  .email('Invalid format')
  .minLength(6)
  .pattern(RegExp(r'...'))
  .build()

// Number Validation
FormixValidators.number<int>()
  .required()
  .positive()
  .min(18, 'Must be an adult')
  .max(99)
  .build()
```

### Async Validation
Async validators are debounced automatically to optimize server performance.

```dart
FormixFieldConfig(
  id: usernameField,
  asyncValidator: (val) async => await checkAvailability(val) ? null : 'Taken',
  debounceDuration: Duration(milliseconds: 500),
)
```

---

## 🕹️ Controlling the Form

### Accessing Formix
There are three ways to access the form controller, depending on your context:

#### 1. Inside the UI (`FormixBuilder`)
Best for reactive UI updates (buttons, visibility).
```dart
FormixBuilder(
  builder: (context, scope) {
    // scope.controller gives you full access
    return ElevatedButton(onPressed: scope.reset);
  }
)
```

#### 2. Using GlobalKey (External Access)
Best for specialized use cases where you need to control the form from a completely different part of the tree.
```dart
final _formKey = GlobalKey<FormixState>();

// ... Formix(key: _formKey, ...)

void submitFromAppBar() {
  _formKey.currentState?.controller.submit();
}
```

#### 3. Using Signals directly
Best for complex logic or extracting reactive reads outside a `FormixBuilder`. Every
controller exposes memoized signal slices — read `.value` inside a `SignalBuilder`.
```dart
final controller = Formix.controllerOf(context)!;

// Reading properties reactively (rebuilds only when validity changes)
SignalBuilder(builder: (context) => Text('${controller.isValidSignal.value}'));

// Executing actions
controller.reset();
```

### 🎮 Controller API Reference
The `FormixController` is your command center.

#### State Updates
| Method | Description |
| :--- | :--- |
| `getValue(id)` | Retrieves the field value as `T?`. Supports smart fallback for unregistered fields. |
| `requireValue(id)` | Retrieves the field value as `T` and throws a `StateError` if null. |
| `setValue(val)` | Updates the field value. |
| `setValues(updates)`| Updates multiple field values at once (Returns `FormixBatchResult`). |
| `applyBatch(batch)` | Updates using a type-safe `FormixBatch` builder. |
| `reset()` | Resets all fields to initial values. |
| `resetField(id)` | Resets a specific field. |
| `markAsDirty(id)` | Manually marks a field as dirty. |

#### Validation
| Method | Description |
| :--- | :--- |
| `validate()` | Triggers validation for all fields. |
| `validateField(id)` | Validates a single field. |
| `setFieldError(id, msg)` | Sets an external error (e.g. from backend). |

#### Focus & Navigation
| Method | Description |
| :--- | :--- |
| `focusField(id)` | Moves focus to the specified field. |
| `focusFirstError()` | Automatically scrolls to the first invalid field. |

#### Advanced
| Method | Description |
| :--- | :--- |
| `undo()` / `redo()` | Navigates history stack. |
| `snapshot()` | Creates a restoration point. |
| `bindField(id, target)` | Syncs two fields together. |


### Global Validation Mode
You can control when validation is triggered globally for the entire form or override it per field.

```dart
Formix(
  // Global mode for all fields
  autovalidateMode: FormixAutovalidateMode.onUserInteraction,
  child: Column(
    children: [
      FormixTextFormField(
        fieldId: nameField,
        // Uses global onUserInteraction by default
        validator: (v) => v!.isEmpty ? 'Error' : null,
      ),
      FormixTextFormField(
        fieldId: pinField,
        // Overrides global mode for this specific field
        validationMode: FormixAutovalidateMode.always,
        validator: (v) => v!.length < 4 ? 'Too short' : null,
      ),
    ],
  ),
| Mode | Behavior |
| :--- | :--- |
| `always` | Validates immediately on mount and every change. |
| `onUserInteraction` | (Default) Validates only after the first change/interaction. |
| `disabled` | Validation only happens when `validate()` or `submit()` is called. |
| `onBlur` | Validation only happens when the field loses focus. |
| `auto` | Per-field default. Inherits from the global `Formix.autovalidateMode`. |


### Cross-Field Validation
Validate fields based on the state of other fields.
```dart
FormixFieldConfig(
  id: confirmField,
  crossFieldValidator: (value, state) {
    if (value != state.getValue(passwordField)) return 'No match';
    return null;
  },
)
```

## 🏗️ Initialization Strategies

Formix provides flexible control over how fields handle their `initialValue`, especially when fields are registered at different times or data is loaded late.

### FormixInitialValueStrategy

You can configure this globally in `FormixFieldConfig` or per-widget:

| Strategy | Behavior | Use Case |
| :--- | :--- | :--- |
| **`preferLocal`** | (Default) Adopts the widget's `initialValue` if the controller is currently `null` and the field isn't "dirty" (modified by user). | **Late loading data**. Use this when you pre-define your form but fetch data asynchronously later. |
| **`preferGlobal`** | Strictly keeps the very first value registered in the `Formix` root or config. Ignores widget-level initial values if registered. | **Architectural Control**. Use this to ensure nested widgets cannot override the baseline state defined at the form root. |

#### Usage Example

```dart
// The field will adopt 'saved-data@email.com' even if pre-registered as null
FormixTextFormField(
  fieldId: emailField,
  initialValue: 'saved-data@email.com',
  initialValueStrategy: FormixInitialValueStrategy.preferLocal, // Default
)
```

---

## 🧪 Advanced Features

### Navigation Guard
Prevent users from losing work when navigation occurs.

```dart
FormixNavigationGuard(
  onPopInvoked: (didPop, isDirty) {
    if (isDirty && !didPop) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Discard changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancel')
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(c); // Close dialog
                Navigator.pop(context); // Pop screen
              },
              child: Text('Discard')
            ),
          ],
        ),
      );
    }
  },
  child: Formix(...),
)
```

### Persistence & State Restoration
Auto-save form state to local storage or support Flutter's native `RestorationMixin`.

#### Standard Persistence
```dart
class MyFormPersistence extends FormixPersistence {
  @override
  Future<void> saveFormState(String formId, Map<String, dynamic> state) async {
    await prefs.setString(formId, jsonEncode(state));
  }

  @override
  Future<Map<String, dynamic>?> loadFormState(String formId) async {
    final str = prefs.getString(formId);
    return str != null ? jsonDecode(str) : null;
  }
}
```

#### Native State Restoration
Formix provides first-class support for Flutter's native state restoration system, allowing your forms to survive app restarts and process death.

**Key Features:**
- `RestorableFormixData` class for seamless `RestorationMixin` integration
- Complete state serialization including values, validations, and metadata
- Automatic restoration of dirty, touched, and pending states
- Type-safe serialization with `toMap()` and `fromMap()`

**Basic Example:**
```dart
class _MyFormState extends State<MyForm> with RestorationMixin {
  final RestorableFormixData _formData = RestorableFormixData();

  @override
  String? get restorationId => 'my_form';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_formData, 'form_state');
  }

  @override
  void dispose() {
    _formData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Formix(
      formId: 'my_form',
      initialData: _formData.value, // Restore form state
      onChangedData: (data) {
        setState(() {
          _formData.value = data; // Save state changes
        });
      },
      child: Column(
        children: [
          FormixTextFormField(fieldId: nameField),
          FormixTextFormField(fieldId: emailField),
        ],
      ),
    );
  }
}
```

**What Gets Restored:**
- ✅ All field values (with type preservation)
- ✅ Validation states and error messages
- ✅ Dirty, touched, and pending states
- ✅ Form metadata (isSubmitting, resetCount, currentStep)
- ✅ Calculated counts (errorCount, dirtyCount, pendingCount)

**Manual Serialization:**
If you need custom persistence logic, you can use the serialization methods directly:

```dart
// Serialize form state
final formData = controller.state;
final map = formData.toMap();
await storage.save('form_backup', jsonEncode(map));

// Restore form state
final json = await storage.load('form_backup');
final map = jsonDecode(json);
final restoredData = FormixData.fromMap(map);

// Use restored data
Formix(
  initialData: restoredData,
  // ...
)
```

### Undo/Redo
History is tracked automatically.

```dart
FormixBuilder(
  builder: (context, scope) => Row(
    children: [
      IconButton(
        icon: Icon(Icons.undo),
        onPressed: scope.canUndo ? scope.undo : null,
      ),
      IconButton(
        icon: Icon(Icons.redo),
        onPressed: scope.canRedo ? scope.redo : null,
      ),
    ],
  ),
)
```

### Robust Bulk Updates & Type Safety
Formix provides a dedicated API for handling large-scale data updates with built-in safety.

#### Type-Safe Batching (`FormixBatch`)
Build a collection of updates with strict compile-time type checking using the fluent API.
```dart
final batch = FormixBatch()
  ..setValue(emailField).to('user@example.com')
  ..setValue(ageField).to(25); // Guaranteed lint enforcement

final result = controller.applyBatch(batch);
if (!result.success) {
  print(result.errors); // Access detailed error map
}
```

#### Robust Error Handling (`FormixBatchResult`)
Updates no longer crash on type mismatches or missing fields. They return a result object containing:
- `updatedFields`: Successfully updated keys.
- `typeMismatches`: Map of field keys to error messages.
- `missingFields`: Fields provided but not registered in the form.

---

## 👨‍🍳 Cookbook

### Multi-step Form (Wizard)
Easily manage multi-step forms by conditionally rendering fields. Formix preserves state for off-screen fields automatically.

```dart
int currentStep = 0;

Formix(
  child: Column(
    children: [
      if (currentStep == 0) ...[
        FormixTextFormField(fieldId: emailField, label: 'Email'),
        ElevatedButton(onPressed: () => setState(() => currentStep = 1), child: Text('Next')),
      ] else ...[
        FormixTextFormField(fieldId: passwordField, label: 'Password'),
        ElevatedButton(onPressed: () => controller.submit(...), child: Text('Submit')),
      ],
    ],
  ),
)
```

### Dependent Fields
Fields that update based on other fields' values.

```dart
FormixFieldConfig(
  id: cityField,
  dependsOn: [countryField],
  validator: (val, data) {
    final country = data.getValue(countryField);
    if (country == 'USA' && val == 'London') return 'London is not in USA';
    return null;
  },
)
```

### Complex Object Array
Managing a list of complex objects (e.g., a list of addresses).

```dart
FormixArray(
  id: addressesField,
  itemBuilder: (context, index, itemId, scope) => FormixGroup(
    prefix: 'address_$index',
    child: Column(
      children: [
        FormixTextFormField(fieldId: streetField, label: 'Street'),
        FormixTextFormField(fieldId: zipField, label: 'Zip Code'),
      ],
    ),
  ),
)
```

### Custom Field Implementation
Create your own form fields by extending `FormixFieldWidget`.

```dart
class MyColorPicker extends FormixFieldWidget<Color> {
  const MyColorPicker({super.key, required super.fieldId});

  @override
  FormixFieldWidgetState<Color> createState() => _MyColorPickerState();
}

class _MyColorPickerState extends FormixFieldWidgetState<Color> {
  @override
  Widget build(BuildContext context) {
    return ColorTile(
      color: value ?? Colors.blue,
      onTap: () => didChange(Colors.red), // Updates form state
    );
  }
}
```

### Headless Widgets
Build completely custom form controls with full UI control while Formix handles all state management.

#### Using FormixRawFormField for Custom Controls
Perfect for non-text inputs like star ratings, color pickers, or custom toggles.

```dart
// Custom Star Rating Widget
final ratingField = FormixFieldID<int>('rating');

FormixRawFormField<int>(
  fieldId: ratingField,
  initialValue: 0,
  validator: (v) => (v ?? 0) < 1 ? 'Please select a rating' : null,
  builder: (context, state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return IconButton(
              onPressed: state.enabled
                ? () => state.didChange(starValue)
                : null,
              icon: Icon(
                starValue <= (state.value ?? 0)
                  ? Icons.star
                  : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
            );
          }),
        ),
        if (state.shouldShowError)
          Text(
            state.validation.errorMessage!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
      ],
    );
  },
)
```

#### Using FormixRawTextField for Custom Text Inputs
Build text fields with custom styling and behavior while maintaining text controller sync.

```dart
// Custom Feedback Field with Character Counter
final feedbackField = FormixFieldID<String>('feedback');

FormixRawTextField<String>(
  fieldId: feedbackField,
  valueToString: (v) => v ?? '',
  stringToValue: (s) => s.isEmpty ? null : s,
  validator: FormixValidators.string()
    .required()
    .minLength(10, 'At least 10 characters required')
    .build(),
  builder: (context, state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: state.hasError && state.isTouched
                ? Colors.red
                : state.focusNode.hasFocus
                  ? Colors.blue
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: state.textController,
            focusNode: state.focusNode,
            maxLines: 4,
            enabled: state.enabled,
            decoration: InputDecoration(
              hintText: 'Tell us what you think...',
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (state.shouldShowError)
              Text(
                state.validation.errorMessage!,
                style: TextStyle(color: Colors.red, fontSize: 12),
              )
            else
              SizedBox.shrink(),
            Text(
              '${state.value?.length ?? 0}/500',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  },
)
```

#### Using FormixRawNotifierField for Performance
Optimize rebuilds using ValueNotifier for granular reactivity.

```dart
// Counter with optimized rebuilds
final counterField = FormixFieldID<int>('counter');

FormixRawNotifierField<int>(
  fieldId: counterField,
  initialValue: 0,
  builder: (context, state) {
    return Column(
      children: [
        // This rebuilds on ANY state change
        Text('Status: ${state.isDirty ? "Modified" : "Pristine"}'),

        // This ONLY rebuilds when value changes
        ValueListenableBuilder<int?>(
          valueListenable: state.valueNotifier,
          builder: (context, value, _) {
            return Text(
              'Count: ${value ?? 0}',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            );
          },
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.remove),
              onPressed: () => state.didChange((state.value ?? 0) - 1),
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () => state.didChange((state.value ?? 0) + 1),
            ),
          ],
        ),
      ],
    );
  },
)
```

---

## 🛠️ Advanced Features

### 🌐 Internationalization (I18n)
Formix has first-class support for localization.

1. **Setup**: Add `FormixLocalizations.delegate` to your `MaterialApp`.
    ```dart
    localizationsDelegates: [
      FormixLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      // ...
    ],
    supportedLocales: [Locale('en'), Locale('es'), Locale('fr'), Locale('de'), Locale('hi'), Locale('zh')],
    ```

2. **Usage**: Access localized messages in custom validators.
    ```dart
    validator: (value, context) =>
        value == null ? FormixLocalizations.of(context).required('Email') : null,
    ```

### 💾 Persistence
Automatically save form data to disk/memory and restore it on app restart.

- **Built-in Interfaces**: Implement `FormixPersistence` to connect to **SharedPreferences**, **Hive**, or a database.
- **Auto-Restore**: Formix automatically repopulates fields when the form initializes with a matching `formId`.

```dart
Formix(
  formId: 'onboarding_step_1', // Unique ID required
  persistence: MyPrefsPersistence(), // Your implementation
  child: ...
)
```

### 📊 Analytics
Gain insights into how users interact with your forms.

Implement `FormixAnalytics` to track events like:
- Field focus/blur (Time per field)
- Validation errors (User friction points)
- Abandonment (Drop-off rates)

```dart
class MyAnalytics extends FormixAnalytics {
  @override
  void onSubmitFailure(String? formId, Map<String, dynamic> errors) {
    MyTracker.logEvent('form_error', {'errors': errors});
  }
}
```

### 🧰 DevTools
**"It's like X-Ray vision for your forms."**

Formix integrates deep into Flutter DevTools.
- **Visual Tree**: See your form's exact structure.
- **Live State**: Watch values, errors, and dirty flags update in real-time.
- **Time Travel**: Undo/Redo form state changes to debug complex logic flows.
- **Modify State**: Inject values directly from DevTools to test edge cases.

*Automatically enabled in Debug mode.*

---

## ⚡ Performance

Formix is engineered for massive scale with continuous performance optimizations.

### Core Performance Features
- **Granular Rebuilds**: Uses `select` to only rebuild exact widgets that change.
- **O(1) Updates**: Field updates are constant time, regardless of form size.
- **Scalability**: Tested with **5000+ active fields** maintaining 60fps interaction.
- **Lazy Evaluation**: Validation and dependency chains are optimized to run only when necessary.

### Recent Optimizations (v0.1.0)

#### 1. Cached InputDecoration
- **What**: Intelligent caching of `InputDecoration` to avoid redundant theme resolution
- **Impact**: Decoration only rebuilds when widget properties or theme actually changes
- **Applied to**: `FormixTextFormField` and `FormixNumberFormField`

#### 2. Combined Field State Notifier
- **What**: Consolidated 4 separate `ValueNotifier`s into a single combined notifier
- **Impact**: Reduces `AnimatedBuilder` overhead from 4 listenables to 1
- **Benefit**: Significantly faster rebuild performance for rapid state changes

#### 3. Optimized Controller Subscription
- **What**: Early return optimization for explicit controllers
- **Impact**: Surgical signal-driven rebuilds — a field change only rebuilds widgets that read that field
- **Benefit**: Cleaner, more efficient code path for common use cases

### Benchmark Results — Riverpod (0.1.x) vs Signals (0.2.0)

Same benchmark suite, same machine. The signals core is faster across the board.
See [`BENCHMARKS.md`](BENCHMARKS.md) for the full methodology and comparison.

| Metric | 0.1.x (Riverpod) | 0.2.0 (Signals) | Change |
|--------|-----------------:|----------------:|--------|
| **Pure Formix overhead / rebuild** | 0.097ms | **0.088ms** | −9.3% |
| **Pure Formix mount/unmount** | 0.054ms | **0.049ms** | −9.3% |
| **Full widget passive rebuild** | 9.548ms | **9.392ms** | −1.6% |
| **Field mount/unmount cycle** | 1.584ms | **1.189ms** | −24.9% |
| **Bulk update 1000 fields** | ~1000ms | **286ms** | ~3.5× faster |

**Surgical rebuilds:** updating one field among 1000 rebuilds exactly one widget
(verified in `test/benchmark_surgical_rebuild_test.dart`).

### Performance Improvements

| Test | Before | After | Improvement |
|------|--------|-------|-------------|
| **100 Widget Rebuilds** | 1388ms | 847ms | **39% faster** 🔥 |
| **Passive Rebuild** | 7.20ms | 5.87ms | **18.5% faster** |
| **50 Keystrokes** | 401ms | 395ms | **1.5% faster** |

### Stress Test Results (M1 Pro)
- **1000 Fields Mount**: <10ms
- **Bulk Updates**: ~50ms for 1000 fields. Single frame execution for `setValues`.
- **Dependency Scale**: **~160ms** for 100,000 dependents. Ultra-fast traversal for deep chains.
- **Memory Efficient**: Uses **lazy-cloning** and **shared validation contexts** to minimize GC pressure and O(N) overhead during validation.

> **Note**: All benchmarks run with 200 warmup iterations and 3000 total samples (3 runs × 1000 iterations) for statistical accuracy.


---

<p align="center">Built with ❤️ for the Flutter Community</p>
