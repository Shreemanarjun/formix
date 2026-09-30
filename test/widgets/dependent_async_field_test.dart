import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  const countryField = FormixFieldID<String>('country');
  const cityField = FormixFieldID<String>('city');
  const cityOptionsField = FormixFieldID<List<String>>('cityOptions');

  Widget buildTestApp({
    required Future<List<String>> Function(String?) fetchCities,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Formix(
          initialValue: const {'country': 'USA', 'city': 'New York'},
          fields: const [
            FormixFieldConfig<String>(id: countryField),
            FormixFieldConfig<String>(id: cityField),
          ],
          child: Column(
            children: [
              const FormixTextFormField(fieldId: countryField),
              FormixDependentAsyncField<List<String>, String>(
                fieldId: cityOptionsField,
                dependency: countryField,
                resetField: cityField,
                future: fetchCities,
                builder: (context, state) {
                  final cities = state.asyncState.value ?? [];
                  return Column(
                    children: cities.map((c) => Text('Option: $c')).toList(),
                  );
                },
              ),
              const FormixTextFormField(fieldId: cityField),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('FormixDependentAsyncField fetches data and resets field', (
    tester,
  ) async {
    // Setup simulated API
    Future<List<String>> fetchCities(String? country) async {
      await Future.delayed(const Duration(milliseconds: 10));
      if (country == 'USA') return ['New York', 'LA'];
      if (country == 'Canada') return ['Toronto', 'Vancouver'];
      return [];
    }

    await tester.pumpWidget(buildTestApp(fetchCities: fetchCities));
    await tester.pumpAndSettle();

    // Initial state: USA -> New York, LA
    expect(find.text('Option: New York'), findsOneWidget);
    expect(find.text('Option: LA'), findsOneWidget);
    // City field should have initial value
    expect(find.text('New York'), findsOneWidget);

    // Change country to Canada
    await tester.enterText(find.byType(TextField).first, 'Canada');
    await tester.pump(); // Trigger listener

    // Should be loading (or clearing dependent field immediately)
    // City field should be cleared because dependency changed
    // Wait for listen callback to fire
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Check if city text field is empty (reset)
    // Note: The second TextField is the city field
    expect(find.widgetWithText(TextField, 'New York'), findsNothing);
    // It shouldn't find 'New York' in the text field anymore if cleared
    // But let's check the controller value via UI
    // Actually, create a simpler way to verify clearing
  });

  testWidgets('FormixDependentAsyncField clears related field on change', (
    tester,
  ) async {
    Future<List<String>> fetchCities(String? country) async {
      return ['A', 'B'];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'country': 'USA', 'city': 'NYC'},
            child: Column(
              children: [
                const FormixTextFormField(
                  fieldId: countryField,
                  key: Key('country_input'),
                ),
                const FormixTextFormField(
                  fieldId: cityField,
                  key: Key('city_input'),
                ),
                FormixDependentAsyncField<List<String>, String>(
                  fieldId: cityOptionsField,
                  dependency: countryField,
                  resetField: cityField,
                  future: fetchCities,
                  builder: (context, state) => Container(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial value
    expect(find.text('NYC'), findsOneWidget);

    // Change dependency
    await tester.enterText(find.byKey(const Key('country_input')), 'Canada');
    await tester.pump();

    // Wait for listener
    await tester.pump();

    // City should be cleared (empty string or null, TextFormField shows empty)
    // Assuming FormixTextFormField handles null as empty string
    expect(find.text('NYC'), findsNothing);
    // Should verify it is empty.
    // Finding Header/Label is tricky, but let's check widget state directly via key
    final cityInput = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('city_input')),
        matching: find.byType(TextField),
      ),
    );
    expect(cityInput.controller!.text, isEmpty);
  });

  testWidgets(
    'FormixDependentAsyncField unmounts child and preserves registration state',
    (tester) async {
      final completers = <Completer<List<String>>>[];
      Future<List<String>> fetchCities(String? country) {
        final c = Completer<List<String>>();
        completers.add(c);
        return c.future;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'country': 'USA', 'city': 'NY'},
              child: Column(
                children: [
                  const FormixTextFormField(
                    fieldId: countryField,
                    key: Key('country'),
                  ),
                  FormixDependentAsyncField<List<String>, String>(
                    fieldId: cityOptionsField,
                    dependency: countryField,
                    resetField: cityField,
                    future: fetchCities,
                    keepPreviousData: false,
                    loadingBuilder: (context) => const Text('Loading...'),
                    builder: (context, state) {
                      return FormixDropdownFormField<String>(
                        fieldId: cityField,
                        key: const Key('city_dropdown'),
                        items: (state.asyncState.value ?? [])
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Initial State: Loading
      await tester.pump();
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byKey(const Key('city_dropdown')), findsNothing);

      // Verify Controller State
      final formixState = tester.state<FormixState>(find.byType(Formix));
      final controller = formixState.controller;

      // child field NOT registered yet (as it's inside builder)
      expect(controller.isFieldRegistered(cityField), isFalse);

      // 2. Load Data
      completers.first.complete(['NY', 'LA']);
      await tester.pump(const Duration(milliseconds: 10)); // Microtasks
      await tester.pump(); // Rebuild from AsyncValue

      expect(find.text('Loading...'), findsNothing);
      expect(find.byKey(const Key('city_dropdown')), findsOneWidget);

      // NOW child field SHOULD be registered
      expect(controller.isFieldRegistered(cityField), isTrue);
      expect(controller.getValue(cityField), 'NY');

      // 3. Change Dependency -> Loading -> Unmount Child
      await tester.enterText(find.byKey(const Key('country')), 'Canada');
      await tester.pump(); // Trigger listener (resetField -> clear)

      // Verify value cleared immediately (for String it's '')
      expect(controller.getValue(cityField), '');

      // Verify loading state (since keepPreviousData: false)
      await tester.pump();
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byKey(const Key('city_dropdown')), findsNothing);

      // Verify child field registration persists
      // NOTE: Formix does NOT automatically unregister fields when widgets dispose.
      expect(controller.isFieldRegistered(cityField), isTrue);

      // 4. Complete second load
      completers.last.complete(['Toronto', 'Vancouver']);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();

      expect(find.text('Loading...'), findsNothing);
      expect(find.byKey(const Key('city_dropdown')), findsOneWidget);

      // Verify child re-connected correctly
      expect(controller.isFieldRegistered(cityField), isTrue);
      expect(controller.getValue(cityField), ''); // Still empty from reset
    },
  );

  testWidgets('FormixDependentAsyncField validation clears on reset', (
    tester,
  ) async {
    final completers = <Completer<List<String>>>[];
    Future<List<String>> fetchCities(String? country) {
      final c = Completer<List<String>>();
      completers.add(c);
      return c.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'country': 'USA', 'city': 'NY'},
            child: Column(
              children: [
                const FormixTextFormField(
                  fieldId: countryField,
                  key: Key('country'),
                ),
                FormixDependentAsyncField<List<String>, String>(
                  fieldId: cityOptionsField,
                  dependency: countryField,
                  resetField: cityField,
                  future: fetchCities,
                  keepPreviousData: false,
                  loadingBuilder: (context) => const Text('Loading...'),
                  builder: (context, state) {
                    return FormixDropdownFormField<String>(
                      fieldId: cityField,
                      key: const Key('city_dropdown'),
                      items: (state.asyncState.value ?? [])
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    completers.first.complete(['NY', 'LA']);
    await tester.pumpAndSettle();

    final formixState = tester.state<FormixState>(find.byType(Formix));
    final controller = formixState.controller;

    // Set invalid state manually
    controller.setFieldError(cityField, 'Custom Error');
    await tester.pump();

    // Check state directly (UI might hide it if not touched)
    expect(controller.getValidation(cityField).errorMessage, 'Custom Error');

    // Change dependency
    await tester.enterText(find.byKey(const Key('country')), 'Canada');
    await tester.pump(); // Reset happens

    // Value should be empty string
    expect(controller.getValue(cityField), '');

    completers.last.complete(['Toronto']);
    await tester.pumpAndSettle();

    // Check if error is gone.
    // When value changes (setValue to ''), validation runs.
    // If validation passes for '' (not required), error is gone.
    // "Custom Error" should be cleared because validation re-ran.
    expect(controller.getValidation(cityField).errorMessage, isNull);
  });

  testWidgets('FormixDependentAsyncField respects debounce duration', (
    tester,
  ) async {
    final completers = <Completer<List<String>>>[];

    Future<List<String>> fetchCities(String? country) {
      final c = Completer<List<String>>();
      completers.add(c);
      return c.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'country': 'USA'},
            child: Column(
              children: [
                const FormixTextFormField(
                  fieldId: countryField,
                  key: Key('country'),
                ),
                FormixDependentAsyncField<List<String>, String>(
                  fieldId: cityOptionsField,
                  dependency: countryField,
                  future: fetchCities,
                  debounce: const Duration(milliseconds: 500),
                  loadingBuilder: (context) => const Text('Loading...'),
                  builder: (context, state) {
                    final cities = state.asyncState.value ?? [];
                    return Column(
                      children: cities.map((c) => Text('Option: $c')).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 1. Initial Load (USA)
    await tester.pump(const Duration(milliseconds: 500));
    if (completers.isNotEmpty) {
      completers.last.complete(['NY']);
    }
    await tester.pumpAndSettle();
    expect(find.text('Option: NY'), findsOneWidget);

    // 2. Change Dependency to 'C'
    await tester.enterText(find.byKey(const Key('country')), 'C');
    await tester.pump();

    // We have a new future now.
    final canadaFuture = completers.last;

    // Complete it IMMEDIATELY
    canadaFuture.complete(['Toronto']);

    // Pump a little bit (less than debounce)
    await tester.pump(const Duration(milliseconds: 200));

    // EXPECTATION: Debounce prevents update.
    // UI should NOT show 'Option: Toronto' yet.
    // It should still show 'Option: NY'
    expect(find.text('Option: NY'), findsOneWidget);
    expect(find.text('Option: Toronto'), findsNothing);
    expect(find.text('Loading...'), findsNothing);

    // 3. Wait remaining time (300ms + buffer)
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(); // Run microtasks/futures

    // Now _executeFuture ran. It attached .then(). Future is already complete.
    // It updates state -> 'Toronto'.
    expect(find.text('Option: Toronto'), findsOneWidget);
  });
}
