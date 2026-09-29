import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('SliverFormixArray Widget Tests', () {
    testWidgets('renders items in CustomScrollView', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: ['Flutter', 'Dart', 'React'],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return ListTile(
                        title: Text('Item $index'),
                        subtitle: FormixTextFormField(fieldId: itemId),
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

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('handles adding items', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: ['A', 'B'],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return ListTile(
                        title: Text('Item $index'),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: FormixBuilder(
                      builder: (context, scope) => ElevatedButton(
                        onPressed: () => scope.addArrayItem(arrayId, 'C'),
                        child: const Text('Add'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsNothing);

      // Add item
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('handles removing items', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: ['A', 'B', 'C'],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return ListTile(
                        title: Text('Item $index'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => scope.removeArrayItemAt(arrayId, index),
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

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      // Remove first item
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // After removal, indices shift down
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsNothing);
    });

    testWidgets('shows empty builder when array is empty', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: <String>[],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return ListTile(title: Text('Item $index'));
                    },
                    emptyBuilder: (context, scope) {
                      return const Center(
                        child: Text('No items'),
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

      expect(find.text('No items'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('empty builder is wrapped in SliverToBoxAdapter', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: <String>[],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return ListTile(title: Text('Item $index'));
                    },
                    emptyBuilder: (context, scope) {
                      return const Text('Empty');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('works with FormixGroup prefix resolution', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: FormixArrayID<String>('user.tags'),
                  initialValue: ['A', 'B'],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: FormixGroup(
                      prefix: 'user',
                      child: CustomScrollView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        slivers: [
                          SliverFormixArray<String>(
                            id: arrayId,
                            itemBuilder: (context, index, itemId, scope) {
                              return ListTile(title: Text('Item $index'));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('updates when array value changes', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: ['A'],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return ListTile(
                        title: FormixTextFormField(fieldId: itemId),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: FormixBuilder(
                      builder: (context, scope) => ElevatedButton(
                        onPressed: () {
                          scope.setValue(arrayId, ['A', 'B', 'C']);
                        },
                        child: const Text('Set Values'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(1));

      // Update array value
      await tester.tap(find.text('Set Values'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('handles complex item widgets', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: ['Flutter', 'Dart'],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text('Tag ${index + 1}'),
                              FormixTextFormField(
                                fieldId: itemId,
                                decoration: InputDecoration(
                                  labelText: 'Value',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => scope.removeArrayItemAt(arrayId, index),
                                  ),
                                ),
                              ),
                            ],
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

      expect(find.text('Tag 1'), findsOneWidget);
      expect(find.text('Tag 2'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('works with SliverAppBar and other slivers', (tester) async {
      const arrayId = FormixArrayID<String>('tags');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(
                  id: arrayId,
                  initialValue: ['A', 'B'],
                ),
              ],
              child: CustomScrollView(
                slivers: [
                  const SliverAppBar(
                    title: Text('My Form'),
                    floating: true,
                  ),
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      return ListTile(title: Text('Item $index'));
                    },
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Footer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Form'), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
    });

    testWidgets('does not rebuild unnecessarily', (tester) async {
      const arrayId = FormixArrayID<String>('tags');
      const otherFieldId = FormixFieldID<String>('other');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [
                FormixFieldConfig(id: arrayId, initialValue: ['A']),
                FormixFieldConfig(id: otherFieldId, initialValue: 'test'),
              ],
              child: CustomScrollView(
                slivers: [
                  SliverFormixArray<String>(
                    id: arrayId,
                    itemBuilder: (context, index, itemId, scope) {
                      buildCount++;
                      return ListTile(title: Text('Item $index'));
                    },
                  ),
                  SliverToBoxAdapter(
                    child: FormixBuilder(
                      builder: (context, scope) => ElevatedButton(
                        onPressed: () {
                          scope.setValue(otherFieldId, 'changed');
                        },
                        child: const Text('Change Other'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialBuildCount = buildCount;

      // Change unrelated field - should not rebuild array items
      await tester.tap(find.text('Change Other'));
      await tester.pumpAndSettle();

      // Build count should not increase (array items don't rebuild)
      expect(buildCount, equals(initialBuildCount));
    });
  });
}
