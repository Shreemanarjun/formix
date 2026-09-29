import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Mock Data Classes
class MockState {
  final int id;
  final String name;
  const MockState(this.id, this.name);
  @override
  String toString() => name;
  @override
  bool operator ==(Object other) => other is MockState && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class MockCity {
  final String id;
  final String name;
  const MockCity(this.id, this.name);
  @override
  String toString() => name;
  @override
  bool operator ==(Object other) => other is MockCity && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

void main() {
  testWidgets('FormixAsyncField auto-selects first item using addPostFrameCallback hack', (tester) async {
    const stateOptionsId = FormixFieldID<List<String>>('state_options');
    const selectedStateId = FormixFieldID<String>('selected_state');

    final statesCompleter = Completer<List<String>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            onChanged: (_) {},
            child: FormixAsyncField<List<String>>(
              fieldId: stateOptionsId,
              future: statesCompleter.future,
              onData: (context, controller, data) {
                controller.setValue(selectedStateId, data.first);
              },
              builder: (context, stateSnapshot) {
                return FormixRawFormField<String>(
                  fieldId: selectedStateId,
                  builder: (context, selectionState) {
                    return Text(selectionState.value ?? 'No selection');
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    // Initially loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the future
    statesCompleter.complete(['State A', 'State B']);
    // Wait for everything to settle (futures, pumps, post-frame callbacks)
    await tester.pumpAndSettle();

    expect(find.text('State A'), findsOneWidget);
  });

  testWidgets('FormixAsyncField auto-selects first item using onData callback', (tester) async {
    const stateOptionsId = FormixFieldID<List<String>>('state_options_ondata');
    const selectedStateId = FormixFieldID<String>('selected_state_ondata');

    final statesCompleter = Completer<List<String>>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            onChanged: (_) {},
            child: FormixAsyncField<List<String>>(
              fieldId: stateOptionsId,
              future: statesCompleter.future,
              onData: (context, controller, states) {
                // This is the clean way
                if (states.isNotEmpty && controller.getValue(selectedStateId) == null) {
                  controller.setValue(selectedStateId, states.first);
                }
              },
              builder: (context, stateSnapshot) {
                return FormixRawFormField<String>(
                  fieldId: selectedStateId,
                  builder: (context, selectionState) {
                    return Text(selectionState.value ?? 'No selection');
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    // Initially loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the future
    statesCompleter.complete(['State A', 'State B']);
    // Wait for everything to settle
    await tester.pumpAndSettle();

    // Value should be set
    expect(find.text('State A'), findsOneWidget);
  });

  testWidgets('FormixDependentAsyncField correctly handles dependency changes and onData', (tester) async {
    const stateFieldId = FormixFieldID<MockState>('state_field');
    const cityFieldId = FormixFieldID<MockCity?>('city_field');
    const cityOptionsId = FormixFieldID<List<MockCity>>('city_options');

    final mockStates = [
      const MockState(1, 'California'),
      const MockState(2, 'New York'),
    ];

    final mockCities = {
      1: [const MockCity('LA', 'Los Angeles'), const MockCity('SF', 'San Francisco')],
      2: [const MockCity('NYC', 'New York City'), const MockCity('BUF', 'Buffalo')],
    };

    Future<List<MockCity>> fetchCities(MockState? state) async {
      await Future.delayed(const Duration(milliseconds: 10));
      if (state == null) return [];
      return mockCities[state.id] ?? [];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            onChanged: (_) {},
            child: Column(
              children: [
                // State Selector
                FormixRawFormField<MockState>(
                  fieldId: stateFieldId,
                  builder: (context, stateStatus) {
                    return DropdownButton<MockState>(
                      value: stateStatus.value,
                      items: mockStates.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (s) => stateStatus.didChange(s),
                    );
                  },
                ),
                // City Dependent Field
                FormixDependentAsyncField<List<MockCity>, MockState>(
                  fieldId: cityOptionsId,
                  dependency: stateFieldId,
                  resetField: cityFieldId,
                  future: fetchCities,
                  onData: (context, controller, cities) {
                    // Auto-select first city
                    if (cities.isNotEmpty && controller.getValue(cityFieldId) == null) {
                      controller.setValue(cityFieldId, cities.first);
                    }
                  },
                  loadingBuilder: (context) => const CircularProgressIndicator(),
                  builder: (context, cityOptionsSnapshot) {
                    final cities = cityOptionsSnapshot.value ?? [];
                    // If empty/loading handled, this should be safe
                    return FormixRawFormField<MockCity?>(
                      fieldId: cityFieldId,
                      builder: (context, cityStatus) {
                        if (cities.isEmpty && cityStatus.value == null) {
                          return const Text('No Cities Available');
                        }
                        return Text(cityStatus.value?.name ?? 'No City Selected');
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Initial Loading (fetching cities for null state) -> Wait for it
    await tester.pumpAndSettle();

    // Initial State: No state selected, cities empty, so "No Cities Available" or "No City Selected" depending on logic
    // fetchCities(null) -> []
    // builder sees cities=[]
    // RawField value is null.
    // Text is 'No Cities Available'
    expect(find.text('No Cities Available'), findsOneWidget);

    // Select California
    await tester.tap(find.byType(DropdownButton<MockState>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('California').last);
    await tester.pumpAndSettle(); // Selection closed, state updated

    // Async fetch triggered. Loading first?
    // FormixAsyncField might show loadingBuilder depending on keepPreviousData. Default false.
    // So "No Cities Available" should be gone, circular progress visible?
    // Wait for fetch.
    await tester.pumpAndSettle();

    // onData fired -> 'Los Angeles' selected
    expect(find.text('Los Angeles'), findsOneWidget);

    // Change State to New York
    await tester.tap(find.byType(DropdownButton<MockState>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New York').last);
    await tester.pumpAndSettle();

    // Wait for fetch
    await tester.pumpAndSettle();

    // onData fires -> Select 'New York City'
    expect(find.text('New York City'), findsOneWidget);
  });
}
