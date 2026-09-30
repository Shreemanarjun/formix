import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

const _titleId = FormixFieldID<String>('title');
const _categoryId = FormixFieldID<String>('category');

class MultiFormSyncPage extends StatefulWidget {
  const MultiFormSyncPage({super.key});

  @override
  State<MultiFormSyncPage> createState() => _MultiFormSyncPageState();
}

class _MultiFormSyncPageState extends State<MultiFormSyncPage> {
  // Own both controllers directly — no InheritedWidget lookups, no build-time
  // side-effects. Each is just a bag of signals we hold and dispose.
  final _formA = FormixController(
    formId: 'formA',
    fields: const [
      FormixFieldConfig<String>(id: _titleId, initialValue: 'My Project'),
      FormixFieldConfig<String>(id: _categoryId, initialValue: 'Work'),
    ],
  );
  final _formB = FormixController(
    formId: 'formB',
    fields: const [
      FormixFieldConfig<String>(id: _titleId),
      FormixFieldConfig<String>(id: _categoryId),
    ],
  );

  @override
  void initState() {
    super.initState();
    // Wire the one-way sync once, up front — both controllers already exist.
    _formB.bindField(_titleId, sourceController: _formA, sourceField: _titleId);
    _formB.bindField(_categoryId, sourceController: _formA, sourceField: _categoryId);
  }

  @override
  void dispose() {
    _formA.dispose();
    _formB.dispose();
    super.dispose();
  }

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
                // FORM A: The Editor — provides the controller we own.
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    elevation: 4,
                    child: Formix(
                      controller: _formA,
                      child: const SingleChildScrollView(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Form A (Source)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Divider(),
                            FormixTextFormField(
                              fieldId: _titleId,
                              decoration: InputDecoration(labelText: 'Project Title'),
                            ),
                            SizedBox(height: 16),
                            FormixDropdownFormField(
                              fieldId: _categoryId,
                              items: [
                                DropdownMenuItem(value: 'Work', child: Text('Work')),
                                DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                                DropdownMenuItem(value: 'Hobby', child: Text('Hobby')),
                              ],
                              decoration: InputDecoration(labelText: 'Category'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // FORM B: The Preview — synced target, also owned by us.
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    color: Colors.grey[50],
                    child: Formix(
                      controller: _formB,
                      child: const SingleChildScrollView(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Form B (Synced Clone)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Divider(),
                            FormixTextFormField(
                              fieldId: _titleId,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Synced Title',
                                filled: true,
                              ),
                            ),
                            SizedBox(height: 16),
                            FormixDropdownFormField(
                              fieldId: _categoryId,
                              items: [
                                DropdownMenuItem(value: 'Work', child: Text('Work')),
                                DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                                DropdownMenuItem(value: 'Hobby', child: Text('Hobby')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Synced Category',
                                filled: true,
                              ),
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
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              'Sync Active',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
