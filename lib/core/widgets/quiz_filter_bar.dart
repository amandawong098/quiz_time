import 'package:flutter/material.dart';

class QuizFilterBar extends StatelessWidget {
  final String searchQuery;
  final String? selectedGrade;
  final String? selectedSubject;
  final String? selectedQuestionRange;
  final List<String> grades;
  final List<String> subjects;
  final Function(String) onSearchChanged;
  final Function(String?) onGradeChanged;
  final Function(String?) onSubjectChanged;
  final Function(String?) onQuestionRangeChanged;
  final VoidCallback onReset;

  const QuizFilterBar({
    super.key,
    required this.searchQuery,
    required this.selectedGrade,
    required this.selectedSubject,
    required this.selectedQuestionRange,
    this.grades = const [],
    this.subjects = const [],
    required this.onSearchChanged,
    required this.onGradeChanged,
    required this.onSubjectChanged,
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
                initialValue: selectedGrade,
                decoration: const InputDecoration(labelText: 'Grade'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Grades')),
                  ...grades.map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text(g),
                    ),
                  ),
                ],
                onChanged: onGradeChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedSubject,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Subjects')),
                  ...subjects.map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s),
                    ),
                  ),
                ],
                onChanged: onSubjectChanged,
              ),
            ),
          ],
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
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }
}
