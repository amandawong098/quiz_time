import 'package:flutter/material.dart';
import 'package:quiz_time/l10n/app_localizations.dart';
import '../utils/l10n_utils.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: TextEditingController(text: searchQuery)
            ..selection = TextSelection.collapsed(offset: searchQuery.length),
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: l10n.searchQuizzesLabel,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedGrade,
                decoration: InputDecoration(labelText: l10n.gradeLabel),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.allGrades)),
                  ...grades.map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text(L10nUtils.getLocalizedGrade(g, l10n)),
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
                decoration: InputDecoration(labelText: l10n.subjectLabel),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.allSubjects)),
                  ...subjects.map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(L10nUtils.getLocalizedSubject(s, l10n)),
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
                decoration: InputDecoration(labelText: l10n.noOfQuestionsLabel),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.any)),
                  const DropdownMenuItem(value: '1-5', child: Text('1-5')),
                  const DropdownMenuItem(value: '5-10', child: Text('5-10')),
                  const DropdownMenuItem(value: '10-20', child: Text('10-20')),
                  const DropdownMenuItem(value: '>20', child: Text('>20')),
                ],
                onChanged: onQuestionRangeChanged,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reset),
            ),
          ],
        ),
      ],
    );
  }
}
