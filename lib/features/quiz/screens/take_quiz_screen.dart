import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../data/repositories/friendship_repository.dart';
import '../widgets/kahoot_multiplayer_views.dart';

enum KahootRoundPhase {
  question,
  reveal,
  scoreboard,
}

class TakeQuizScreen extends StatefulWidget {
  final String quizId;
  final String? challengeId;
  final bool shuffle;
  final bool isPreview;
  final String? initialQuestionId;
  final bool useTimer;

  const TakeQuizScreen({
    super.key,
    required this.quizId,
    this.challengeId,
    this.shuffle = false,
    this.isPreview = false,
    this.initialQuestionId,
    this.useTimer = true,
  });

  static bool isActive = false;

  @override
  State<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> {
  bool _isLoading = true;
  List<Question> _questions = [];

  int _currentIndex = 0;
  int _remainingSeconds = 0;
  Timer? _timer;

  Set<String> _selectedOptionIds = {};
  bool _isAnswerChecked = false;
  bool? _lastAnswerCorrect;

  int _correctCount = 0;
  int _wrongCount = 0;
  final List<int> _timeTakenPerQuestion = [];
  int _currentQuestionStartTime = 0;
  final List<Map<String, dynamic>> _userAnswers = [];
  bool _useTimer = true;

  // ----------------------------------------------------
  // Multiplayer / Kahoot State
  // ----------------------------------------------------
  KahootRoundPhase _multiplayerPhase = KahootRoundPhase.question;
  RealtimeChannel? _challengeChannel;
  String? _currentUserId;
  bool _isHost = false;
  final Map<String, PlayerLiveState> _playerStates = {};
  bool _hasLockedAnswer = false;
  int _myRoundPoints = 0;
  int _myTotalScore = 0;
  int _myStreak = 0;

  Timer? _revealTimer;
  Timer? _scoreboardTimer;
  int _scoreboardSecondsRemaining = 5;
  Timer? _hostInactivityTimer;

  final List<FloatingEmoji> _activeFloatingEmojis = [];
  final Map<String, int> _optionVoteCounts = {};

  @override
  void initState() {
    super.initState();
    _useTimer = widget.useTimer;
    TakeQuizScreen.isActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendshipRepository>().setUserPlaying(true);
    });
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final repo = context.read<QuizRepository>();
      final data = await repo.getQuizDetails(widget.quizId);

      final client = Supabase.instance.client;
      _currentUserId = client.auth.currentUser?.id;

      bool isShuffle = false;
      bool useTimer = widget.useTimer;

      if (widget.challengeId != null) {
        try {
          final challenge = await client
              .from('quiz_challenges')
              .select('host_id, shuffle, use_timer')
              .eq('id', widget.challengeId!)
              .single();
          _isHost = (_currentUserId == challenge['host_id']);
          isShuffle = challenge['shuffle'] as bool? ?? false;
          useTimer = challenge['use_timer'] as bool? ?? true;
        } catch (_) {
          final challenge = await client
              .from('quiz_challenges')
              .select('host_id, shuffle')
              .eq('id', widget.challengeId!)
              .single();
          _isHost = (_currentUserId == challenge['host_id']);
          isShuffle = challenge['shuffle'] as bool? ?? false;
        }

        // Load multiplayer players
        try {
          final playersRes = await client
              .from('quiz_challenge_players')
              .select('*, profiles!user_id(name, avatar_url)')
              .eq('challenge_id', widget.challengeId!);

          for (var row in (playersRes as List)) {
            final uId = row['user_id'] as String;
            final profile = row['profiles'] as Map<String, dynamic>?;
            final name = profile?['name'] as String? ?? 'Player';
            final avatar = profile?['avatar_url'] as String?;
            final isQuit = row['is_quit'] as bool? ?? false;
            _playerStates[uId] = PlayerLiveState(
              userId: uId,
              name: name,
              avatarUrl: avatar,
              isQuit: isQuit,
              isHost: uId == row['challenge_id'],
            );
          }
        } catch (e) {
          debugPrint('Error loading challenge players: $e');
        }

        _subscribeChallengeChannel();
      }

      if (mounted) {
        setState(() {
          _questions = data['questions'] as List<Question>;
          _useTimer = useTimer;

          // If multiplayer shuffle, use deterministic random seed so all devices share identical order
          if (isShuffle || widget.shuffle) {
            if (widget.challengeId != null) {
              _questions.shuffle(Random(widget.challengeId.hashCode));
            } else if (widget.initialQuestionId == null) {
              _questions.shuffle();
            }
          }

          if (widget.initialQuestionId != null) {
            final targetIdx =
                _questions.indexWhere((q) => q.id == widget.initialQuestionId);
            if (targetIdx != -1) {
              _currentIndex = targetIdx;
            }
          }
          _isLoading = false;
        });

        if (_questions.isNotEmpty) {
          _startQuestion();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _subscribeChallengeChannel() {
    if (widget.challengeId == null) return;
    final client = Supabase.instance.client;

    _challengeChannel =
        client.channel('public:quiz_challenge_live:${widget.challengeId!}')
          ..onBroadcast(
            event: 'player_answered',
            callback: (payload) {
              final uId = payload['userId'] as String?;
              final qIdx = payload['questionIndex'] as int?;
              final optIds =
                  (payload['optionIds'] as List?)?.cast<String>() ?? [];
              final isCorr = payload['isCorrect'] as bool? ?? false;
              final pts = payload['pointsEarned'] as int? ?? 0;

              if (uId != null &&
                  qIdx == _currentIndex &&
                  _playerStates.containsKey(uId)) {
                if (mounted) {
                  setState(() {
                    final p = _playerStates[uId]!;
                    p.isAnswered = true;
                    p.selectedOptionIds = optIds;
                    p.isCorrect = isCorr;
                    p.currentRoundScore = pts;
                    p.totalScore += pts;
                    p.streak = isCorr ? p.streak + 1 : 0;
                    for (var oId in optIds) {
                      _optionVoteCounts[oId] =
                          (_optionVoteCounts[oId] ?? 0) + 1;
                    }
                  });
                }
                _checkAllPlayersAnswered();
              }
            },
          )
          ..onBroadcast(
            event: 'host_action',
            callback: (payload) {
              final action = payload['action'] as String?;
              final qIdx = payload['questionIndex'] as int?;
              if (action == 'end_round' && qIdx == _currentIndex) {
                _triggerRoundEnd();
              } else if (action == 'next_question' &&
                  qIdx == _currentIndex + 1) {
                _nextQuestion();
              }
            },
          )
          ..onBroadcast(
            event: 'player_reaction',
            callback: (payload) {
              final emoji = payload['emoji'] as String?;
              if (emoji != null) {
                _triggerLocalEmoji(emoji);
              }
            },
          )
          ..subscribe();
  }

  void _sendEmoji(String emoji) {
    _triggerLocalEmoji(emoji);
    if (widget.challengeId != null && _challengeChannel != null) {
      _challengeChannel!.sendBroadcastMessage(
        event: 'player_reaction',
        payload: {'emoji': emoji, 'userId': _currentUserId},
      );
    }
  }

  void _triggerLocalEmoji(String emoji) {
    if (!mounted) return;
    final random = Random();
    setState(() {
      _activeFloatingEmojis.add(
        FloatingEmoji(
          id: '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}',
          emoji: emoji,
          xRatio: 0.15 + random.nextDouble() * 0.7,
          scale: 0.9 + random.nextDouble() * 0.4,
          createdAt: DateTime.now(),
        ),
      );
      if (_activeFloatingEmojis.length > 25) {
        _activeFloatingEmojis.removeRange(
            0, _activeFloatingEmojis.length - 25);
      }
    });
  }

  void _startQuestion() {
    _selectedOptionIds.clear();
    _isAnswerChecked = false;
    _lastAnswerCorrect = null;
    _hasLockedAnswer = false;
    _multiplayerPhase = KahootRoundPhase.question;
    _optionVoteCounts.clear();

    for (var p in _playerStates.values) {
      p.isAnswered = false;
      p.selectedOptionIds = [];
      p.isCorrect = false;
      p.currentRoundScore = 0;
    }

    _remainingSeconds = _questions[_currentIndex].durationSeconds;
    _currentQuestionStartTime = DateTime.now().millisecondsSinceEpoch;

    _timer?.cancel();
    if (!widget.isPreview && _useTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            if (widget.challengeId != null) {
              _triggerRoundEnd();
            } else {
              _checkAnswer(); // Solo mode auto-check on timeout
            }
          }
        });
      });
    }
  }

  void _checkAnswer() {
    if (_isAnswerChecked) return;

    _timer?.cancel();

    int timeTakenMs =
        DateTime.now().millisecondsSinceEpoch - _currentQuestionStartTime;
    _timeTakenPerQuestion.add(timeTakenMs);

    final currentQ = _questions[_currentIndex];
    bool isCorrect = false;

    final correctOptionIds = currentQ.options
        .where((o) => o.isCorrect)
        .map((o) => o.id)
        .toSet();

    if (correctOptionIds.isNotEmpty) {
      isCorrect = _selectedOptionIds.length == correctOptionIds.length &&
          _selectedOptionIds.every((id) => correctOptionIds.contains(id));
    }

    if (isCorrect) {
      _correctCount++;
    } else {
      _wrongCount++;
    }
    _lastAnswerCorrect = isCorrect;

    // Solo Mode Flow
    if (widget.challengeId == null) {
      setState(() {
        _isAnswerChecked = true;
        _userAnswers.add({
          'question_id': currentQ.id,
          'question_text': currentQ.questionText,
          'explanation': currentQ.explanation,
          'selected_option_ids': _selectedOptionIds.toList(),
          'selected_option_id': _selectedOptionIds.isNotEmpty
              ? _selectedOptionIds.first
              : null,
          'options': currentQ.options
              .map(
                (o) => {
                  'id': o.id,
                  'text': o.optionText,
                  'is_correct': o.isCorrect,
                },
              )
              .toList(),
        });
      });

      // Auto next after 2 seconds for solo
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _nextQuestion();
      });
      return;
    }

    // Multiplayer Flow (Kahoot style)
    int points = 0;
    if (isCorrect) {
      if (_useTimer) {
        final totalMs =
            (currentQ.durationSeconds * 1000).toDouble();
        final ratio = (timeTakenMs / totalMs).clamp(0.0, 1.0);
        // Kahoot formula: 500 to 1000 points based on speed
        points = (1000 * (1.0 - ratio * 0.5)).round();
      } else {
        points = 1000;
      }
      _myStreak++;
    } else {
      _myStreak = 0;
    }

    _myRoundPoints = points;
    _myTotalScore += points;
    _hasLockedAnswer = true;

    setState(() {
      _isAnswerChecked = true;
      if (_currentUserId != null &&
          _playerStates.containsKey(_currentUserId)) {
        final me = _playerStates[_currentUserId!]!;
        me.isAnswered = true;
        me.isCorrect = isCorrect;
        me.currentRoundScore = points;
        me.totalScore = _myTotalScore;
        me.streak = _myStreak;
        me.selectedOptionIds = _selectedOptionIds.toList();
        for (var oId in _selectedOptionIds) {
          _optionVoteCounts[oId] = (_optionVoteCounts[oId] ?? 0) + 1;
        }
      }

      _userAnswers.add({
        'question_id': currentQ.id,
        'question_text': currentQ.questionText,
        'explanation': currentQ.explanation,
        'selected_option_ids': _selectedOptionIds.toList(),
        'selected_option_id': _selectedOptionIds.isNotEmpty
            ? _selectedOptionIds.first
            : null,
        'options': currentQ.options
            .map(
              (o) => {
                'id': o.id,
                'text': o.optionText,
                'is_correct': o.isCorrect,
              },
            )
            .toList(),
      });
    });

    // Broadcast answer to opponents
    _challengeChannel?.sendBroadcastMessage(
      event: 'player_answered',
      payload: {
        'userId': _currentUserId,
        'questionIndex': _currentIndex,
        'optionIds': _selectedOptionIds.toList(),
        'isCorrect': isCorrect,
        'pointsEarned': points,
      },
    );

    // Check if everyone has submitted
    _checkAllPlayersAnswered();
  }

  void _checkAllPlayersAnswered() {
    if (widget.challengeId == null) return;
    final active = _playerStates.values.where((p) => !p.isQuit).toList();
    if (active.isEmpty) return;

    final answered = active.where((p) => p.isAnswered).length;
    if (answered >= active.length) {
      if (_isHost) {
        _challengeChannel?.sendBroadcastMessage(
          event: 'host_action',
          payload: {'action': 'end_round', 'questionIndex': _currentIndex},
        );
      }
      _triggerRoundEnd();
    }
  }

  void _triggerRoundEnd() {
    if (_multiplayerPhase != KahootRoundPhase.question) return;
    _timer?.cancel();

    // If current user didn't submit, record timeout
    if (!_hasLockedAnswer) {
      _hasLockedAnswer = true;
      _myStreak = 0;
      _myRoundPoints = 0;
      _wrongCount++;
      _lastAnswerCorrect = false;

      final currentQ = _questions[_currentIndex];
      _userAnswers.add({
        'question_id': currentQ.id,
        'question_text': currentQ.questionText,
        'explanation': currentQ.explanation,
        'selected_option_ids': <String>[],
        'selected_option_id': null,
        'options': currentQ.options
            .map(
              (o) => {
                'id': o.id,
                'text': o.optionText,
                'is_correct': o.isCorrect,
              },
            )
            .toList(),
      });

      if (_currentUserId != null &&
          _playerStates.containsKey(_currentUserId)) {
        final me = _playerStates[_currentUserId!]!;
        me.isAnswered = true;
        me.isCorrect = false;
        me.currentRoundScore = 0;
        me.streak = 0;
      }
    }

    if (mounted) {
      setState(() {
        _multiplayerPhase = KahootRoundPhase.reveal;
      });
    }

    // Auto transition to scoreboard after 3.5 seconds
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _multiplayerPhase == KahootRoundPhase.reveal) {
        _transitionToScoreboard();
      }
    });
  }

  void _transitionToScoreboard() {
    _revealTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _multiplayerPhase = KahootRoundPhase.scoreboard;
      _scoreboardSecondsRemaining = 5;
    });

    if (_useTimer) {
      _scoreboardTimer?.cancel();
      _scoreboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_scoreboardSecondsRemaining > 1) {
          setState(() => _scoreboardSecondsRemaining--);
        } else {
          timer.cancel();
          _nextQuestion();
        }
      });
    } else {
      // Option 2: Host disconnect / inactivity fail-safe
      if (!_isHost) {
        _hostInactivityTimer?.cancel();
        _hostInactivityTimer = Timer(const Duration(seconds: 15), () {
          if (mounted && _multiplayerPhase == KahootRoundPhase.scoreboard) {
            _startAutoScoreboardCountdown();
          }
        });
      }
    }
  }

  void _startAutoScoreboardCountdown() {
    _scoreboardTimer?.cancel();
    _scoreboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_scoreboardSecondsRemaining > 1) {
        setState(() => _scoreboardSecondsRemaining--);
      } else {
        timer.cancel();
        _nextQuestion();
      }
    });
  }

  void _endRoundEarly() {
    if (_isHost && widget.challengeId != null) {
      _challengeChannel?.sendBroadcastMessage(
        event: 'host_action',
        payload: {'action': 'end_round', 'questionIndex': _currentIndex},
      );
      _triggerRoundEnd();
    }
  }

  void _nextQuestion() {
    _revealTimer?.cancel();
    _scoreboardTimer?.cancel();
    _hostInactivityTimer?.cancel();

    if (_currentIndex < _questions.length - 1) {
      if (widget.challengeId != null && _isHost && !_useTimer) {
        _challengeChannel?.sendBroadcastMessage(
          event: 'host_action',
          payload: {
            'action': 'next_question',
            'questionIndex': _currentIndex + 1
          },
        );
      }

      setState(() {
        _currentIndex++;
      });
      _startQuestion();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz({bool isQuit = false}) async {
    _timer?.cancel();
    _revealTimer?.cancel();
    _scoreboardTimer?.cancel();
    _hostInactivityTimer?.cancel();

    if (widget.isPreview) {
      if (mounted) context.pop();
      return;
    }

    double avgTime = 0;
    if (_timeTakenPerQuestion.isNotEmpty) {
      avgTime = _timeTakenPerQuestion.reduce((a, b) => a + b) /
          _timeTakenPerQuestion.length /
          1000.0;
    }

    final totalQuestions = _questions.isEmpty ? 1 : _questions.length;
    int score = (_correctCount * 100) ~/ totalQuestions;
    double accuracy = (_correctCount / totalQuestions) * 100.0;

    final attempt = QuizAttempt(
      id: '',
      userId: '',
      quizId: widget.quizId,
      score: score,
      totalQuestions: totalQuestions,
      correctAnswers: _correctCount,
      wrongAnswers: _wrongCount,
      avgTimePerQuestion: avgTime,
      createdAt: DateTime.now(),
      userAnswers: _userAnswers,
    );

    try {
      final repo = context.read<QuizRepository>();
      final attemptId = await repo.saveQuizAttempt(attempt);

      // Award XP points: 2 XP per correct answer
      final int xpAwarded = _correctCount * 2;
      if (!widget.isPreview && xpAwarded > 0) {
        try {
          final client = Supabase.instance.client;
          final user = client.auth.currentUser;
          if (user != null) {
            int currentXp = 0;
            int currentWeeklyXp = 0;
            try {
              final res = await client
                  .from('profiles')
                  .select('xp, weekly_xp')
                  .eq('id', user.id)
                  .single();
              currentXp = (res['xp'] as num? ?? 0).toInt();
              currentWeeklyXp = (res['weekly_xp'] as num? ?? 0).toInt();
            } catch (_) {
              final metadata = user.userMetadata;
              if (metadata != null && metadata.containsKey('xp')) {
                currentXp = int.tryParse(metadata['xp'].toString()) ?? 0;
              }
              if (metadata != null && metadata.containsKey('weekly_xp')) {
                currentWeeklyXp =
                    int.tryParse(metadata['weekly_xp'].toString()) ?? 0;
              }
            }

            final newXp = currentXp + xpAwarded;
            final newWeeklyXp = currentWeeklyXp + xpAwarded;

            final metadata = user.userMetadata;
            await client.auth.updateUser(
              UserAttributes(
                data: {
                  ...metadata ?? {},
                  'xp': newXp,
                  'weekly_xp': newWeeklyXp,
                },
              ),
            );

            await client.from('profiles').update({
              'xp': newXp,
              'weekly_xp': newWeeklyXp,
            }).eq('id', user.id);
          }
        } catch (e) {
          debugPrint('Error updating XP: $e');
        }
      }

      if (widget.challengeId != null) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId != null) {
          await client
              .from('quiz_challenge_players')
              .update({
                'score': _myTotalScore,
                'accuracy': accuracy,
                'completed_at': DateTime.now().toIso8601String(),
                'is_quit': isQuit,
              })
              .eq('challenge_id', widget.challengeId!)
              .eq('user_id', userId);
        }
      }

      if (mounted) {
        final reviewPath = widget.challengeId != null
            ? '/quiz/${widget.quizId}/review?challengeId=${widget.challengeId}'
            : '/quiz/${widget.quizId}/review';
        context.go(reviewPath, extra: {'attemptId': attemptId});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${e.toString()}')),
        );
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    TakeQuizScreen.isActive = false;
    _timer?.cancel();
    _revealTimer?.cancel();
    _scoreboardTimer?.cancel();
    _hostInactivityTimer?.cancel();
    if (_challengeChannel != null) {
      Supabase.instance.client.removeChannel(_challengeChannel!);
      _challengeChannel = null;
    }
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      client
          .from('profiles')
          .update({'is_playing': false})
          .eq('id', userId)
          .then((_) {})
          .catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No quizzes found.')),
      );
    }

    final question = _questions[_currentIndex];

    // ==========================================
    // MULTIPLAYER PHASES: Reveal & Scoreboard
    // ==========================================
    if (widget.challengeId != null) {
      if (_multiplayerPhase == KahootRoundPhase.reveal) {
        return Stack(
          children: [
            KahootRevealView(
              isCorrect: _lastAnswerCorrect == true,
              isTimedOut: _selectedOptionIds.isEmpty,
              pointsEarned: _myRoundPoints,
              streak: _myStreak,
              question: question,
              userSelectedOptionIds: _selectedOptionIds.toList(),
              optionVoteCounts: _optionVoteCounts,
              totalAnswered: _playerStates.values.where((p) => p.isAnswered).length,
              onContinue: _transitionToScoreboard,
              onSendEmoji: _sendEmoji,
            ),
            FloatingEmojiOverlay(emojis: _activeFloatingEmojis),
          ],
        );
      } else if (_multiplayerPhase == KahootRoundPhase.scoreboard) {
        return Stack(
          children: [
            KahootScoreboardView(
              players: _playerStates.values.toList(),
              currentQuestionIndex: _currentIndex,
              totalQuestions: _questions.length,
              isHost: _isHost,
              useTimer: _useTimer,
              secondsRemaining: _scoreboardSecondsRemaining,
              onNextQuestion: _nextQuestion,
              currentUserId: _currentUserId ?? '',
              onSendEmoji: _sendEmoji,
            ),
            FloatingEmojiOverlay(emojis: _activeFloatingEmojis),
          ],
        );
      }
    }

    // ==========================================
    // QUESTION PHASE (Solo & Multiplayer)
    // ==========================================
    double progress = question.durationSeconds > 0
        ? _remainingSeconds / question.durationSeconds
        : 0.0;

    final activePlayers =
        _playerStates.values.where((p) => !p.isQuit).toList();
    final answeredPlayersCount =
        activePlayers.where((p) => p.isAnswered).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Quiz?'),
            content: const Text(
              'Are you sure you want to exit? Your progress will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldPop == true) {
          if (mounted) {
            _finishQuiz(isQuit: true);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Question ${_currentIndex + 1} of ${_questions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            // If multiplayer with timer turned OFF and user is Host: End Round button
            if (widget.challengeId != null && !_useTimer && _isHost)
              TextButton.icon(
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.amber, size: 20),
                label: const Text(
                  'End Round',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _endRoundEarly,
              ),
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timer Bar
                  if (!widget.isPreview && _useTimer) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: progress, end: progress),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            value < 0.25 ? Colors.red : Colors.deepPurple,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.challengeId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people_alt_rounded,
                                    size: 14, color: Colors.deepPurple),
                                const SizedBox(width: 4),
                                Text(
                                  '$answeredPlayersCount / ${activePlayers.length} answered',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Text(
                          '00:${_remainingSeconds.toString().padLeft(2, '0')}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _remainingSeconds <= 5
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ] else if (widget.challengeId != null && !_useTimer) ...[
                    // Multiplayer untimed status pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_alt_rounded,
                                  size: 15, color: Colors.deepPurple),
                              const SizedBox(width: 6),
                              Text(
                                '$answeredPlayersCount / ${activePlayers.length} answered',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    question.questionText,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Options list
                  Expanded(
                    child: ListView.builder(
                      itemCount: question.options.length,
                      itemBuilder: (context, index) {
                        final option = question.options[index];
                        final isMultipleChoice = question.options
                                .where((o) => o.isCorrect)
                                .length >
                            1;
                        final isSelected =
                            _selectedOptionIds.contains(option.id);

                        final disableSelection =
                            _isAnswerChecked || _hasLockedAnswer;

                        if (isMultipleChoice) {
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                option.optionText,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              value: isSelected,
                              activeColor: Colors.deepPurple,
                              onChanged: disableSelection
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedOptionIds.add(option.id);
                                        } else {
                                          _selectedOptionIds.remove(option.id);
                                        }
                                      });
                                    },
                            ),
                          );
                        } else {
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: RadioListTile<String>(
                              title: Text(
                                option.optionText,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              value: option.id,
                              groupValue: isSelected ? option.id : null,
                              activeColor: Colors.deepPurple,
                              onChanged: disableSelection
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _selectedOptionIds = {option.id};
                                      });
                                      _checkAnswer();
                                    },
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  // Submit button for multi-choice
                  if (!_isAnswerChecked &&
                      !_hasLockedAnswer &&
                      question.options.where((o) => o.isCorrect).length > 1)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _selectedOptionIds.isEmpty
                                ? null
                                : _checkAnswer,
                            child: const Text(
                              'Submit Answer',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Multiplayer Waiting Banner
                  if (widget.challengeId != null && _hasLockedAnswer)
                    KahootWaitingBanner(
                      answeredCount: answeredPlayersCount,
                      totalCount: activePlayers.length,
                      onSendEmoji: _sendEmoji,
                    ),
                ],
              ),
            ),

            // Floating Emoji Animation Overlay
            FloatingEmojiOverlay(emojis: _activeFloatingEmojis),
          ],
        ),
      ),
    );
  }
}
