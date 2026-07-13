import 'package:flutter/material.dart';

class QuizFilterBar extends StatelessWidget {
  final String searchQuery;
  final String? selectedQuestionRange;
  final Function(String) onSearchChanged;
  final Function(String?) onQuestionRangeChanged;
  final VoidCallback onReset;

  const QuizFilterBar({
    super.key,
    required this.searchQuery,
    required this.selectedQuestionRange,
    required this.onSearchChanged,
    required this.onQuestionRangeChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: TextEditingController(text: searchQuery)
            ..selection = TextSelection.collapsed(offset: searchQuery.length),
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            labelText: 'Search quizzes',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedQuestionRange,
                decoration: const InputDecoration(labelText: 'No. of Questions'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: '1-5', child: Text('1-5')),
                  DropdownMenuItem(value: '5-10', child: Text('5-10')),
                  DropdownMenuItem(value: '10-20', child: Text('10-20')),
                  DropdownMenuItem(value: '>20', child: Text('>20')),
                ],
                onChanged: onQuestionRangeChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.deepPurple,
              tooltip: 'Reset filters',
            ),
          ],
        ),
      ],
    );
  }
}
