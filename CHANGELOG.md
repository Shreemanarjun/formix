## 0.2.0 - Signals core (Breaking)

Formix now runs on [signals](https://pub.dev/packages/signals_flutter) instead of Riverpod.
The form logic, validators, and widget API are unchanged; the reactivity engine is faster
and simpler. See `MIGRATION.md` for the full upgrade guide.

- **No more `ProviderScope`**: `Formix` is fully self-contained. Removed the
  `flutter_riverpod` dependency and the re-export from `package:formix`.
- **Signals core**: whole-form state is a single `Signal<FormixData>`; per-field/aspect
  slices are exposed as memoized `Computed`s (`valueSignal`, `validationSignal`,
  `dirtySignal`, `touchedSignal`, `pendingSignal`, `isValidSignal`, `isDirtySignal`,
  `isSubmittingSignal`, `currentStepSignal`, `groupValidSignal`, `groupDirtySignal`) for
  surgical rebuilds. Widgets rebuild via `SignalBuilder`.
- **Removed**: all `*Provider` globals and `formControllerProvider`-family plumbing.
  Construct controllers directly with `FormixController(...)` / `FormixController.fromParameter(...)`.
- **Renamed**: `RiverpodFormController` → `FormixBaseController`.
- **Global messages**: `formixMessagesProvider` → the reactive `formixGlobalMessages` signal.
  Set `formixGlobalMessages.value = MyMessages()` on a language change; all forms re-validate.
- `FormixAsyncField.asyncValue` now uses `AsyncState<T>` (signals) instead of `AsyncValue<T>`.

## 0.1.3 - Dev (Unreleased)
- **Message Updates & Localization**:
  - Re-introduced optimization to prevent form controller resets during global message/locale updates by switching to `ref.listen` and excluding `messages` from `FormixParameter` equality.
  - Added `messages` property to `Formix` widget for local message overrides, which now update reactively via `didUpdateWidget`.
  - Added `updateMessages()` to `FormixController` to allow manual message updates without resetting state.
  - Exported `FormixValidationKeys` for easier use of standard localized error messages in custom validators.
- **Type Safety Persistence**:
  - Restored strict nullability enforcement in `FormixFieldID.isTypeValid` and `FormixField.isTypeValid`. `null` is now only considered valid if the type parameter `T` is nullable (e.g., `FormixFieldID<String?>`). 
- **Bug Fixes & Refactoring**:
  - Fixed regression in standalone `FormixController` (outside of Riverpod `ProviderScope`) by safely handling `ref` access.
  - Riverpod 3 migration improvements.
  - Fixed cross field validation and multi step form validation issues.
  - Add more examples and updated stability test suite (664 tests passing).

## 0.1.2

### ⚡ Performance Optimizations
- **FormixBuilder Optimization**: Cached `FormixScope` instances to prevent unnecessary downstream rebuilds and clarified behavior with new tests.

## 0.1.1

### ✨ New Features
- **Enhanced Type Safety for Sealed Classes**:
  - Improved `FormixFieldID<T>` and `FormixBatch` to correctly handle inheritance. Values that are subclasses of `T` (such as sealed class implementations) are now properly allowed in `setValue`, `setValues`, and `applyBatch`.
  - Added `isTypeValid` and `isNullableType` to `FormixFieldID` for robust runtime type checking.
  - Added `sameTypes<S, V>()` utility for exact type comparison when mutual sub-typing is required.
- **Async Field Enhancements**:
  - Implemented `onData` callback for `FormixAsyncField` and `FormixDependentAsyncField` to enable safe post-load side effects and initial value selection.
  - Simplified async field initial selection by favoring the `onData` callback over manual logic in builders.
- **Robust Form Reset**:
  - Added `clearErrors` parameter to `reset`, `resetToValues`, and `resetFields` methods to prevent immediate validation errors after a reset.
  - Enhanced reset logic to automatically cancel pending async validations and remove errors from the internal validation map.
  - Reset operations now correctly trigger re-validation for dependent fields of reset fields.
- **Granular Reactivity**:
  - Added selector support to `FormixDependentField` and `FormixFieldDerivation` for optimized updates.
  - Exposed `onData` for better integration in parent-child field relationships.
- **Type-Safe Field Preservation**:
  - Safely preserve and reuse existing field validators and transformers during re-registration (e.g., during hot reload or wizard step navigation) by introducing wrapped versions for automatic type conversion.
- **Refined Type Validation for Inheritance**:
  - Enhanced `_batchUpdate` to support "upgrading" from raw String initial values (e.g., from JSON) to custom Objects (like `Sealed` subclasses) when a typed `FormixFieldID` is used.
  - Improved inheritance support for raw string updates: Transitions between different custom objects (non-primitives) are now allowed to facilitate sealed class hierarchies even without explicit field registration.
  - Maintained strict type safety for core primitives (num, bool, String, DateTime) to prevent unintended type mismatches.
  - Fixed a potential type-inference loss in `_FieldRegistrar` by improving internal generic list handling during field registration.

### 🛠️ Core Improvements
- **Consistent Batch Updates**:
  - `RiverpodFormController` now leverages `FormixFieldID` type information during batch updates even when fields are not yet registered.
  - Enhanced type validation logic to ensure consistency between provided `FormixFieldID`s and existing initial values in the form state.
  - Improved error messages for type mismatches, now providing better context when values are incompatible with previously inferred types.

### ⚡ Performance Optimizations
- **Aggressive Caching**:
  - Implemented `InputDecoration` and `TextInputFormatter` list caching in `FormixTextFormField` and `FormixNumberFormField` to avoid redundant theme resolution.
  - Added explicit `FormixParameter` and provider caching in `FormixState` to avoid redundant family lookups and hash calculations during rebuilds.
  - Added `PERFORMANCE.md` documenting the library's internal optimization strategies.
- **Stable Provider Lifecycle**:
  - Switched from `ref.watch` to `ref.listen` for localized messages in `formControllerProvider`. This prevents form state resets during language/locale changes.
  - Updated `FormixParameter` to use `DeepCollectionEquality` for all collection fields, ensuring provider stability when parameters are recreated with identical data.
- **Optimized Rebuilds**:
  - Refined `_FieldRegistrar` to skip redundant registrations using `ListEquality`.
  - Optimized `SliverFormixArray` to watch the provider's notifier, preventing unnecessary list rebuilds on unrelated field changes.
- **Other Improvements**:
  - Added `updateMessages()` to `RiverpodFormController` for reactive message updates without controller recreation.

### 🧪 Testing
- **Sealed Class Type Safety**: Added `test/sealed_class_test.dart` to verify correct handling of sealed classes and subclasses in batch updates and field state.
- Added comprehensive widget tests for `SliverFormixArray` and `FormixAsyncField`'s `onData` behavior.
- Added stability test suite for verifying controller preservation across parent rebuilds and message updates.
- Total test count: 654 tests passing.

## 0.1.0

### ✨ New Features
- **Configurable Initial Value Strategy**:
  - Introduced `FormixInitialValueStrategy` enum to control how fields adopt initial values after their first registration.
  - Added `preferLocal` strategy (default): Fields intelligently adopt values from widgets if the current state is `null` and not yet modified by the user. This solves common issues with late-initialized data in dynamic forms or wizards.
  - Added `preferGlobal` strategy: Fields strictly adhere to the initial value provided during the very first registration (at the `Formix` root), ignoring subsequent updates from nested widgets.
  - Strategy can be configured at the `FormixFieldConfig` level or overridden on individual field widgets.

### 🛠️ Core Improvements & Fixes
- **Type Safety Fix for Field Registration**:
  - Fixed critical type casting error in `FormixFieldWidgetState._ensureFieldRegistered` that occurred when preserving validators from existing fields.
  - Now uses `wrappedValidator`, `wrappedAsyncValidator`, `wrappedCrossFieldValidator`, and `wrappedTransformer` methods to safely handle type conversions between `dynamic` and typed validators.
  - Resolves runtime errors like `type '(DateTime?) => String?' is not a subtype of type '((dynamic) => String?)?'` when using typed fields with custom validators.
  - Added comprehensive test suite (`type_safety_field_registration_test.dart`) covering DateTime, TimeOfDay, complex objects, and validator override scenarios.

- **Unified Ancestor Validation**:
  - Introduced `FormixAncestorValidator` to centralize `ProviderScope` and `Formix` requirement checks across all widgets.
  - Improved developer experience with rich, descriptive error messages and actionable code examples when configuration is missing.
- **Robust Field Re-registration**: Updated `registerFields` logic to track newly registered fields versus definition updates, ensuring state preservation while correctly applying initial values when appropriate.
- **FormixSection Fix**: Implemented `didUpdateWidget` in `FormixSection` to reliably catch and register configuration changes, fixing a bug where fields in dynamic wizards or reused sections occasionally failed to initialize.
- **Unified Widget API**: Exposed `initialValueStrategy` on all standard and adaptive form fields for fine-grained control.
- **Flexibility Enhancements**: Updated `FormixDependentField` and `FormixDependentAsyncField` to support standalone usage outside of `Formix` widgets by falling back to the global controller provider.
- **Robust Reset with clearErrors**:
  - Enhanced `reset`, `resetToValues`, and `resetFields` to reliably clear all error states when `clearErrors: true` is provided.
  - Automatically cancels all pending asynchronous validation debouncers during reset to prevent late-arriving errors.
  - Correctly triggers re-validation for dependent fields of reset fields, ensuring consistent form-wide validity state.
  - Resets the validation lifecycle by removing internal validation flags, preventing premature re-validation in "onUserInteraction" mode.
- **Fixed Hidden Bug**: Resolved an edge-case where `initialValue` provided in a widget was ignored if the field had been pre-registered in the root `Formix` widget with a `null` value.
- **Golden Test Refresh**: Updated all error state golden tests to reflect the new premium error UI.

### ⚡ Performance Optimizations
- **Cached InputDecoration** (FormixTextFormField & FormixNumberFormField):
  - Implemented intelligent caching of `InputDecoration` to avoid redundant theme resolution.
  - Decoration is only rebuilt when widget properties or theme actually changes.
  - Reduces `Theme.of(context)` lookups and decoration processing overhead.
  - **New**: Added caching for final effective decoration (with error/helper text).
  - **New**: Added caching for input formatters list.
- **Combined Field State Notifier**:
  - Consolidated 4 separate `ValueNotifier`s (value, validation, dirty, touched) into a single combined notifier.
  - Reduces `AnimatedBuilder` overhead from 4 listenables to 1.
  - Significantly improves rebuild performance for rapid state changes.
- **Optimized Controller Subscription Setup**:
  - Added early return optimization for explicit controllers in `FormixFieldWidgetState`.
  - Avoids unnecessary Riverpod subscription setup when controller is provided directly.
  - Cleaner, more efficient code path for common use cases.
- **SliverFormixArray Optimization**:
  - Fixed rebuild issue: Changed `ref.watch(provider)` to `ref.watch(provider.notifier)`.
  - Now only rebuilds when controller instance changes, not on every form state change.
  - Prevents unnecessary rebuilds in large scrollable forms.
- **Performance Impact**:
  - **Formix vs Flutter Baseline**: 13-22% **FASTER** than plain Flutter TextFormField!
    - Passive Rebuild: 7.985ms (Flutter: 10.274ms) - **22% faster**
    - Mount/Unmount: 1.670ms (Flutter: 1.928ms) - **13% faster**
  - Pure Formix overhead: ~0.08ms per rebuild (negligible)
  - Mount/Unmount cycles: ~1.5ms per cycle
  - **Key Insight**: Granular selectors + aggressive caching = faster than baseline!
- **Enhanced Benchmarks**:
  - Consolidated all performance tests into `formix_benchmarks_test.dart`.
  - Added **baseline Flutter TextFormField benchmarks** for accurate comparison.
  - Each test runs 3 times with 1000 iterations and averages results for accuracy.
  - Beautiful box-drawing output format for easy performance tracking.
  - Comprehensive documentation in `BENCHMARK_RESULTS.md` and `REBUILD_OPTIMIZATION.md`.

### 🧪 Testing
- **SliverFormixArray Test Suite**:
  - Added comprehensive widget tests (`test/widgets/sliver_form_array_test.dart`).
  - 10 test cases covering rendering, CRUD operations, empty states, and rebuild optimization.
  - Verified that array items don't rebuild on unrelated field changes.
  - Integration tests with SliverAppBar, FormixGroup, and complex UI patterns.
- **Total Test Count**: 646 tests passing (10 new SliverFormixArray tests).



## 0.0.9

### 🛠️ Core Improvements & Fixes
- **Improved Lifecycle Management**:
  - `Formix` now robustly handles external controllers with `keepAlive: true`, ensuring they are not disposed even when the widget tree is rebuilt or navigation occurs.
  - Added `preventDisposal` flag to `RiverpodFormController` to support external lifecycle management.
  - Converted `FormixBuilder` to `ConsumerStatefulWidget` for reliable resource cleanup and correct interaction with Riverpod's referencing system.
- **Enhanced Debugging**:
  - Added meaningful `toString()` implementation to `FormixParameter` for easier debugging of provider families.
- **Initial Value Override**: Fixed logic to correctly prioritize field-level `initialValue` over global form default values. This ensures that explicitly configured fields (e.g., in `FormixTextFormField`) always retain their specific initial values.
- **Lazy Step State Preservation**: Fixed a critical issue where re-registering a field (such as waking a lazy step in a wizard) would overwrite user-entered data with the initial value. Now, `Formix` intelligently preserves "dirty" (user-modified) values while still applying initial values to "clean" fields.
- **Race Condition Fix**: Resolved a race condition in `registerFields` where rapid field registrations could lead to lost validation state updates. The state calculation is now encapsulated within the update closure for reliable sequential execution.

## 0.0.8

### ✨ New Features
- **Form-Level Theming**:
  - Introduced `FormixTheme` and `FormixThemeData` for centralized styling.
  - Support for global `InputDecorationTheme`, `loadingIcon`, and `editIcon`.
  - Conditional theme application via the `enabled` flag.
- **Sliver Support**:
  - Added `SliverFormixArray` for high-performance dynamic lists inside `CustomScrollView`.
- **Adaptive Support**:
  - Introduced `FormixAdaptiveTextFormField` for automatic switching between Material and Cupertino styling based on the platform.
- **Native State Restoration**:
  - Introduced `RestorableFormixData` class that extends `RestorableValue<FormixData>` for seamless integration with Flutter's `RestorationMixin`.
  - Added comprehensive `toMap()` and `fromMap()` methods to `FormixData` for complete state serialization including:
    - All field values (preserving types)
    - Validation states and error messages
    - Dirty, touched, and pending states
    - Form metadata (isSubmitting, resetCount, currentStep)
    - Calculated counts (errorCount, dirtyCount, pendingCount)
  - Added `toMap()` and `fromMap()` to `ValidationResult` for proper validation state persistence.
  - Added `initialData` parameter to `Formix` widget and `FormixController` for restoring form state on initialization.
  - Optimized `FormixParameter` identity to exclude `initialData`, preventing unnecessary provider recreation.
  - Full test coverage with unit tests and golden snapshot tests demonstrating restoration in real-world scenarios.
- **Improved Documentation**:
  - Added "Conditional Fields" guide to README explaining usage of `FormixSection` with `keepAlive: false` for dynamic forms.
  - Added comprehensive `ConditionalFormExample` in example app showing real-world dynamic field patterns.

### 🛠️ Core Improvements & Bug Fixes
- **Robust Count Tracking**:
  - Refactored internal validation logic in `_batchUpdate` and `validate` methods to ensure atomic updates of `errorCount` and `pendingCount`.
  - Fixed "Double Counting" bug where `errorCount` was decremented twice during transitions from "invalid" to "async validating".
  - Fixed "Leaked Pending Count" where transitions from "validating" to "invalid" (synchronously) failed to decrement `pendingCount`.
- **Improved validate() Behavior**:
  - The `validate()` method now automatically marks all validated fields as **touched**. This aligns with standard Flutter behavior, ensuring error messages become visible in the UI immediately upon manual validation.
- **State Consistency**:
  - Enhanced `validate()` to correctly populate `changedFields`, ensuring reactive listeners and UI components are accurately notified of form-wide validation updates.

## 0.0.7

### 🛠️ Core Improvements
- **Enhanced Validation Access**:
  - `FormixData` and controllers now expose `errors` (Map of field IDs to error messages) and `errorMessages` (List of all error messages).
  - This simplifies global error handling and custom error summary displays.
  - Added `@override` annotations to `FormixController` for improved type safety and lint compliance.
- **Improved Validation Logic**:
  - Implemented comprehensive `autovalidateMode` support for individual fields, allowing fine-grained control over when validation occurs.
  - Refined error display logic to ensure messages appear exactly when expected based on field interaction and validation mode.
- **Enhanced Testing**:
  - Added new golden tests for validation states to ensure visual consistency of error states across UI components.

## 0.0.6

### 📚 Documentation Improvements
- **Enhanced Headless Documentation**:
  - **FormixFieldStateSnapshot.valueNotifier**: Added comprehensive documentation with practical examples showing how to use `ValueListenableBuilder` for granular reactivity and optimized rebuilds.
  - **FormixRawNotifierField**: Complete class documentation explaining its purpose as a performance-optimized widget for ValueNotifier-based updates, with detailed examples demonstrating the difference between full rebuilds and granular updates.
  - **Cookbook Section**: Added extensive "Headless Widgets" cookbook with three production-ready patterns:
    - `FormixRawFormField` for custom controls (star rating example)
    - `FormixRawTextField` for custom text inputs (feedback field with character counter)
    - `FormixRawNotifierField` for performance optimization (counter with granular rebuilds)
  - **Updated Example App**: Completely rewrote the headless form example to showcase all `FormixFieldStateSnapshot` properties with real-time state indicators and latest API usage.
  - **Table of Contents**: Added Cookbook section to README with proper navigation links.

## 0.0.5

### 💎 DevTools Extension Redesign (v2)
- **Premium UI**: Completely overhauled the DevTools extension with a modern, tabbed interface (**Fields**, **Dependencies**, **Raw State**).
- **Glassmorphic Aesthetics**: Implemented a premium design system with transparency, blur effects, and full support for Dark/Light modes.
- **Enhanced Inspection**:
  - **Raw State Tab**: Inspect structured, nested form data in real-time (powered by `toNestedMap`).
  - **Dependency Graph**: Visualized field relationships showing exactly what a field depends on and what it affects.
  - **Status Badges**: Circular indicators for **D**irty, **T**ouched, and **P**ending states.
  - **Performance Metrics**: Reactive validation duration labels with color-coded status.
- **Integrated refreshing**: New auto-refresh logic with customizable intervals (1s-10s) and a dedicated sync indicator.
- **formDataProvider**: Added a reactive provider to expose the entire `FormixData` state.

### ✨ Accessibility & Semantics (shadcn-inspired)
- **Form Semantics**: The `Formix` widget now automatically reports as a `SemanticsRole.form`, improving structural navigation for screen readers.
- **Validation Semantics**: All fields (including headless ones) now communicate their validation status (`invalid`/`valid`) directly to the OS via `SemanticsValidationResult`.
- **Intelligent Announcements**: Added `FormixController.announceErrors()` which automatically reads out the first validation error to assistive technologies when a submission fails.

### 🚀 Standard Field Properties
- **Unified API**: All Formix fields (`Text`, `Number`, `Checkbox`, `Dropdown`) now support standard `FormField` properties:
  - `onSaved` & `onReset` hooks.
  - `enabled` state management.
  - `forceErrorText` for manual error overrides.
  - `errorBuilder` for custom error UI.
  - `autovalidateMode` for per-field validation control.
  - `restorationId` for state restoration.
- **Explicit Controller**: The `Formix` widget now supports an optional explicit `controller` parameter, allowing for manual instantiation while keeping the reactive provider benefits.

### 🛠️ Core Improvements & Fixes
- **Headless API**: `FormixFieldStateSnapshot` now exposes `enabled` and `errorBuilder`, making it easier to build high-quality custom components.
- **Validation Fix**: Fixed `RiverpodFormController.registerField` to strictly honor `autovalidateMode` during initial registration, preventing unwanted errors in `disabled` forms.
- **Type-Safe Value Retrieval**:
  - Reverted `getValue<T>` to return `T?` for better safety and backwards compatibility.
  - Added "smart fallback" to `getValue`: now recovers values from `initialValueMap` or field definitions if a field is not yet registered.
  - Introduced `requireValue<T>`: returns `T` and throws a descriptive `StateError` if the value is null.
- **New Field Transformers**:
  - `FormixFieldTransformer`: Synchronous 1-to-1 transformation between fields.
  - `FormixFieldAsyncTransformer`: Asynchronous transformation with built-in debounce and robust lifecycle management.
- **Hot Reload Support**: Fixed field definitions not updating during hot reload. `Formix` and `FormixSection` now reliably detect configuration changes and update the controller.
- **Riverpod Refactors**: Key widgets (`FormixFieldDerivation`, `FormixGroup`, `FormixListener`) upgraded to `ConsumerStatefulWidget` for better state access.
- **Hot Reload Support**: Fixed field definitions not updating during hot reload. `Formix` and `FormixSection` now reliably detect configuration changes and update the controller.
- **FormixSection Overhaul**: Refactored to `ConsumerStatefulWidget` for consistent lifecycle management.
  - Now supports synchronous registration to prevent lazy-loading race conditions.
  - Reliably handles `keepAlive` for preserving state in wizards and tabs.
- **Undo/Redo Stability**: Fixed history pollution where focus/touch events triggered unnecessary undo steps. History is now strictly value-based using deep equality checks.
- **Validation Fixes**:
  - `FormixAutovalidateMode.always` now correctly shows errors immediately upon registration for all field types.
  - Fixed input formatter ordering in `FormixTextFormField` and `FormixNumberFormField` to ensure config-level formatters (logic) run before widget-level formatters (UI).
- **New `FormixAsyncField`**: Added a dedicated widget for handling asynchronous data fetching within forms.
  - Features built-in race condition protection and retry logic.
  - Automatically re-triggers fetch on form reset (via `onRetry`).
  - Coordinated with the form's `isPending` state for submission safety.
- **New `FormixDependentAsyncField`**: A simplified widget for parent-child field relationships.
  - Automatically watches a dependency and executes a future.
  - **Improved Robustness**: Fixed lifecycle issues where fields could occasionally unregister during rapid state transitions.
  - Supports `resetField` to automatically clear dependent fields when the parent changes.
- **Robust Reset Logic**: Form resets are now tracked via an internal `resetCount`, ensuring the `onReset` hook is reliably triggered for all fields regardless of their previous dirty state.
- **Improved Pending State Management**: Fixed "Tried to modify a provider while the widget tree was building" error by moving pending state updates to microtasks.
- **Multi-Step Form Reliability**: Fixed a bug where navigating back to a previous page in a multi-step form would show "required" validation errors even if fields were filled. Formix now correctly validates against preserved values during re-registration.
- **Dropdown Field**: Migrated `FormixDropdownFormField` to use `InputDecorator` + `DropdownButton`. Now defensively handles values not present in the items list to prevent crashes during dynamic transitions.
- **Global Validation Mode**:
  - Introduced form-level `autovalidateMode` in `Formix` widget and `FormixController`.
  - Added `FormixAutovalidateMode.auto` as the default for all fields, allowing them to inherit the form's global setting or explicitly override it.
  - Improved `onUserInteraction` logic to ensure consistent feedback when values are changed and then reverted to their initial state.
- **Infinite Loop Fix**: Optimized `FormixController` listener notifications to prevent infinite loops when fields trigger state changes during updates (e.g., in `FormixFieldAsyncTransformer`).
- **Robust Bulk Update API**:
  - Added `FormixBatch` for compile-time type-safe batch building with a new fluent `setValue().to()` API for guaranteed lint enforcement.
  - Added `FormixBatchResult` for detailed reporting on batch failures (type mismatches, missing fields).
  - Both `setValues` and `updateFromMap` now return results instead of throwing, with an optional `strict: true` mode for developers who prefer immediate crashes during debugging.
- **High-Performance Dependency Tracking**:
  - Re-engineered `_collectTransitiveDependents` with a high-speed BFS implementation using an index-based queue, reducing traversal time for 100,000-field chains from **332ms to ~160ms**.
  - Optimized internal dependents map access with zero-allocation iterables.
- **Async Validation Stability**:
  - Fixed a critical race condition where `submit()` could hang indefinitely if called while an async validation was already pending.
  - Corrected `pendingCount` double-increment bug during concurrent validation cycles.
  - Consolidated "validating" state transitions into primary batch updates, eliminating redundant UI rebuilds.
- **Optimized State Engine**:
  - Implemented **Lazy Map Cloning** for validation results, avoiding O(N) penalties when field values change but validation results remain constant.
  - Shared `FormixData` validation contexts across batch updates to drastically reduce GC pressure in cross-field validation chains.
  - Replaced functional filter/map operations in hot paths with high-performance manual loops for count calculations.
- **Validation Fixes**:
  - Fixed `onUserInteraction` mode regression where valid results weren't properly cached to track the "previously validated" state.
  - Corrected `FormixAutovalidateMode.always` behavior during initial field registration.
- **DevTools Integration**: Forms without an explicit `formId` now automatically register with DevTools using their internal namespace as a fallback, ensuring full visibility.

### 🛠️ Developer Experience
- **FormixBuilder Enhancements**: Improved reactive data access patterns with better scoping.
- **New `FormixWidget`**: Added base class for creating reusable, context-aware form components with less boilerplate.

### 🧪 Testing
- **Advanced Async Test Suite**: Added comprehensive tests for `FormixDependentAsyncField` and `FormixAsyncField`:
  - Rapid dependency change handling and debounce verification.
  - State preservation during async loading unmounts.
  - Validation error clearing on field resets.
- **Additional Test Coverage**:
  - Dynamic Array Fields (Contacts List)
  - Multi-Step Wizards with State Preservation
  - Complex Validation Scenarios & Input Formatting
  - Hot Reload & Lifecycle Behavior
  - Performance & Memory Leaks (5000+ fields, rapid typing stress tests)

## 0.0.4

### 🛠️ DevTools Integration
- **DevTools Extension**: Added a dedicated DevTools extension for real-time form state inspection and debugging
  - 🔍 Visual form state tree with field values, validation states, and metadata
  - ⚡ Performance monitoring for form rebuilds and validation execution
  - 🔗 Deep link integration for quick access from running applications
  - 🌐 Built with Flutter Web and fully integrated with the DevTools ecosystem

### 🔒 Type Safety & Reliability
- **Strict Null Safety**: Comprehensive null-safety across all validators and widgets
- **Integration Testing**: Expanded integration tests for complex scenarios

### 🎯 User Experience Enhancements
- **Rich Error Placeholders**: Dynamic errors like `Field {label} must be at least {min} characters`
- **Built-in Masking & Formatting**: Input formatters in `FieldConfig`
- **Automatic Focus Management**: Submit-to-Error and Enter-to-Next implemented

### 🧠 Advanced State Management
- **Undo/Redo History**: Snapshots for state restoration and history
- **Optimistic Field Updates**: Pending state for server round-trips
- **Multi-Form Synchronization**: "Binding" API to link fields between separate forms

- **Improved error messages and validation feedback**
- **Fluent Validators**: New `FormixValidators` API for readable chainable rules
- **Logging Analytics**: Built-in debug logger for form events
- **Robust Dependency Logic**: Support for recursive A->B->C dependency chains with cycle detection. Optimized to O(N) (10,000-field chain updates in ~70ms).
- **Correct Undo/Redo Behavior**: Implemented semantic equality for form state to prevent duplicate history entries.
- **Async Submission Safety**: `submit()` now waits for all pending async validations to complete before proceeding
- **Partial Validation**: `validate(fields: [...])` allows validating specific subsets of fields (e.g., for Steppers)

### ⚡ Performance Optimizations
- **Delta Updates**: O(1) complexity for field updates (was O(N)), enabling forms with 1000+ fields
- **Lazy Step Initialization**: "Sleep" background steps to save memory in 50+ step forms
- **Form Analytics Hook**: Track completion time and abandonment points
- **Built-in Localization**: Support for 6 languages out-of-the-box (En, Es, Fr, De, Hi, Zh)
- **Zero Configuration**: Works automatically with standard Flutter `MaterialApp`
- **Optional Delegate**: New `FormixLocalizations.delegate` for seamless integration (completely optional)
- **Reviewable Messages**: Fallback mechanism to `Localizations.localeOf(context)` if delegate is missing

### 🔧 Developer Experience
- Enhanced visual debugging tools through DevTools extension
- Better form state introspection capabilities
- Improved error messages and validation feedback

## 0.0.3
- Upgraded flutter_riverpod to ^2.6.1


## 0.0.2

- Updated logo URL


## 0.0.1

### ✨ Initial Release

An elite, type-safe, and ultra-reactive form engine for Flutter powered by Riverpod.

#### 🔒 Core Features
* **True Type Safety**: Compile-time safety using `FormixFieldID<T>` and `FormixArrayID<T>`.
* **High Performance**: Granular rebuilds using Riverpod selectors—only affected widgets update.
* **Auto-Disposable**: Automatic memory management with Riverpod `autoDispose` controllers.
* **Declarative API**: Define form structure easily using `FormixFieldConfig`.

#### 🚥 Validation & Logic
* **Smart Validation**: Support for Sync, Async (with debounce), and Cross-field validation.
* **Dependency Tracking**: Automatic re-validation of dependent fields.
* **Field Derivation**: Computed fields based on other form values.

#### 🏗️ Advanced UI Components
* **Sectional Forms**: `FormixSection` for lazy-loading and organizing massive forms (100+ fields).
* **Form Arrays**: Managed dynamic lists with type safety.
* **Navigation Guard**: `FormixNavigationGuard` to prevent accidental data loss on dirty forms.
* **Performance Monitor**: `FormixFieldPerformanceMonitor` for tracking widget rebuilds.

#### 🎯 UX & Control
* **Programmatic Focus**: Jump to errors or specific fields via `FormixScope`.
* **Automated Scrolling**: Smooth scrolling to validation errors.
* **State Persistence**: Interface for saving/restoring form progress to local storage.

#### 🧩 Built-in Widgets
* `RiverpodTextFormField`
* `RiverpodNumberFormField`
* `RiverpodCheckboxFormField`
* `RiverpodDropdownFormField`
* `FormixDependentField`
* `FormixBuilder`
* `FormixWidget` (Base class for custom components)
