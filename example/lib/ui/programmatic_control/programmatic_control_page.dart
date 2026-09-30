import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

final field1Id = FormixFieldID<String>('field_1');
final field2Id = FormixFieldID<String>('field_2');
final field3Id = FormixFieldID<String>('field_3');
final field4Id = FormixFieldID<String>('field_4');
final field5Id = FormixFieldID<String>('field_5');

class ProgrammaticControlPage extends StatelessWidget {
  const ProgrammaticControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programmatic Control')),
      body: Formix(
        fields: [
          FormixFieldConfig<String>(id: field1Id),
          FormixFieldConfig<String>(id: field2Id),
          FormixFieldConfig<String>(
            id: field3Id,
            validator: (val) => (val?.isEmpty ?? true) ? 'Required' : null,
          ),
          FormixFieldConfig<String>(id: field4Id),
          FormixFieldConfig<String>(id: field5Id),
        ],
        child: FormixBuilder(
          builder: (context, scope) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => scope.focusField(field5Id),
                        child: const Text('Focus Last'),
                      ),
                      ElevatedButton(
                        onPressed: () => scope.scrollToField(field5Id),
                        child: const Text('Scroll Last'),
                      ),
                      ElevatedButton(
                        onPressed: () => scope.focusFirstError(),
                        child: const Text('Focus Error'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildField(field1Id, 'First Field'),
                          const SizedBox(height: 200),
                          _buildField(field2Id, 'Second Field'),
                          const SizedBox(height: 200),
                          _buildField(field3Id, 'Third Field (Mandatory)'),
                          const SizedBox(height: 200),
                          _buildField(field4Id, 'Fourth Field'),
                          const SizedBox(height: 200),
                          _buildField(field5Id, 'Last Field'),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildField(FormixFieldID<String> id, String label) {
    return FormixTextFormField(
      fieldId: id,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
