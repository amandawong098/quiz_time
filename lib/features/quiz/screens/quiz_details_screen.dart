import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../widgets/multiplayer_invite_dialog.dart';
import '../widgets/quiz_discussions_sheet.dart';

class QuizDetailsScreen extends StatefulWidget {
  final String quizId;
  const QuizDetailsScreen({super.key, required this.quizId});

  @override
  State<QuizDetailsScreen> createState() => _QuizDetailsScreenState();
}

class _QuizDetailsScreenState extends State<QuizDetailsScreen> {
  bool _isLoading = true;
  Quiz? _quiz;
  List<Question> _questions = [];
  bool _shuffleQuestions = false;
  int _totalDiscussionsCount = 0;
  bool _hasPlayedBefore = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repo = context.read<QuizRepository>();
      final data = await repo.getQuizDetails(widget.quizId);
      final attempts = await repo.getQuizAttempts(widget.quizId);
      final discRepo = context.read<DiscussionRepository>();
      final count = await discRepo.getQuizTotalDiscussionsCount(widget.quizId);
      if (mounted) {
        setState(() {
          _quiz = data['quiz'] as Quiz;
          _questions = data['questions'] as List<Question>;
          _totalDiscussionsCount = count;
          _hasPlayedBefore = attempts.isNotEmpty;
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_quiz == null) {
      return const Scaffold(body: Center(child: Text('No quizzes found.')));
    }



    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Details'),
        leading: Navigator.of(context).canPop()
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.go('/discover');
                },
              ),
        actions: [
          TextButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => QuizDiscussionsSheet(
                  quizId: widget.quizId,
                  quizTitle: _quiz!.title,
                  isLocked: !_hasPlayedBefore,
                  onTopicCreated: () {
                    _loadData();
                  },
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22, color: Colors.white),
            label: Text(
              '$_totalDiscussionsCount',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_quiz!.imageUrl != null)
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(_quiz!.imageUrl!),
                  )
                else
                  const CircleAvatar(
                    radius: 60,
                    child: Icon(Icons.quiz, size: 60),
                  ),
                const SizedBox(height: 16),
                Text(
                  _quiz!.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_quiz!.description != null) ...[
                  const SizedBox(height: 8),
                  Text(_quiz!.description!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(_quiz!.grade),
                    ),
                    Chip(
                      label: Text(_quiz!.subject),
                    ),
                    Chip(label: Text('${_questions.length} Questions')),
                  ],
                ),
                const SizedBox(height: 32),
                 Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Shuffle Questions', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Switch(
                          value: _shuffleQuestions,
                          activeThumbColor: Colors.deepPurple,
                          onChanged: (val) {
                            setState(() {
                              _shuffleQuestions = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person),
                        label: const Text('Play Solo Mode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          context.push('/quiz/${widget.quizId}/take?shuffle=$_shuffleQuestions');
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_quiz!.isPublic == false) ...[
                      SizedBox(
                        width: 280,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Multiplayer Mode (Disabled)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: null, // Disabled
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Multiplayer mode is turned off for private quizzes.',
                        style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ] else ...[
                      SizedBox(
                        width: 280,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.people),
                          label: const Text('Play Multiplayer Mode'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => MultiplayerInviteDialog(
                                quizId: widget.quizId,
                                quizTitle: _quiz!.title,
                                shuffle: _shuffleQuestions,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


