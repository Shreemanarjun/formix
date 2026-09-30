import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

class UndoRedoPage extends StatelessWidget {
  const UndoRedoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Undo/Redo History')),
      body: Formix(
        initialValue: const {
          'document': 'Initial content.\n\nType here...',
          'font_size': 14.0,
          'dark_mode': false,
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildToolbar(context),
              const Divider(),
              Expanded(child: _buildEditor()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return FormixBuilder(
      builder: (context, scope) {
        // Access controller for undo/redo
        final controller = scope.controller;

        // We can't easily watch canUndo/canRedo unless we expose them
        // or watch the entire state and check history index?
        // Actually typical approach is to just try.
        // For a polished UI, we'd need reactive getters for canUndo/canRedo.
        // But for this demo, buttons are always enabled or we assume simple.

        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              // On press, we just call undo.
              // In a real app we'd disable if history empty.
              onPressed: () {
                controller.undo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Undo action'),
                    duration: Duration(milliseconds: 500),
                  ),
                );
              },
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: () {
                controller.redo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Redo action'),
                    duration: Duration(milliseconds: 500),
                  ),
                );
              },
              tooltip: 'Redo',
            ),
            const VerticalDivider(),
            Expanded(
              child: Row(
                children: [
                  const Text('Size: '),
                  Expanded(
                    child: FormixBuilder(
                      builder: (context, scope) {
                        final size =
                            scope.watchValue<double>(
                              FormixFieldID('font_size'),
                            ) ??
                            14.0;
                        return Slider(
                          min: 8.0,
                          max: 32.0,
                          value: size,
                          onChanged: (val) =>
                              scope.setValue(FormixFieldID('font_size'), val),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            FormixBuilder(
              builder: (context, scope) {
                final isDark =
                    scope.watchValue<bool>(FormixFieldID('dark_mode')) ?? false;
                return Switch(
                  value: isDark,
                  onChanged: (val) =>
                      scope.setValue(FormixFieldID('dark_mode'), val),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditor() {
    return FormixBuilder(
      builder: (context, scope) {
        final isDark =
            scope.watchValue<bool>(FormixFieldID('dark_mode')) ?? false;
        final size =
            scope.watchValue<double>(FormixFieldID('font_size')) ?? 14.0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: FormixTextFormField(
            fieldId: FormixFieldID('document'),
            maxLines: null,
            expands: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: size,
              fontFamily: 'Courier',
            ),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        );
      },
    );
  }
}
