import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

class MultiFormSyncPage extends StatefulWidget {
  const MultiFormSyncPage({super.key});

  @override
  State<MultiFormSyncPage> createState() => _MultiFormSyncPageState();
}

class _MultiFormSyncPageState extends State<MultiFormSyncPage> {
  // We need reference to controllers to setup bindings
  FormixController? _formA;
  FormixController? _formB;

  bool _bindingsSetup = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Form Synchronization')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Edit in Form A (Left) to see changes in Form B (Right) instantly.\nForm B is "read-only" synced.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // FORM A: The Editor
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    elevation: 4,
                    child: Formix(
                      formId: 'formA',
                      initialValue: const {
                        'title': 'My Project',
                        'category': 'Work',
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Form A (Source)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Divider(),
                            FormixBuilder(
                              builder: (context, scope) {
                                // Capture controller
                                _formA = scope.controller;
                                return const SizedBox();
                              },
                            ),
                            FormixTextFormField(
                              fieldId: FormixFieldID('title'),
                              decoration: const InputDecoration(
                                labelText: 'Project Title',
                              ),
                            ),
                            const SizedBox(height: 16),
                            FormixDropdownFormField(
                              fieldId: FormixFieldID('category'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Work',
                                  child: Text('Work'),
                                ),
                                DropdownMenuItem(
                                  value: 'Personal',
                                  child: Text('Personal'),
                                ),
                                DropdownMenuItem(
                                  value: 'Hobby',
                                  child: Text('Hobby'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // FORM B: The Preview (Synced)
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    color: Colors.grey[50],
                    child: Formix(
                      formId: 'formB',
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Form B (Synced Clone)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Divider(),
                            FormixBuilder(
                              builder: (context, scope) {
                                _formB = scope.controller;

                                // One-time setup of bindings when both are ready
                                // In a real app, this might be done in an initState or dedicated binder widget
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (_formA != null &&
                                      _formB != null &&
                                      !_bindingsSetup) {
                                    _formB!.bindField(
                                      FormixFieldID('title'),
                                      sourceController: _formA!,
                                      sourceField: FormixFieldID('title'),
                                    );
                                    _formB!.bindField(
                                      FormixFieldID('category'),
                                      sourceController: _formA!,
                                      sourceField: FormixFieldID('category'),
                                    );
                                    _bindingsSetup = true;
                                    setState(() {}); // refresh to show bound
                                  }
                                });

                                return const SizedBox();
                              },
                            ),
                            // Fields in Form B need to be registered to receive values
                            FormixTextFormField(
                              fieldId: FormixFieldID('title'),
                              readOnly: true, // It's a sync target
                              decoration: const InputDecoration(
                                labelText: 'Synced Title',
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FormixDropdownFormField(
                              fieldId: FormixFieldID('category'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Work',
                                  child: Text('Work'),
                                ),
                                DropdownMenuItem(
                                  value: 'Personal',
                                  child: Text('Personal'),
                                ),
                                DropdownMenuItem(
                                  value: 'Hobby',
                                  child: Text('Hobby'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Synced Category',
                                filled: true,
                              ),
                              // Note: readOnly for dropdowns isn't always standard, often disabled
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_bindingsSetup)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Sync Active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
