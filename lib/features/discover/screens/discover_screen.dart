import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../core/widgets/quiz_filter_bar.dart';
import '../../../core/widgets/notification_badge.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _searchQuery = '';
  String? _selectedGrade;
  String? _selectedSubject;
  String? _selectedQuestionRange;
  List<Quiz> _quizzes = [];
  List<String> _grades = [];
  List<String> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<QuizRepository>();

      if (_grades.isEmpty || _subjects.isEmpty) {
        _grades = await repo.getGrades();
        _subjects = await repo.getSubjects();
      }

      final results = await repo.getPublicQuizzes(
        query: _searchQuery,
        grade: _selectedGrade,
        subject: _selectedSubject,
        questionRange: _selectedQuestionRange,
      );
      if (mounted) {
        setState(() {
          _quizzes = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        actions: const [NotificationIconBadge()],
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
                _loadQuizzes();
              },
              onGradeChanged: (v) {
                setState(() => _selectedGrade = v);
                _loadQuizzes();
              },
              onSubjectChanged: (v) {
                setState(() => _selectedSubject = v);
                _loadQuizzes();
              },
              onQuestionRangeChanged: (v) {
                setState(() => _selectedQuestionRange = v);
                _loadQuizzes();
              },
              onReset: () {
                setState(() {
                  _searchQuery = '';
                  _selectedGrade = null;
                  _selectedSubject = null;
                  _selectedQuestionRange = null;
                });
                _loadQuizzes();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadQuizzes,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _quizzes.isEmpty
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
                            itemCount: _quizzes.length,
                            itemBuilder: (context, index) {
                              final quiz = _quizzes[index];
                              return Card(
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
                                    '${quiz.grade} • ${quiz.subject}',
                                  ),
                                  onTap: () {
                                    context.push('/quiz/${quiz.id}');
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
