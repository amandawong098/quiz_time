import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';

class QuizReviewScreen extends StatefulWidget {
  final String quizId;
  final String attemptId;
  final String? challengeId;

  const QuizReviewScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
    this.challengeId,
  });

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  bool _isLoading = true;
  QuizAttempt? _attempt;
  List<Map<String, dynamic>> _challengePlayers = [];
  RealtimeChannel? _playersChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.challengeId != null) {
      _loadChallengePlayers();
      _subscribeChallengePlayers();
    }
  }

  @override
  void dispose() {
    _unsubscribeChallengePlayers();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final repo = context.read<QuizRepository>();
      final attempts = await repo.getQuizAttempts(widget.quizId);

      if (mounted) {
        setState(() {
          try {
            _attempt = attempts.firstWhere((a) => a.id == widget.attemptId);
          } catch (e) {
            _attempt = attempts.isNotEmpty ? attempts.last : null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadChallengePlayers() async {
    if (widget.challengeId == null) return;
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('quiz_challenge_players')
          .select('*, profiles!user_id(name)')
          .eq('challenge_id', widget.challengeId!);

      if (mounted) {
        setState(() {
          _challengePlayers = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('Error loading challenge players: $e');
    }
  }

  void _subscribeChallengePlayers() {
    if (widget.challengeId == null) return;
    final client = Supabase.instance.client;

    _playersChannel = client.channel('public:quiz_challenge_players:review_${widget.challengeId!}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'quiz_challenge_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'challenge_id',
          value: widget.challengeId!,
        ),
        callback: (payload) {
          _loadChallengePlayers(); // Reload to get joins
        },
      )
      ..subscribe();
  }

  void _unsubscribeChallengePlayers() {
    if (_playersChannel != null) {
      Supabase.instance.client.removeChannel(_playersChannel!);
      _playersChannel = null;
    }
  }

  bool get _isChallengeFinished {
    if (widget.challengeId == null) return true;
    if (_challengePlayers.isEmpty) return false;

    return _challengePlayers.every((player) {
      final completedAt = player['completed_at'];
      final isQuit = player['is_quit'] as bool? ?? false;
      final status = player['status'] as String? ?? 'pending';

      if (status != 'accepted') return true;

      return completedAt != null || isQuit;
    });
  }

  List<Map<String, dynamic>> get _rankedPlayers {
    final accepted = _challengePlayers.where((p) => p['status'] == 'accepted').toList();
    accepted.sort((a, b) {
      final double accA = (a['accuracy'] as num?)?.toDouble() ?? 0.0;
      final double accB = (b['accuracy'] as num?)?.toDouble() ?? 0.0;
      return accB.compareTo(accA); // Descending
    });
    return accepted;
  }

  Widget _buildDetailedAnalysis() {
    if (_attempt == null || _attempt!.userAnswers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Detailed Analysis',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_attempt!.userAnswers.length, (index) {
          final answerData = _attempt!.userAnswers[index];
          final questionText = answerData['question_text'] ?? 'Question';
          final List options = answerData['options'] ?? [];
          final selectedOptionIds = answerData['selected_option_ids'] as List? ?? 
              (answerData['selected_option_id'] != null ? [answerData['selected_option_id']] : []);
          final isUnattempted = selectedOptionIds.isEmpty;

          final correctOptionIds = options
              .where((o) => o['is_correct'] == true)
              .map((o) => o['id'])
              .toSet();

          final isCorrect = !isUnattempted &&
              selectedOptionIds.length == correctOptionIds.length &&
              selectedOptionIds.every((id) => correctOptionIds.contains(id));

          return Card(
            color: isUnattempted ? Colors.grey.shade200 : null,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isUnattempted)
                        const Text(
                          'Unattempted',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        )
                      else if (isCorrect)
                        const Text(
                          'Correct',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        )
                      else
                        const Text(
                          'Incorrect',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isUnattempted)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Unattempted (Timeout/Quit)',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isCorrect = opt['is_correct'] == true;
                    final isSelected = selectedOptionIds.contains(opt['id']);

                    Color? bgColor;
                    if (isCorrect) {
                      bgColor = isUnattempted
                          ? Colors.grey.shade400
                          : Colors.green.shade300;
                    } else if (isSelected) {
                      bgColor = Colors.red.shade300;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            bgColor ??
                            (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        opt['text'] ?? '',
                        style: TextStyle(
                          fontWeight: (isCorrect || isSelected)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMultiplayerStatusView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        const CircularProgressIndicator(color: Colors.deepPurple),
        const SizedBox(height: 24),
        const Text(
          'Waiting for other players to finish...',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Competitors status:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Divider(),
                ..._challengePlayers.where((p) => p['status'] == 'accepted').map((p) {
                  final name = p['profiles'] != null ? p['profiles']['name'] as String : 'Player';
                  final completedAt = p['completed_at'];
                  final isQuit = p['is_quit'] as bool? ?? false;

                  String statusText;
                  Color color;
                  IconData icon;

                  if (isQuit) {
                    statusText = 'Quit halfway';
                    color = Colors.grey;
                    icon = Icons.cancel_rounded;
                  } else if (completedAt != null) {
                    statusText = 'Completed';
                    color = Colors.green;
                    icon = Icons.check_circle_rounded;
                  } else {
                    statusText = 'Still playing...';
                    color = Colors.orange;
                    icon = Icons.hourglass_top_rounded;
                  }

                  return ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(
                      statusText,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplayerRankingView() {
    final ranked = _rankedPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Final Standings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: List.generate(ranked.length, (index) {
                final player = ranked[index];
                final name = player['profiles'] != null ? player['profiles']['name'] as String : 'Player';
                final isQuit = player['is_quit'] as bool? ?? false;
                final accuracy = (player['accuracy'] as num?)?.toDouble() ?? 0.0;
                final accuracyInt = accuracy.round();

                Widget leading;
                if (index == 0) {
                  leading = const Icon(Icons.emoji_events, color: Colors.amber, size: 28);
                } else if (index == 1) {
                  leading = const Icon(Icons.emoji_events, color: Colors.grey, size: 28);
                } else if (index == 2) {
                  leading = const Icon(Icons.emoji_events, color: Colors.brown, size: 28);
                } else {
                  leading = CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  );
                }

                return ListTile(
                  leading: leading,
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    isQuit ? 'QUIT (0%)' : '$accuracyInt%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isQuit ? Colors.redAccent : Colors.deepPurple,
                      fontSize: 14,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSummaryBox({required String title, required String value}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_attempt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Attempt not found')),
      );
    }

    final finished = _isChallengeFinished;

    Color scoreColor;
    if (_attempt!.score < 30) {
      scoreColor = Colors.red;
    } else if (_attempt!.score < 70) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.challengeId != null && !finished) ...[
              _buildMultiplayerStatusView(),
            ] else ...[
              if (widget.challengeId != null) ...[
                _buildMultiplayerRankingView(),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _attempt!.score / 100,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                          ),
                          Text(
                            '${_attempt!.score}%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _attempt!.score < 40
                            ? 'Try Again!'
                            : (_attempt!.score < 80 ? 'Good Job!' : 'Outstanding!'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryBox(
                      title: 'Correct',
                      value: _attempt!.correctAnswers.toString(),
                    ),
                    _buildSummaryBox(
                      title: 'Wrong',
                      value: _attempt!.wrongAnswers.toString(),
                    ),
                    _buildSummaryBox(
                      title: 'Avg Time',
                      value: '${_attempt!.avgTimePerQuestion?.toStringAsFixed(1) ?? 0}s',
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ] else ...[
                // Solo Mode Attempt view
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _attempt!.score / 100,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                          ),
                          Text(
                            '${_attempt!.score}%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _attempt!.score < 40
                            ? 'Try Again!'
                            : (_attempt!.score < 80 ? 'Good Job!' : 'Outstanding!'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSummaryBox(
                            title: 'Correct',
                            value: _attempt!.correctAnswers.toString(),
                          ),
                          _buildSummaryBox(
                            title: 'Wrong',
                            value: _attempt!.wrongAnswers.toString(),
                          ),
                          _buildSummaryBox(
                            title: 'Avg Time',
                            value: '${_attempt!.avgTimePerQuestion?.toStringAsFixed(1) ?? 0}s',
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
              _buildDetailedAnalysis(),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Quizzes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    context.go('/');
                  },
                ),
              ),
              const SizedBox(height: 48),
            ],
          ],
        ),
      ),
    );
  }
}
