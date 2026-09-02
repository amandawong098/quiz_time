import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../widgets/multiplayer_invite_dialog.dart';
import '../widgets/quiz_discussions_sheet.dart';
import '../../profile/widgets/user_detail_bottom_sheet.dart';

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
  bool _useTimer = true;
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
      final discRepo = context.read<DiscussionRepository>();
      final data = await repo.getQuizDetails(widget.quizId);
      final attempts = await repo.getQuizAttempts(widget.quizId);
      final count = await discRepo.getQuizTotalDiscussionsCount(widget.quizId);
      var quiz = data['quiz'] as Quiz;

      if (quiz.creatorId.isNotEmpty &&
          (quiz.creatorName == null || quiz.creatorName!.isEmpty)) {
        try {
          final profileRes = await Supabase.instance.client
              .from('profiles')
              .select('name, avatar_url')
              .eq('id', quiz.creatorId)
              .maybeSingle();
          if (profileRes != null) {
            quiz = Quiz(
              id: quiz.id,
              creatorId: quiz.creatorId,
              title: quiz.title,
              description: quiz.description,
              isPublic: quiz.isPublic,
              imageUrl: quiz.imageUrl,
              createdAt: quiz.createdAt,
              questionCount: quiz.questionCount,
              creatorName: profileRes['name'] as String?,
              creatorAvatarUrl: profileRes['avatar_url'] as String?,
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _quiz = quiz;
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
                  isLocked: !context.read<AuthRepository>().isAdmin &&
                      (!_hasPlayedBefore && _quiz!.creatorId != Supabase.instance.client.auth.currentUser?.id),
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
                if (_quiz!.creatorId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      UserDetailBottomSheet.show(
                        context,
                        userId: _quiz!.creatorId,
                        name: _quiz!.creatorName ?? 'Author',
                        avatarUrl: _quiz!.creatorAvatarUrl,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.deepPurple.shade100,
                            backgroundImage: (_quiz!.creatorAvatarUrl != null &&
                                    _quiz!.creatorAvatarUrl!.isNotEmpty)
                                ? NetworkImage(_quiz!.creatorAvatarUrl!)
                                : null,
                            child: (_quiz!.creatorAvatarUrl == null ||
                                    _quiz!.creatorAvatarUrl!.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 11, color: Colors.deepPurple)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _quiz!.creatorName ?? 'Author',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('${_questions.length} Questions')),
                  ],
                ),
                const SizedBox(height: 32),
                if (context.watch<AuthRepository>().isAdmin)
                  _buildAdminQuestionInspection()
                else
                  Column(
                    children: [
                      SizedBox(
                        width: 220,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Turn on Timer', style: TextStyle(fontWeight: FontWeight.bold)),
                            Switch(
                              value: _useTimer,
                              activeThumbColor: Colors.deepPurple,
                              activeTrackColor: Colors.deepPurple.shade100,
                              onChanged: (val) {
                                setState(() {
                                  _useTimer = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shuffle Questions', style: TextStyle(fontWeight: FontWeight.bold)),
                            Switch(
                              value: _shuffleQuestions,
                              activeThumbColor: Colors.deepPurple,
                              activeTrackColor: Colors.deepPurple.shade100,
                              onChanged: (val) {
                                setState(() {
                                  _shuffleQuestions = val;
                                });
                              },
                            ),
                          ],
                        ),
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
                            context.push('/quiz/${widget.quizId}/take?shuffle=$_shuffleQuestions&useTimer=$_useTimer');
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
                                  useTimer: _useTimer,
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

  Widget _buildAdminQuestionInspection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: Colors.amber.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Admin Inspection Mode: Full questions, correct answers, and explanations are directly visible below.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_questions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No questions found in this quiz.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final q = _questions[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Q${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.questionText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...q.options.map((opt) {
                        final isCorrect = opt.isCorrect;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrect ? Colors.green.shade300 : Colors.grey.shade200,
                              width: isCorrect ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: isCorrect ? Colors.green.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  opt.optionText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                                    color: isCorrect ? Colors.green.shade900 : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isCorrect)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Correct',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade800),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Explanation: ${q.explanation}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}


