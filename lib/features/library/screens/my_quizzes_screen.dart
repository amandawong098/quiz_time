import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../core/widgets/quiz_filter_bar.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMyQuizzes();
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
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quizzes'),
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
                  label: const Text('All'),
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
                  label: const Text('Public'),
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
                  label: const Text('Private'),
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
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(child: Text('No quizzes found.')),
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
                                    '${quiz.grade ?? ''} • ${quiz.subject ?? ''} • ${quiz.isPublic ? 'Public' : 'Private'}',
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
                                              title: const Text('Delete Quiz'),
                                              content: const Text(
                                                'Are you sure you want to delete this quiz?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        ctx,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        ctx,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
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
