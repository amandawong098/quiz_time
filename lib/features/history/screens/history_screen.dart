import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../core/widgets/quiz_filter_bar.dart';

import 'package:quiz_time/l10n/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String? _selectedGrade;
  String? _selectedSubject;
  String? _selectedQuestionRange;
  bool _isLoading = true;
  List<Map<String, dynamic>> _attempts = [];
  List<String> _grades = [];
  List<String> _subjects = [];
  Locale? _currentLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_currentLocale != locale) {
      _currentLocale = locale;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<QuizRepository>();

      // Fetch categories if empty
      if (_grades.isEmpty || _subjects.isEmpty) {
        _grades = await repo.getGrades();
        _subjects = await repo.getSubjects();
      }

      final attempts = await repo.getAllQuizAttempts(
        query: _searchQuery,
        grade: _selectedGrade,
        subject: _selectedSubject,
        questionRange: _selectedQuestionRange,
      );
      if (mounted) {
        setState(() {
          _attempts = attempts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorOccurred(e.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            QuizFilterBar(
              searchQuery: _searchQuery,
              selectedGrade: _selectedGrade,
              selectedSubject: _selectedSubject,
              selectedQuestionRange: _selectedQuestionRange,
              grades: _grades,
              subjects: _subjects,
              onSearchChanged: (v) {
                _searchQuery = v;
                _loadHistory();
              },
              onGradeChanged: (v) {
                setState(() => _selectedGrade = v);
                _loadHistory();
              },
              onSubjectChanged: (v) {
                setState(() => _selectedSubject = v);
                _loadHistory();
              },
              onQuestionRangeChanged: (v) {
                setState(() => _selectedQuestionRange = v);
                _loadHistory();
              },
              onReset: () {
                setState(() {
                  _searchQuery = '';
                  _selectedGrade = null;
                  _selectedSubject = null;
                  _selectedQuestionRange = null;
                });
                _loadHistory();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _attempts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 100),
                            child: Center(child: Text(l10n.noQuizHistoryFound)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _attempts.length,
                        itemBuilder: (context, index) {
                          final attempt = _attempts[index];
                          final date = DateTime.parse(attempt['created_at']);
                          final quizTitle = attempt['quizzes']['title'];

                          int score = attempt['score'];
                          Color scoreColor;
                          if (score < 30) {
                            scoreColor = Colors.red;
                          } else if (score < 70) {
                            scoreColor = Colors.orange;
                          } else {
                            scoreColor = Colors.green;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    attempt['quizzes']['image_url'] != null
                                    ? NetworkImage(
                                        attempt['quizzes']['image_url'],
                                      )
                                    : null,
                                child: attempt['quizzes']['image_url'] == null
                                    ? const Icon(Icons.quiz)
                                    : null,
                              ),
                              title: Text(
                                quizTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${date.day}/${date.month}/${date.year} • ${l10n.correctCount(attempt['correct_answers'])}',
                              ),
                              trailing: SizedBox(
                                width: 40,
                                height: 40,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: score / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        scoreColor,
                                      ),
                                    ),
                                    Text(
                                      '$score',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: scoreColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () {
                                context.push(
                                  '/quiz/${attempt['quiz_id']}/review',
                                  extra: {'attemptId': attempt['id']},
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
