import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormArray Logic', () {
    test('addArrayItem adds item to list', () {
      final controller = FormixController();
      const arrayId = FormixArrayID<String>('tags');

      controller.addArrayItem(arrayId, 'tag1');
      expect(controller.getValue(arrayId), ['tag1']);

      controller.addArrayItem(
        arrayId,
        'tag1',
      ); // Duplicate key should work fine in array
      controller.addArrayItem(arrayId, 'tag2');
      expect(controller.getValue(arrayId), ['tag1', 'tag1', 'tag2']);
    });

    test('removeArrayItemAt removes correct item', () {
      final controller = FormixController();
      const arrayId = FormixArrayID<String>('tags');

      controller.setValue(arrayId, ['tag1', 'tag2', 'tag3']);

      controller.removeArrayItemAt(arrayId, 1);
      expect(controller.getValue(arrayId), ['tag1', 'tag3']);
    });

    test('replaceArrayItem replaces item at index', () {
      final controller = FormixController();
      const arrayId = FormixArrayID<String>('tags');

      controller.setValue(arrayId, ['tag1', 'tag2']);

      controller.replaceArrayItem(arrayId, 0, 'newTag');
      expect(controller.getValue(arrayId), ['newTag', 'tag2']);
    });

    test('moveArrayItem reorders items', () {
      final controller = FormixController();
      const arrayId = FormixArrayID<String>('tags');

      controller.setValue(arrayId, ['tag1', 'tag2', 'tag3']);

      controller.moveArrayItem(arrayId, 0, 1);
      expect(controller.getValue(arrayId), ['tag2', 'tag1', 'tag3']);
    });
  });

  group('FormixArray Widget', () {
    testWidgets('renders items and handles adding/removing', (tester) async {
      const arrayId = FormixArrayID<String>('hobbies');

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'hobbies': ['A', 'B'],
            },
            child: Scaffold(
              body: FormixArray<String>(
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
              floatingActionButton: FormixBuilder(
                builder: (context, scope) => FloatingActionButton(
                  onPressed: () => scope.addArrayItem(arrayId, 'C'),
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);

      // Add item
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Item 2'), findsOneWidget);

      // Remove item
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // After removal, index 0 is gone, 1 becomes 0, 2 becomes 1
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsNothing);
    });
  });
}
