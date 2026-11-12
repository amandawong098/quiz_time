import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../widgets/quiz_discussions_sheet.dart';
import '../widgets/kahoot_multiplayer_views.dart';

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
  RealtimeChannel? _liveBroadcastChannel;
  Timer? _liveSyncTimer;
  String? _quizTitle;
  Map<String, int> _questionDiscussionCounts = {};
  int _totalDiscussionsCount = 0;
  bool _canPostDiscussion = false;

  // Live multiplayer visual state (progress, streaks, recent score deltas, floating emojis)
  final Map<String, int> _playerQuestionIndex = {};
  final Map<String, int> _playerStreaks = {};
  final Map<String, int> _recentPointsDelta = {};
  final Map<String, Timer> _deltaTimers = {};
  final List<FloatingEmoji> _activeFloatingEmojis = [];

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
      final discRepo = context.read<DiscussionRepository>();
      final authRepo = context.read<AuthRepository>();
      final quizData = await repo.getQuizDetails(widget.quizId);
      final attempts = await repo.getQuizAttempts(widget.quizId);
      final counts = await discRepo.getQuizQuestionsDiscussionsCount(widget.quizId);
      final totalCount = await discRepo.getQuizTotalDiscussionsCount(widget.quizId);

      bool canPost = false;
      try {
        final perm = await discRepo.checkLearnerCanPostDiscussion(
          userId: Supabase.instance.client.auth.currentUser?.id,
          isUserAdmin: authRepo.isAdmin,
          quizId: widget.quizId,
        );
        canPost = perm.canPost;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _quizTitle = (quizData['quiz'] as Quiz).title;
          _questionDiscussionCounts = counts;
          _totalDiscussionsCount = totalCount;
          _canPostDiscussion = canPost;
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
        final newList = List<Map<String, dynamic>>.from(response as List);

        // Detect score increases from DB sync to trigger "+X pts" pop badge
        final oldScores = <String, int>{
          for (final p in _challengePlayers)
            if (p['user_id'] != null)
              p['user_id'] as String: (p['score'] as num?)?.toInt() ?? 0,
        };
        for (final p in newList) {
          final uId = p['user_id'] as String?;
          if (uId == null) continue;
          final newScore = (p['score'] as num?)?.toInt() ?? 0;
          final prevScore = oldScores[uId];
          if (prevScore != null && newScore > prevScore) {
            _showRecentDelta(uId, newScore - prevScore);
          }
        }

        setState(() {
          _challengePlayers = newList;
        });

        if (_isChallengeFinished) {
          _liveSyncTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint('Error loading challenge players: $e');
    }
  }

  void _showRecentDelta(String userId, int delta) {
    if (delta <= 0) return;
    _deltaTimers[userId]?.cancel();
    if (mounted) {
      setState(() {
        _recentPointsDelta[userId] = delta;
      });
    }
    _deltaTimers[userId] = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _recentPointsDelta.remove(userId);
        });
      }
    });
  }

  void _triggerLocalEmoji(String emoji) {
    if (!mounted) return;
    final now = DateTime.now();
    final random = Random();
    setState(() {
      _activeFloatingEmojis.removeWhere(
        (e) => now.difference(e.createdAt).inMilliseconds > 2500,
      );
      _activeFloatingEmojis.add(
        FloatingEmoji(
          id: '${now.millisecondsSinceEpoch}_${random.nextInt(1000)}',
          emoji: emoji,
          xRatio: 0.15 + random.nextDouble() * 0.7,
          scale: 0.9 + random.nextDouble() * 0.4,
          createdAt: now,
        ),
      );
    });
  }

  void _sendEmoji(String emoji) {
    _triggerLocalEmoji(emoji);
    _liveBroadcastChannel?.sendBroadcastMessage(
      event: 'player_reaction',
      payload: {
        'userId': Supabase.instance.client.auth.currentUser?.id,
        'emoji': emoji,
      },
    );
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

    // Also subscribe to live broadcast channel for instant per-question updates & emoji reactions
    _liveBroadcastChannel = client.channel('public:quiz_challenge_live:${widget.challengeId!}')
      ..onBroadcast(
        event: 'player_answered',
        callback: (payload) {
          final uId = payload['userId'] as String?;
          final qIdx = payload['questionIndex'] as int?;
          final pts = (payload['pointsEarned'] as num?)?.toInt() ?? 0;
          final totalScore = (payload['totalScore'] as num?)?.toInt();
          final streak = (payload['streak'] as num?)?.toInt();
          final acc = (payload['accuracy'] as num?)?.toDouble();

          if (uId != null && mounted) {
            setState(() {
              if (qIdx != null) _playerQuestionIndex[uId] = qIdx + 1;
              if (streak != null) _playerStreaks[uId] = streak;
              for (final p in _challengePlayers) {
                if (p['user_id'] == uId) {
                  if (totalScore != null) p['score'] = totalScore;
                  if (acc != null) p['accuracy'] = acc;
                }
              }
            });
            if (pts > 0) {
              _showRecentDelta(uId, pts);
            }
          }
          _loadChallengePlayers();
        },
      )
      ..onBroadcast(
        event: 'player_progress',
        callback: (payload) {
          final uId = payload['userId'] as String?;
          final qIdx = payload['questionIndex'] as int?;
          final streak = (payload['streak'] as num?)?.toInt();
          final totalScore = (payload['totalScore'] as num?)?.toInt();
          if (uId != null && mounted) {
            setState(() {
              if (qIdx != null) _playerQuestionIndex[uId] = qIdx + 1;
              if (streak != null) _playerStreaks[uId] = streak;
              if (totalScore != null) {
                for (final p in _challengePlayers) {
                  if (p['user_id'] == uId && totalScore > ((p['score'] as num?)?.toInt() ?? 0)) {
                    p['score'] = totalScore;
                  }
                }
              }
            });
          }
        },
      )
      ..onBroadcast(
        event: 'player_quit',
        callback: (payload) {
          final uId = payload['userId'] as String?;
          final totalScore = (payload['totalScore'] as num?)?.toInt();
          final acc = (payload['accuracy'] as num?)?.toDouble();
          if (uId != null && mounted) {
            setState(() {
              for (final p in _challengePlayers) {
                if (p['user_id'] == uId) {
                  p['is_quit'] = true;
                  p['completed_at'] = DateTime.now().toIso8601String();
                  if (totalScore != null) p['score'] = totalScore;
                  if (acc != null) p['accuracy'] = acc;
                }
              }
            });
          }
          _loadChallengePlayers();
        },
      )
      ..onBroadcast(
        event: 'player_finished',
        callback: (payload) {
          final uId = payload['userId'] as String?;
          final totalScore = (payload['totalScore'] as num?)?.toInt();
          final acc = (payload['accuracy'] as num?)?.toDouble();
          if (uId != null && mounted) {
            setState(() {
              for (final p in _challengePlayers) {
                if (p['user_id'] == uId) {
                  p['completed_at'] = DateTime.now().toIso8601String();
                  if (totalScore != null) p['score'] = totalScore;
                  if (acc != null) p['accuracy'] = acc;
                }
              }
            });
          }
          _loadChallengePlayers();
        },
      )
      ..onBroadcast(
        event: 'player_reaction',
        callback: (payload) {
          final emoji = payload['emoji'] as String?;
          final senderId = payload['userId'] as String?;
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (emoji != null && senderId != currentUserId) {
            _triggerLocalEmoji(emoji);
          }
        },
      )
      ..subscribe();

    // Periodic live sync while any player is still playing
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && !_isChallengeFinished) {
        _loadChallengePlayers();
      }
    });
  }

  void _unsubscribeChallengePlayers() {
    _liveSyncTimer?.cancel();
    for (final timer in _deltaTimers.values) {
      timer.cancel();
    }
    _deltaTimers.clear();
    if (_playersChannel != null) {
      Supabase.instance.client.removeChannel(_playersChannel!);
      _playersChannel = null;
    }
    if (_liveBroadcastChannel != null) {
      Supabase.instance.client.removeChannel(_liveBroadcastChannel!);
      _liveBroadcastChannel = null;
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
      final int scoreA = (a['score'] as num?)?.toInt() ?? 0;
      final int scoreB = (b['score'] as num?)?.toInt() ?? 0;
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // Descending by Kahoot points
      }
      final double accA = (a['accuracy'] as num?)?.toDouble() ?? 0.0;
      final double accB = (b['accuracy'] as num?)?.toDouble() ?? 0.0;
      return accB.compareTo(accA); // Descending by accuracy
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
          final questionId = answerData['question_id'] as String?;
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
                      Row(
                        children: [
                          Text(
                            'Question ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_canPostDiscussion && questionId != null) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => QuizDiscussionsSheet(
                                    quizId: widget.quizId,
                                    questionId: questionId,
                                    quizTitle: _quizTitle ?? 'Quiz',
                                    questionText: questionText,
                                    questionNumber: index + 1,
                                    isLocked: false,
                                    onTopicCreated: () {
                                      _loadData();
                                    },
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18,
                                color: Colors.deepPurple,
                              ),
                              label: Text(
                                '${_questionDiscussionCounts[questionId] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                  if (answerData['explanation'] != null && (answerData['explanation'] as String).trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange.shade800),
                              const SizedBox(width: 6),
                              const Text(
                                'Explanation',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            answerData['explanation'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
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
        }),
      ],
    );
  }

  Widget _buildMultiplayerRankingView() {
    final ranked = _rankedPlayers;
    final bool finished = _isChallengeFinished;
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final int totalQ = _attempt?.totalQuestions ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            finished ? 'Final Standings' : 'Current Standings',
            key: ValueKey<bool>(finished),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.deepPurple,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (!finished) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Live match in progress — rankings update in real time',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...List.generate(ranked.length, (index) {
                  final player = ranked[index];
                  final userId = player['user_id'] as String? ?? 'player_$index';
                  final isMe = userId == currentUserId;
                  final name = player['profiles'] != null ? player['profiles']['name'] as String : 'Player';
                  final completedAt = player['completed_at'];
                  final isQuit = player['is_quit'] as bool? ?? false;
                  final isStillPlaying = !isQuit && completedAt == null;
                  final score = (player['score'] as num?)?.toInt() ?? 0;
                  final accuracy = (player['accuracy'] as num?)?.toDouble() ?? 0.0;
                  final accuracyInt = accuracy.round();
                  final int playerCorrect = ((accuracy / 100.0) * totalQ).round();
                  final int playerXp = playerCorrect * 2;
                  final int? recentDelta = _recentPointsDelta[userId];
                  final int? liveQ = _playerQuestionIndex[userId];
                  final int streak = _playerStreaks[userId] ?? 0;

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
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  return AnimatedContainer(
                    key: ValueKey('rank_row_$userId'),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: recentDelta != null
                          ? Colors.green.withValues(alpha: 0.08)
                          : (isMe
                              ? Colors.deepPurple.withValues(alpha: 0.05)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: recentDelta != null
                            ? Colors.green.shade300
                            : (isMe
                                ? Colors.deepPurple.withValues(alpha: 0.2)
                                : Colors.transparent),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (isStillPlaying) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.circle, size: 7, color: Colors.green.shade600),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              liveQ != null
                                                  ? 'Playing Q${liveQ.clamp(1, totalQ)}/$totalQ'
                                                  : 'Playing live',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (streak >= 2)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Text(
                                          '🔥 $streak',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: score.toDouble()),
                              duration: const Duration(milliseconds: 550),
                              curve: Curves.easeOutCubic,
                              builder: (context, animValue, _) {
                                final displayPts = animValue.round();
                                if (isQuit) {
                                  return Text(
                                    'QUIT ($displayPts pts)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                      fontSize: 14,
                                    ),
                                  );
                                } else if (completedAt != null) {
                                  return Text(
                                    '$displayPts pts ($accuracyInt%)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                      fontSize: 14,
                                    ),
                                  );
                                } else {
                                  return Text(
                                    '$displayPts pts',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                      fontSize: 14,
                                    ),
                                  );
                                }
                              },
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                              child: recentDelta != null
                                  ? Container(
                                      key: ValueKey('delta_${userId}_$recentDelta'),
                                      margin: const EdgeInsets.only(top: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+$recentDelta pts',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            // Only display XP when the player has ended their quiz attempt (completed or quit)
                            if (isQuit || completedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '+$playerXp XP 🏆',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                // Live Emoji Reaction Bar so players on Review screen can react in real time
                Row(
                  children: [
                    Text(
                      'React live:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['🔥', '👏', '😱', '😂', '🎯', '💀', '🎉', '🤯'].map((emoji) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => _sendEmoji(emoji),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
            context.go('/discover');
          },
        ),
        actions: [
          if (_canPostDiscussion) ...[
            TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => QuizDiscussionsSheet(
                    quizId: widget.quizId,
                    quizTitle: _quizTitle ?? 'Quiz',
                    isLocked: false,
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
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.challengeId != null) ...[
                  _buildMultiplayerRankingView(),
                ],
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
                      const SizedBox(height: 8),
                      Text(
                        '+${_attempt!.correctAnswers * 2} XP Earned 🏆',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
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
                      context.go('/discover');
                    },
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
          if (widget.challengeId != null)
            Positioned.fill(
              child: FloatingEmojiOverlay(emojis: _activeFloatingEmojis),
            ),
        ],
      ),
    );
  }
}
