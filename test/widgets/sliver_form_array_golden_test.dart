import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('SliverFormixArray Golden Test', (tester) async {
    const arrayId = FormixArrayID<String>('tags');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: Scaffold(
          body: Formix(
            fields: const [
              FormixFieldConfig(
                id: arrayId,
                initialValue: ['Flutter', 'React', 'Vue'],
              ),
            ],
            child: CustomScrollView(
              slivers: [
                const SliverAppBar(
                  title: Text('Sliver Form Array'),
                  floating: true,
                ),
                SliverFormixArray<String>(
                  id: arrayId,
                  itemBuilder: (context, index, itemId, scope) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: FormixTextFormField(
                        fieldId: itemId,
                        decoration: InputDecoration(
                          labelText: 'Tag ${index + 1}',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => scope.removeArrayItemAt(arrayId, index),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 3 items are present
    expect(find.byType(TextField), findsNWidgets(3));

    // Golden check
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/sliver_form_array_initial.png'),
    );

    // Test removal
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));

    // Golden check after removal
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/sliver_form_array_after_removal.png'),
    );
  });
}
