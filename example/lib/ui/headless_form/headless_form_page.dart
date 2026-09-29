import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

// Headless Form Example - Showcasing Latest API
class HeadlessFormExample extends StatelessWidget {
  const HeadlessFormExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const HeadlessFormExampleContent();
  }
}

class HeadlessFormExampleContent extends StatefulWidget {
  const HeadlessFormExampleContent({super.key});

  @override
  State<HeadlessFormExampleContent> createState() =>
      _HeadlessFormExampleContentState();
}

class _HeadlessFormExampleContentState
    extends State<HeadlessFormExampleContent> {
  // Field IDs
  static final ratingField = FormixFieldID<int>('rating');
  static final feedbackField = FormixFieldID<String>('feedback');
  static final wouldRecommendField = FormixFieldID<bool>('wouldRecommend');
  static final counterField = FormixFieldID<int>('counter');

  @override
  Widget build(BuildContext context) {
    return Formix(
      formId: 'headless_form_example',
      initialValue: {
        'rating': 0,
        'feedback': '',
        'wouldRecommend': false,
        'counter': 0,
      },
      fields: [
        FormixFieldConfig<int>(
          id: ratingField,
          initialValue: 0,
          validator: (value) {
            if ((value ?? 0) < 1) return 'Please select a rating';
            return null;
          },
        ),
        FormixFieldConfig<String>(
          id: feedbackField,
          initialValue: '',
          validator: FormixValidators.string()
              .required('Please provide feedback')
              .minLength(10, 'Feedback must be at least 10 characters')
              .build(),
        ),
        FormixFieldConfig<bool>(id: wouldRecommendField, initialValue: false),
        FormixFieldConfig<int>(id: counterField, initialValue: 0),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Headless Form Widgets - Latest API',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Custom form controls showcasing all FormixFieldStateSnapshot properties',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // 1. FormixRawFormField - Star Rating
            _buildSectionTitle('1. FormixRawFormField - Star Rating'),
            const SizedBox(height: 8),
            FormixRawFormField<int>(
              fieldId: ratingField,
              validator: (v) => (v ?? 0) < 1 ? 'Please select a rating' : null,
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: state.hasError && state.isTouched
                            ? Colors.red.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.hasError && state.isTouched
                              ? Colors.red
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (index) {
                              final starValue = index + 1;
                              return IconButton(
                                onPressed: state.enabled
                                    ? () {
                                        state.didChange(starValue);
                                        state.markAsTouched();
                                      }
                                    : null,
                                icon: Icon(
                                  starValue <= (state.value ?? 0)
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: state.enabled
                                      ? Colors.amber
                                      : Colors.grey,
                                  size: 32,
                                ),
                              );
                            }),
                          ),
                          if (state.shouldShowError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                state.validation.errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStateIndicators(state),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 2. FormixRawTextField - Custom Feedback Field
            _buildSectionTitle('2. FormixRawTextField - Custom Text Input'),
            const SizedBox(height: 8),
            FormixRawTextField<String>(
              fieldId: feedbackField,
              valueToString: (v) => v ?? '',
              stringToValue: (s) => s.isEmpty ? null : s,
              validator: FormixValidators.string()
                  .required()
                  .minLength(10, 'At least 10 characters required')
                  .build(),
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: state.hasError && state.isTouched
                              ? Colors.red
                              : state.focusNode.hasFocus
                              ? Colors.blue
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: state.textController,
                        focusNode: state.focusNode,
                        maxLines: 4,
                        enabled: state.enabled,
                        decoration: const InputDecoration(
                          hintText: 'Tell us what you think...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (state.shouldShowError)
                          Expanded(
                            child: Text(
                              state.validation.errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Text(
                          '${state.value?.length ?? 0}/500',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStateIndicators(state),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 3. FormixRawFormField - Custom Toggle
            _buildSectionTitle('3. FormixRawFormField - Custom Toggle'),
            const SizedBox(height: 8),
            FormixRawFormField<bool>(
              fieldId: wouldRecommendField,
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (state.value ?? false)
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (state.value ?? false)
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Would you recommend this?',
                              style: TextStyle(
                                fontSize: 16,
                                color: (state.value ?? false)
                                    ? Colors.green.shade800
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ),
                          Switch(
                            value: state.value ?? false,
                            onChanged: state.enabled
                                ? (value) {
                                    state.didChange(value);
                                    state.markAsTouched();
                                  }
                                : null,
                            activeThumbColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStateIndicators(state),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 4. FormixRawNotifierField - Performance Optimized Counter
            _buildSectionTitle(
              '4. FormixRawNotifierField - Performance Optimized',
            ),
            const SizedBox(height: 8),
            FormixRawNotifierField<int>(
              fieldId: counterField,
              builder: (context, state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Using ValueListenableBuilder for granular updates',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          // This ONLY rebuilds when value changes
                          ValueListenableBuilder<int?>(
                            valueListenable: state.valueNotifier,
                            builder: (context, value, _) {
                              return Text(
                                '${value ?? 0}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: state.enabled
                                    ? () => state.didChange(
                                        (state.value ?? 0) - 1,
                                      )
                                    : null,
                                iconSize: 32,
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: state.enabled
                                    ? () => state.didChange(
                                        (state.value ?? 0) + 1,
                                      )
                                    : null,
                                iconSize: 32,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStateIndicators(state),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            const FormixFormStatus(),
            const SizedBox(height: 16),

            // Submit Button
            FormixBuilder(
              builder: (context, scope) {
                return ElevatedButton(
                  onPressed: scope.watchIsValid
                      ? () {
                          scope.submit(
                            onValid: (values) async {
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Form Submitted'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children:
                                          [
                                                Text(
                                                  'Rating: ${values['rating']} ⭐',
                                                ),
                                                Text(
                                                  'Feedback: ${values['feedback']}',
                                                ),
                                                Text(
                                                  'Recommend: ${values['wouldRecommend']}',
                                                ),
                                                Text(
                                                  'Counter: ${values['counter']}',
                                                ),
                                              ]
                                              .map(
                                                (w) => Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: w,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      : null,
                  child: const Text('Submit Survey'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildStateIndicators<T>(FormixFieldStateSnapshot<T> state) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _buildChip('Dirty', state.isDirty, Colors.orange),
          _buildChip('Touched', state.isTouched, Colors.purple),
          _buildChip('Valid', state.validation.isValid, Colors.green),
          _buildChip('Enabled', state.enabled, Colors.blue),
          if (state.isSubmitting) _buildChip('Submitting', true, Colors.red),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.2) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color : Colors.grey),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: active ? color : Colors.grey.shade600,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
