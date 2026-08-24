import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../core/widgets/quiz_filter_bar.dart';
import '../../../core/services/ai_generation_manager.dart';

class MyQuizzesScreen extends StatefulWidget {
  const MyQuizzesScreen({super.key});

  @override
  State<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _MyQuizzesScreenState extends State<MyQuizzesScreen> {
  String _searchQuery = '';
  String? _selectedQuestionRange;
  List<Quiz> _myQuizzes = [];
  bool _isLoading = true;
  String _visibilityFilter = 'All'; // All, Public, Private

  @override
  void initState() {
    super.initState();
    _loadMyQuizzes();
    AIGenerationManager().addListener(_onAIManagerStateChanged);
  }

  @override
  void dispose() {
    AIGenerationManager().removeListener(_onAIManagerStateChanged);
    super.dispose();
  }

  void _onAIManagerStateChanged() {
    if (mounted) {
      final task = AIGenerationManager().currentTask;
      if (task?.status == AITaskStatus.completed) {
        _loadMyQuizzes();
      }
      setState(() {});
    }
  }

  Future<void> _loadMyQuizzes() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<QuizRepository>();

      final quizzes = await repo.getMyQuizzes(
        query: _searchQuery,
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

  String _getQuestionBadgeEmoji(int count) {
    if (count <= 5) return '🌱';
    if (count <= 10) return '⚡';
    if (count <= 20) return '🔥';
    return '🧠';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quizzes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: FilledButton.tonalIcon(
              onPressed: () {
                context.push('/ai-quiz-generator').then((_) => _loadMyQuizzes());
              },
              icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple),
              label: const Text('AI Generator'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade50,
                foregroundColor: Colors.deepPurple.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Background AI Generation Status Banner
            Builder(
              builder: (context) {
                final aiTask = AIGenerationManager().currentTask;
                if (aiTask == null || aiTask.status != AITaskStatus.generating) {
                  return const SizedBox.shrink();
                }
                return Card(
                  color: Colors.deepPurple.shade50,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.deepPurple.shade200),
                  ),
                  child: ListTile(
                    leading: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    title: Text(
                      'AI Generating: ${aiTask.prompt.isNotEmpty ? aiTask.prompt : (aiTask.fileName ?? "Quiz")}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.deepPurple,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      aiTask.statusMessage,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        context.push('/ai-quiz-generator');
                      },
                      child: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                );
              },
            ),
            QuizFilterBar(
              searchQuery: _searchQuery,
              selectedQuestionRange: _selectedQuestionRange,
              onSearchChanged: (v) {
                _searchQuery = v;
                _loadMyQuizzes();
              },
              onQuestionRangeChanged: (v) {
                setState(() => _selectedQuestionRange = v);
                _loadMyQuizzes();
              },
              onReset: () {
                setState(() {
                  _searchQuery = '';
                  _selectedQuestionRange = null;
                });
                _loadMyQuizzes();
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _visibilityFilter == 'All',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _visibilityFilter = 'All');
                        _loadMyQuizzes();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: _visibilityFilter == 'Public',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _visibilityFilter = 'Public');
                        _loadMyQuizzes();
                      }
                    },
                  ),
                  ChoiceChip(
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
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    context.push('/quiz/${quiz.id}');
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        // Left Thumbnail (Slightly larger, rounded)
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            gradient: quiz.imageUrl == null
                                                ? LinearGradient(
                                                    colors: [
                                                      Colors.deepPurple.shade600,
                                                      Colors.indigo.shade400,
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            image: quiz.imageUrl != null
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      quiz.imageUrl!,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: quiz.imageUrl == null
                                              ? const Icon(
                                                  Icons.quiz_rounded,
                                                  size: 30,
                                                  color: Colors.white70,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        // Title & Meta Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      quiz.title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              if (quiz.description != null &&
                                                  quiz.description!
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                Text(
                                                  quiz.description!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              // Visibility Label (green for public, gray for private)
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: quiz.isPublic
                                                      ? Colors.green.shade50
                                                      : Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: quiz.isPublic
                                                        ? Colors.green.shade300
                                                        : Colors.grey.shade300,
                                                  ),
                                                ),
                                                child: Text(
                                                  quiz.isPublic ? 'Public' : 'Private',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: quiz.isPublic
                                                        ? Colors.green.shade700
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              // Dynamic Badge count
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.deepPurple.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${_getQuestionBadgeEmoji(quiz.questionCount)}  ${quiz.questionCount} Questions',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors
                                                        .deepPurple
                                                        .shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Inline actions
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_rounded,
                                                size: 22,
                                              ),
                                              color: Colors.deepPurple.shade600,
                                              tooltip: 'Edit quiz',
                                              onPressed: () {
                                                context
                                                    .push(
                                                      '/create-quiz',
                                                      extra: {'quiz': quiz},
                                                    )
                                                    .then(
                                                      (_) => _loadMyQuizzes(),
                                                    );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_rounded,
                                                size: 22,
                                              ),
                                              color: Colors.red.shade600,
                                              tooltip: 'Delete quiz',
                                              onPressed: () async {
                                                final repo =
                                                    context.read<
                                                      QuizRepository
                                                    >();
                                                final confirm =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      builder:
                                                          (ctx) => AlertDialog(
                                                            title: const Text(
                                                              'Delete Quiz',
                                                            ),
                                                            content: const Text(
                                                              'Are you sure you want to delete this quiz?',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () =>
                                                                        Navigator
                                                                            .pop(
                                                                              ctx,
                                                                              false,
                                                                            ),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              TextButton(
                                                                onPressed:
                                                                    () =>
                                                                        Navigator
                                                                            .pop(
                                                                              ctx,
                                                                              true,
                                                                            ),
                                                                child:
                                                                    const Text(
                                                                      'Delete',
                                                                      style:
                                                                          TextStyle(
                                                                            color:
                                                                                Colors
                                                                                    .red,
                                                                          ),
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                if (confirm == true) {
                                                  await repo.deleteQuiz(
                                                    quiz.id,
                                                  );
                                                  _loadMyQuizzes();
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
