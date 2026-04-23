import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../core/widgets/quiz_filter_bar.dart';
import '../../../core/utils/l10n_utils.dart';

import 'package:quiz_time/l10n/app_localizations.dart';

class MyQuizzesScreen extends StatefulWidget {
  const MyQuizzesScreen({super.key});

  @override
  State<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _MyQuizzesScreenState extends State<MyQuizzesScreen> {
  String _searchQuery = '';
  String? _selectedGrade;
  String? _selectedSubject;
  String? _selectedQuestionRange;
  List<Quiz> _myQuizzes = [];
  List<String> _grades = [];
  List<String> _subjects = [];
  bool _isLoading = true;
  String _visibilityFilter = 'All'; // All, Public, Private
  Locale? _currentLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_currentLocale != locale) {
      _currentLocale = locale;
      _loadMyQuizzes();
    }
  }

  Future<void> _loadMyQuizzes() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<QuizRepository>();
      
      // Fetch categories if empty
      if (_grades.isEmpty || _subjects.isEmpty) {
        _grades = await repo.getGrades();
        _subjects = await repo.getSubjects();
      }

      final quizzes = await repo.getMyQuizzes(
        query: _searchQuery,
        grade: _selectedGrade,
        subject: _selectedSubject,
        questionRange: _selectedQuestionRange,
        isPublic: _visibilityFilter == 'All' ? null : _visibilityFilter == 'Public',
      );
      if (mounted) {
        setState(() {
          _myQuizzes = quizzes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOccurred(e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myQuizzes),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/create-quiz').then((_) => _loadMyQuizzes());
            },
          ),
        ],
      ),
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
                _loadMyQuizzes();
              },
              onGradeChanged: (v) {
                setState(() => _selectedGrade = v);
                _loadMyQuizzes();
              },
              onSubjectChanged: (v) {
                setState(() => _selectedSubject = v);
                _loadMyQuizzes();
              },
              onQuestionRangeChanged: (v) {
                setState(() => _selectedQuestionRange = v);
                _loadMyQuizzes();
              },
              onReset: () {
                setState(() {
                  _searchQuery = '';
                  _selectedGrade = null;
                  _selectedSubject = null;
                  _selectedQuestionRange = null;
                });
                _loadMyQuizzes();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  label: Text(l10n.all),
                  selected: _visibilityFilter == 'All',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _visibilityFilter = 'All');
                      _loadMyQuizzes();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.public),
                  selected: _visibilityFilter == 'Public',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _visibilityFilter = 'Public');
                      _loadMyQuizzes();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.private),
                  selected: _visibilityFilter == 'Private',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _visibilityFilter = 'Private');
                      _loadMyQuizzes();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMyQuizzes,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _myQuizzes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 100),
                                child: Center(child: Text(l10n.noQuizzesFound)),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _myQuizzes.length,
                            itemBuilder: (context, index) {
                              final quiz = _myQuizzes[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ListTile(
                                  leading:
                                      quiz.imageUrl != null
                                          ? CircleAvatar(
                                            backgroundImage: NetworkImage(
                                              quiz.imageUrl!,
                                            ),
                                          )
                                          : const CircleAvatar(
                                            child: Icon(Icons.quiz),
                                          ),
                                  title: Text(
                                    quiz.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${L10nUtils.getLocalizedGrade(quiz.grade, l10n)} • ${L10nUtils.getLocalizedSubject(quiz.subject, l10n)} • ${quiz.isPublic ? l10n.public : l10n.private}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (ctx) => AlertDialog(
                                              title: Text(l10n.deleteQuiz),
                                              content: Text(
                                                l10n.areYouSureYouWantToDeleteThisQuiz,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        ctx,
                                                        false,
                                                      ),
                                                  child: Text(l10n.cancel),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        ctx,
                                                        true,
                                                      ),
                                                  child: Text(
                                                    l10n.delete,
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
                                      if (confirm == true) {
                                        await context
                                            .read<QuizRepository>()
                                            .deleteQuiz(quiz.id);
                                        _loadMyQuizzes();
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    context
                                        .push(
                                          '/create-quiz',
                                          extra: {'quiz': quiz},
                                        )
                                        .then((_) => _loadMyQuizzes());
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
