import 'package:flutter/material.dart';
import 'ui/basic_form/basic_form_page.dart';
import 'ui/schema_form/schema_form_page.dart';
import 'ui/conditional_form/conditional_form_page.dart';
import 'ui/derived_fields/derived_fields_page.dart';
import 'ui/validation_examples/validation_examples_page.dart';
import 'ui/headless_form/headless_form_page.dart';
import 'ui/performance_examples/performance_examples_page.dart';
import 'ui/advanced/advanced_page.dart';
import 'ui/dynamic_array/dynamic_array_page.dart';
import 'ui/programmatic_control/programmatic_control_page.dart';
import 'ui/form_groups/form_groups_page.dart';
import 'ui/multi_step_form/multi_step_form_page.dart';
import 'ui/undo_redo_demo.dart';
import 'ui/multi_form_sync_page.dart';
import 'ui/login_form_test/login_form_test_page.dart';
import 'ui/formix_builder_test/formix_builder_test_page.dart';
import 'ui/custom_widgets/custom_widgets_page.dart';
import 'ui/advanced/async_field_submission_page.dart';
import 'ui/dependency_graph_example.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formix Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 19, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formix Examples'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basic'),
            Tab(text: 'Graph Demo'),
            Tab(text: 'Schema'),
            Tab(text: 'Conditional'),
            Tab(text: 'Derived'),
            Tab(text: 'Validation'),
            Tab(text: 'Headless'),
            Tab(text: 'Performance'),
            Tab(text: 'Advanced'),
            Tab(text: 'Arrays'),
            Tab(text: 'Control'),
            Tab(text: 'Groups'),
            Tab(text: 'Multi-Step'),
            Tab(text: 'Undo/Redo'),
            Tab(text: 'Sync'),
            Tab(text: 'Login'),
            Tab(text: 'Builder Test'),
            Tab(text: 'Async Submission'),
            Tab(text: 'Custom Widgets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          BasicFormExample(),
          DependencyGraphExample(),
          SchemaFormExample(),
          ConditionalFormExample(),
          DerivedFieldsExample(),
          ValidationExamples(),
          HeadlessFormExample(),
          PerformanceExamples(),
          AdvancedExample(),
          DynamicArrayPage(),
          ProgrammaticControlPage(),
          FormGroupsPage(),
          MultiStepFormPage(),
          UndoRedoPage(),
          MultiFormSyncPage(),
          LoginFormTestPage(),
          FormixBuilderTestPage(),
          AsyncFieldSubmissionPage(),
          CustomWidgetsPage(),
        ],
      ),
    );
  }
}
