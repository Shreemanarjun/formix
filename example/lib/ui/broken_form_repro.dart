import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

void main() {
  runApp(const MaterialApp(home: BrokenFormPage()));
}

class BrokenFormPage extends StatelessWidget {
  const BrokenFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broken Form')),
      body: Column(
        children: [
          // This will fail because there is no Formix ancestor
          FormixTextFormField(
            fieldId: FormixFieldID('name'),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ],
      ),
    );
  }
}
