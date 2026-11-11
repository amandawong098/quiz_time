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
  RealtimeChannel? _playersDbChannel;
  String? _currentUserId;
  bool _isHost = false;
  final Map<String, PlayerLiveState> _playerStates = {};
  final ValueNotifier<int> _liveStateNotifier = ValueNotifier<int>(0);
  final Map<int, List<Map<String, dynamic>>> _pendingAnswerPayloads = {};
  bool _hasLockedAnswer = false;
  bool _isFinishingQuiz = false;
  int _myRoundPoints = 0;
  int _myTotalScore = 0;
  int _myStreak = 0;

  String? _recentAnsweredPlayerName;
  Timer? _recentAnswerBannerTimer;

  Timer? _revealTimer;
  Timer? _scoreboardTimer;
  int _scoreboardSecondsRemaining = 5;
  Timer? _hostInactivityTimer;
  Timer? _playersSyncTimer;

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

      bool isShuffle = widget.shuffle;
      bool useTimer = widget.useTimer;
      String? hostId;

      if (widget.challengeId != null) {
        try {
          final challenge = await client
              .from('quiz_challenges')
              .select('host_id, shuffle, use_timer')
              .eq('id', widget.challengeId!)
              .single();
          hostId = challenge['host_id'] as String?;
          _isHost = (_currentUserId == hostId);
          isShuffle = (challenge['shuffle'] as bool?) ?? widget.shuffle;
          useTimer = (challenge['use_timer'] as bool?) ?? widget.useTimer;
        } catch (_) {
          try {
            final challenge = await client
                .from('quiz_challenges')
                .select('host_id, shuffle')
                .eq('id', widget.challengeId!)
                .single();
            hostId = challenge['host_id'] as String?;
            _isHost = (_currentUserId == hostId);
            isShuffle = (challenge['shuffle'] as bool?) ?? widget.shuffle;
          } catch (_) {}
        }

        // Load multiplayer players (only accepted participants)
        try {
          final playersRes = await client
              .from('quiz_challenge_players')
              .select('*, profiles!user_id(name, avatar_url)')
              .eq('challenge_id', widget.challengeId!);

          for (var row in (playersRes as List)) {
            final status = row['status'] as String? ?? 'accepted';
            if (status != 'accepted') continue;
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
              isHost: uId == hostId,
            );
          }
        } catch (e) {
          debugPrint('Error loading challenge players: $e');
        }
      }

      if (mounted) {
        setState(() {
          _questions = List<Question>.from(data['questions'] as List<Question>);
          _useTimer = useTimer;

          // Deterministically sort options for each question
          for (var q in _questions) {
            q.options.sort((a, b) => a.id.compareTo(b.id));
          }

          // If multiplayer shuffle, use platform-independent deterministic shuffle so all devices share identical order
          if (isShuffle || widget.shuffle) {
            if (widget.challengeId != null) {
              _deterministicShuffleQuestions(_questions, widget.challengeId!);
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

        if (widget.challengeId != null) {
          _subscribeChallengeChannel();
        }

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
              final qIdx = payload['questionIndex'] as int?;
              if (qIdx == null) return;
              if (qIdx == _currentIndex) {
                _applyRemoteAnswerPayload(payload);
              } else if (qIdx > _currentIndex) {
                _pendingAnswerPayloads
                    .putIfAbsent(qIdx, () => [])
                    .add(Map<String, dynamic>.from(payload));
              }
            },
          )
          ..onBroadcast(
            event: 'host_action',
            callback: (payload) {
              final action = payload['action'] as String?;
              final qIdx = payload['questionIndex'] as int?;
              if (action == 'end_round' && qIdx == _currentIndex) {
                _triggerRoundEnd(broadcastEndRound: false);
              } else if (action == 'show_scoreboard' &&
                  qIdx == _currentIndex &&
                  _multiplayerPhase == KahootRoundPhase.reveal) {
                _transitionToScoreboard();
              } else if (action == 'next_question' &&
                  qIdx == _currentIndex + 1) {
                _nextQuestion();
              } else if (action == 'finish_quiz') {
                _finishQuiz();
              }
            },
          )
          ..onBroadcast(
            event: 'player_quit',
            callback: (payload) {
              final uId = payload['userId'] as String?;
              if (uId != null && _playerStates.containsKey(uId)) {
                if (mounted) {
                  setState(() {
                    _playerStates[uId]!.isQuit = true;
                  });
                  _liveStateNotifier.value++;
                }
                _checkAllPlayersAnswered();
              }
            },
          )
          ..onBroadcast(
            event: 'request_sync',
            callback: (payload) {
              if (_isHost && _questions.isNotEmpty) {
                _broadcastQuizOrder();
              }
            },
          )
          ..onBroadcast(
            event: 'sync_quiz_order',
            callback: (payload) {
              if (_isHost) return;
              final orderedIds =
                  (payload['questionIds'] as List?)?.cast<String>();
              if (orderedIds != null &&
                  orderedIds.length == _questions.length &&
                  mounted) {
                bool differs = false;
                for (int i = 0; i < orderedIds.length; i++) {
                  if (_questions[i].id != orderedIds[i]) {
                    differs = true;
                    break;
                  }
                }
                if (differs) {
                  final mapById = {for (var q in _questions) q.id: q};
                  final reordered = <Question>[];
                  for (final id in orderedIds) {
                    final q = mapById[id];
                    if (q != null) reordered.add(q);
                  }
                  if (reordered.length == _questions.length) {
                    setState(() {
                      _questions = reordered;
                    });
                  }
                }
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
          ..subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              if (_isHost && _questions.isNotEmpty) {
                _broadcastQuizOrder();
              } else if (!_isHost) {
                _challengeChannel?.sendBroadcastMessage(
                  event: 'request_sync',
                  payload: {'userId': _currentUserId},
                );
              }
            }
          });

    // Also listen for database updates to quiz_challenge_players (e.g., is_quit)
    _playersDbChannel = client
        .channel('public:quiz_challenge_players:live_${widget.challengeId!}')
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
          final updatedUserId = payload.newRecord['user_id'] as String?;
          final isQuit = payload.newRecord['is_quit'] as bool? ?? false;
          if (updatedUserId != null &&
              isQuit &&
              _playerStates.containsKey(updatedUserId)) {
            if (mounted) {
              setState(() {
                _playerStates[updatedUserId]!.isQuit = true;
              });
              _liveStateNotifier.value++;
            }
            _checkAllPlayersAnswered();
          }
          _syncChallengePlayersFromDb();
        },
      )
      ..subscribe();

    // Periodic fallback sync so cross-platform quit/status updates are never missed
    _playersSyncTimer?.cancel();
    _playersSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && !_isFinishingQuiz) {
        _syncChallengePlayersFromDb();
      }
    });
  }

  Future<void> _syncChallengePlayersFromDb() async {
    if (widget.challengeId == null || !mounted) return;
    try {
      final rows = await Supabase.instance.client
          .from('quiz_challenge_players')
          .select('user_id, status, is_quit, score')
          .eq('challenge_id', widget.challengeId!);

      if (!mounted) return;
      bool changed = false;
      for (final row in (rows as List)) {
        final status = row['status'] as String? ?? 'accepted';
        if (status != 'accepted') continue;
        final uId = row['user_id'] as String?;
        if (uId == null || !_playerStates.containsKey(uId)) continue;
        final isQuit = row['is_quit'] as bool? ?? false;
        final dbScore = (row['score'] as num?)?.toInt() ?? 0;
        final p = _playerStates[uId]!;
        if (isQuit && !p.isQuit) {
          p.isQuit = true;
          changed = true;
        }
        if (uId != _currentUserId && dbScore > p.totalScore) {
          p.totalScore = dbScore;
          changed = true;
        }
      }

      if (changed && mounted) {
        setState(() {});
        _liveStateNotifier.value++;
        _checkAllPlayersAnswered();
      }
    } catch (_) {}
  }

  Future<void> _updateLivePlayerProgressInDb() async {
    if (widget.challengeId == null || _currentUserId == null) return;
    final totalQuestions = _questions.isEmpty ? 1 : _questions.length;
    final double accuracy = (_correctCount / totalQuestions) * 100.0;
    try {
      await Supabase.instance.client
          .from('quiz_challenge_players')
          .update({
            'score': _myTotalScore,
            'accuracy': accuracy,
          })
          .eq('challenge_id', widget.challengeId!)
          .eq('user_id', _currentUserId!);
    } catch (_) {}
  }

  void _broadcastQuizOrder() {
    if (_challengeChannel == null || _questions.isEmpty) return;
    _challengeChannel!.sendBroadcastMessage(
      event: 'sync_quiz_order',
      payload: {
        'questionIds': _questions.map((q) => q.id).toList(),
      },
    );
  }

  void _applyRemoteAnswerPayload(Map<String, dynamic> payload) {
    final uId = payload['userId'] as String?;
    final optIds = (payload['optionIds'] as List?)?.cast<String>() ?? [];
    final isCorr = payload['isCorrect'] as bool? ?? false;
    final pts = payload['pointsEarned'] as int? ?? 0;
    final isTimeout = payload['isTimeout'] as bool? ?? false;

    if (uId != null && _playerStates.containsKey(uId)) {
      final p = _playerStates[uId]!;
      if (p.isAnswered) return; // Avoid double-counting

      if (mounted) {
        setState(() {
          p.isAnswered = true;
          p.isTimedOut = isTimeout;
          p.selectedOptionIds = optIds;
          p.isCorrect = isCorr;
          p.currentRoundScore = pts;
          p.totalScore += pts;
          p.streak = isCorr ? p.streak + 1 : 0;
          for (var oId in optIds) {
            _optionVoteCounts[oId] = (_optionVoteCounts[oId] ?? 0) + 1;
          }

          // Trigger brief "XXX answered" banner notification if another player answered
          if (!isTimeout && uId != _currentUserId) {
            _recentAnsweredPlayerName = p.name;
            _recentAnswerBannerTimer?.cancel();
            _recentAnswerBannerTimer = Timer(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _recentAnsweredPlayerName = null;
                });
              }
            });
          }
        });
        _liveStateNotifier.value++;
      }
      _checkAllPlayersAnswered();
    }
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

  /// Platform-independent deterministic shuffle (identical across Web JS and Native VM)
  void _deterministicShuffleQuestions(List<Question> list, String seedStr) {
    // 1. Sort by question ID so initial order is 100% identical on all devices
    list.sort((a, b) => a.id.compareTo(b.id));

    // 2. Compute positive 31-bit seed using safe small-integer math (< 2^36, no JS float loss)
    int state = 0x1234567;
    for (int i = 0; i < seedStr.length; i++) {
      state = ((state * 31) + seedStr.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    if (state == 0) state = 1;

    // 3. Park-Miller LCG (state * 48271 % 2147483647) Fisher-Yates shuffle
    // Max intermediate product is 2147483646 * 48271 = 1.036e14 << 2^53 - 1
    for (int i = list.length - 1; i > 0; i--) {
      state = (state * 48271) % 2147483647;
      final int j = state % (i + 1);
      final Question tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  void _triggerLocalEmoji(String emoji) {
    if (!mounted) return;
    final random = Random();
    final now = DateTime.now();
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

  void _startQuestion() {
    _selectedOptionIds.clear();
    _isAnswerChecked = false;
    _lastAnswerCorrect = null;
    _hasLockedAnswer = false;
    _multiplayerPhase = KahootRoundPhase.question;
    _optionVoteCounts.clear();
    _recentAnswerBannerTimer?.cancel();
    _recentAnsweredPlayerName = null;

    for (var p in _playerStates.values) {
      p.isAnswered = false;
      p.isTimedOut = false;
      p.selectedOptionIds = [];
      p.isCorrect = false;
      p.currentRoundScore = 0;
    }
    _liveStateNotifier.value++;

    if (widget.challengeId != null) {
      _syncChallengePlayersFromDb();
      _challengeChannel?.sendBroadcastMessage(
        event: 'player_progress',
        payload: {
          'userId': _currentUserId,
          'questionIndex': _currentIndex,
          'totalQuestions': _questions.length,
          'streak': _myStreak,
          'totalScore': _myTotalScore,
        },
      );
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

        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          timer.cancel();
          if (widget.challengeId != null) {
            _triggerRoundEnd();
          } else {
            _checkAnswer(); // Solo mode auto-check on timeout
          }
        }
      });
    }

    // Apply any remote answers that arrived early for this question index
    final buffered = _pendingAnswerPayloads.remove(_currentIndex);
    if (buffered != null) {
      for (final payload in buffered) {
        _applyRemoteAnswerPayload(payload);
      }
    }
  }

  void _checkAnswer() {
    if (_isAnswerChecked) return;

    // In solo mode cancel timer immediately; in multiplayer let the timer continue
    // running so if opponents haven't answered, the round ends when timer reaches 0
    if (widget.challengeId == null) {
      _timer?.cancel();
    }

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
    _liveStateNotifier.value++;

    // Broadcast answer to opponents
    final totalQ = _questions.isEmpty ? 1 : _questions.length;
    _challengeChannel?.sendBroadcastMessage(
      event: 'player_answered',
      payload: {
        'userId': _currentUserId,
        'questionIndex': _currentIndex,
        'totalQuestions': totalQ,
        'optionIds': _selectedOptionIds.toList(),
        'isCorrect': isCorrect,
        'pointsEarned': points,
        'totalScore': _myTotalScore,
        'streak': _myStreak,
        'accuracy': (_correctCount / totalQ) * 100.0,
      },
    );

    // Persist live score & accuracy in DB so Review screen standings update in real time
    _updateLivePlayerProgressInDb();

    // Check if everyone has submitted
    _checkAllPlayersAnswered();
  }

  void _checkAllPlayersAnswered() {
    if (widget.challengeId == null) return;
    final active = _playerStates.values.where((p) => !p.isQuit).toList();
    if (active.isEmpty) return;

    final answered = active.where((p) => p.isAnswered).length;
    if (answered >= active.length) {
      _triggerRoundEnd(broadcastEndRound: true);
    }
  }

  void _triggerRoundEnd({bool broadcastEndRound = true}) {
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
        me.isTimedOut = true;
        me.isCorrect = false;
        me.currentRoundScore = 0;
        me.streak = 0;
      }

      // Broadcast timeout to all other players in the room
      final totalQ = _questions.isEmpty ? 1 : _questions.length;
      _challengeChannel?.sendBroadcastMessage(
        event: 'player_answered',
        payload: {
          'userId': _currentUserId,
          'questionIndex': _currentIndex,
          'totalQuestions': totalQ,
          'optionIds': <String>[],
          'isCorrect': false,
          'pointsEarned': 0,
          'totalScore': _myTotalScore,
          'streak': 0,
          'accuracy': (_correctCount / totalQ) * 100.0,
          'isTimeout': true,
        },
      );

      _updateLivePlayerProgressInDb();
    }

    if (broadcastEndRound) {
      // Force sync: broadcast end_round so opponents with clock drift transition immediately
      _challengeChannel?.sendBroadcastMessage(
        event: 'host_action',
        payload: {'action': 'end_round', 'questionIndex': _currentIndex},
      );
    }

    if (mounted) {
      setState(() {
        _multiplayerPhase = KahootRoundPhase.reveal;
      });
      _liveStateNotifier.value++;
    }

    // Auto transition to scoreboard after 3.5 seconds
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _multiplayerPhase == KahootRoundPhase.reveal) {
        _transitionToScoreboard();
      }
    });
  }

  void _hostSkipToScoreboard() {
    if (_isHost && widget.challengeId != null) {
      _challengeChannel?.sendBroadcastMessage(
        event: 'host_action',
        payload: {'action': 'show_scoreboard', 'questionIndex': _currentIndex},
      );
    }
    _transitionToScoreboard();
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
      _triggerRoundEnd(broadcastEndRound: true);
    }
  }

  void _nextQuestion() {
    _revealTimer?.cancel();
    _scoreboardTimer?.cancel();
    _hostInactivityTimer?.cancel();

    if (_currentIndex < _questions.length - 1) {
      if (widget.challengeId != null && _isHost) {
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
      if (widget.challengeId != null && _isHost) {
        _challengeChannel?.sendBroadcastMessage(
          event: 'host_action',
          payload: {'action': 'finish_quiz'},
        );
      }
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz({bool isQuit = false}) async {
    if (_isFinishingQuiz) return;
    _isFinishingQuiz = true;

    _timer?.cancel();
    _revealTimer?.cancel();
    _scoreboardTimer?.cancel();
    _hostInactivityTimer?.cancel();
    _recentAnswerBannerTimer?.cancel();
    _playersSyncTimer?.cancel();

    if (widget.isPreview) {
      if (mounted) context.pop();
      return;
    }

    final repo = context.read<QuizRepository>();
    final totalQuestions = _questions.isEmpty ? 1 : _questions.length;
    final int score = (_correctCount * 100) ~/ totalQuestions;
    final double accuracy = (_correctCount / totalQuestions) * 100.0;

    // Immediately update DB and broadcast quit/finish first so other devices reflect it right away
    if (widget.challengeId != null) {
      if (isQuit &&
          _currentUserId != null &&
          _playerStates.containsKey(_currentUserId)) {
        _playerStates[_currentUserId!]!.isQuit = true;
        _liveStateNotifier.value++;
      }
      final client = Supabase.instance.client;
      final userId = _currentUserId ?? client.auth.currentUser?.id;
      if (userId != null) {
        try {
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
        } catch (_) {}
      }
      try {
        await _challengeChannel?.sendBroadcastMessage(
          event: isQuit ? 'player_quit' : 'player_finished',
          payload: {
            'userId': userId,
            'totalScore': _myTotalScore,
            'accuracy': accuracy,
            'isQuit': isQuit,
          },
        );
      } catch (_) {}
    }

    // Record any remaining unattempted questions (Option A for both Solo and Multiplayer)
    final recordedQuestionIds = _userAnswers
        .map((a) => a['question_id'] as String?)
        .whereType<String>()
        .toSet();
    for (final q in _questions) {
      if (!recordedQuestionIds.contains(q.id)) {
        _userAnswers.add({
          'question_id': q.id,
          'question_text': q.questionText,
          'explanation': q.explanation,
          'selected_option_ids': <String>[],
          'selected_option_id': null,
          'options': q.options
              .map(
                (o) => {
                  'id': o.id,
                  'text': o.optionText,
                  'is_correct': o.isCorrect,
                },
              )
              .toList(),
        });
      }
    }

    double avgTime = 0;
    if (_timeTakenPerQuestion.isNotEmpty) {
      avgTime = _timeTakenPerQuestion.reduce((a, b) => a + b) /
          _timeTakenPerQuestion.length /
          1000.0;
    }

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
    _recentAnswerBannerTimer?.cancel();
    _playersSyncTimer?.cancel();
    _liveStateNotifier.dispose();
    final client = Supabase.instance.client;
    final userId = _currentUserId ?? client.auth.currentUser?.id;
    if (widget.challengeId != null && !_isFinishingQuiz && userId != null) {
      final totalQuestions = _questions.isEmpty ? 1 : _questions.length;
      final double accuracy = (_correctCount / totalQuestions) * 100.0;
      client
          .from('quiz_challenge_players')
          .update({
            'score': _myTotalScore,
            'accuracy': accuracy,
            'completed_at': DateTime.now().toIso8601String(),
            'is_quit': true,
          })
          .eq('challenge_id', widget.challengeId!)
          .eq('user_id', userId)
          .then((_) {})
          .catchError((_) {});
      try {
        _challengeChannel?.sendBroadcastMessage(
          event: 'player_quit',
          payload: {'userId': userId},
        );
      } catch (_) {}
    }
    if (_challengeChannel != null) {
      Supabase.instance.client.removeChannel(_challengeChannel!);
      _challengeChannel = null;
    }
    if (_playersDbChannel != null) {
      Supabase.instance.client.removeChannel(_playersDbChannel!);
      _playersDbChannel = null;
    }
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

    Widget currentPhaseWidget;
    if (widget.challengeId != null) {
      if (_multiplayerPhase == KahootRoundPhase.reveal) {
        currentPhaseWidget = KahootRevealView(
          key: ValueKey('reveal_$_currentIndex'),
          isCorrect: _lastAnswerCorrect == true,
          isTimedOut: _selectedOptionIds.isEmpty,
          pointsEarned: _myRoundPoints,
          streak: _myStreak,
          question: question,
          userSelectedOptionIds: _selectedOptionIds.toList(),
          optionVoteCounts: _optionVoteCounts,
          totalAnswered:
              _playerStates.values.where((p) => p.isAnswered).length,
          onContinue: _isHost ? _hostSkipToScoreboard : null,
          onSendEmoji: _sendEmoji,
        );
      } else if (_multiplayerPhase == KahootRoundPhase.scoreboard) {
        currentPhaseWidget = KahootScoreboardView(
          key: ValueKey('scoreboard_$_currentIndex'),
          players: _playerStates.values.toList(),
          currentQuestionIndex: _currentIndex,
          totalQuestions: _questions.length,
          isHost: _isHost,
          useTimer: _useTimer,
          secondsRemaining: _scoreboardSecondsRemaining,
          onNextQuestion: _nextQuestion,
          currentUserId: _currentUserId ?? '',
          onSendEmoji: _sendEmoji,
        );
      } else {
        currentPhaseWidget = _buildQuestionScreen(
          context,
          key: ValueKey('question_$_currentIndex'),
        );
      }
    } else {
      currentPhaseWidget = _buildQuestionScreen(
        context,
        key: ValueKey('question_$_currentIndex'),
      );
    }

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
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: currentPhaseWidget,
          ),
          if (widget.challengeId != null)
            Positioned.fill(
              child: FloatingEmojiOverlay(emojis: _activeFloatingEmojis),
            ),
        ],
      ),
    );
  }

  void _showLivePlayersStatusSheet() {
    if (widget.challengeId == null) return;
    _syncChallengePlayersFromDb();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ValueListenableBuilder<int>(
          valueListenable: _liveStateNotifier,
          builder: (context, _, _) {
            final activePlayers =
                _playerStates.values.where((p) => !p.isQuit).toList();
            final answeredPlayersCount =
                activePlayers.where((p) => p.isAnswered).length;

            final sorted = _playerStates.values.toList()
              ..sort((a, b) {
                if (a.userId == _currentUserId) return -1;
                if (b.userId == _currentUserId) return 1;
                if (a.isQuit != b.isQuit) return a.isQuit ? 1 : -1;
                if (a.isAnswered != b.isAnswered) return a.isAnswered ? -1 : 1;
                return a.name.compareTo(b.name);
              });

            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentIndex + 1} Status',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$answeredPlayersCount / ${activePlayers.length} answered',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = sorted[index];
                          final isMe = p.userId == _currentUserId;

                          Widget statusChip;
                          if (p.isQuit) {
                            statusChip = Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cancel_rounded,
                                      size: 13, color: Colors.red.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Quit',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (p.isTimedOut) {
                            statusChip = Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_off_rounded,
                                      size: 13, color: Colors.orange.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Timed out',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (p.isAnswered) {
                            statusChip = Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 13, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Answered',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            statusChip = Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.psychology_rounded,
                                      size: 13, color: Colors.amber.shade900),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Thinking...',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.deepPurple.shade100,
                              backgroundImage: p.avatarUrl != null &&
                                      p.avatarUrl!.isNotEmpty
                                  ? NetworkImage(p.avatarUrl!)
                                  : null,
                              child: p.avatarUrl == null ||
                                      p.avatarUrl!.isEmpty
                                  ? Text(
                                      p.name.isNotEmpty
                                          ? p.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
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
                                if (p.isHost) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'HOST',
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
                            trailing: statusChip,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedAnsweredStatusPill({
    required int answeredCount,
    required int totalCount,
    bool isLarge = false,
  }) {
    final bool hasRecent = _recentAnsweredPlayerName != null;
    final String labelText = hasRecent
        ? '$_recentAnsweredPlayerName answered'
        : '$answeredCount / $totalCount answered';
    final double fontSize = isLarge ? 13 : 12;
    final double iconSize = isLarge ? 15 : 14;

    return InkWell(
      onTap: _showLivePlayersStatusSheet,
      borderRadius: BorderRadius.circular(isLarge ? 16 : 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? 12 : 8,
          vertical: isLarge ? 5 : 3,
        ),
        decoration: BoxDecoration(
          color: hasRecent ? Colors.green.shade50 : Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(isLarge ? 16 : 12),
          border: Border.all(
            color:
                hasRecent ? Colors.green.shade400 : Colors.deepPurple.shade200,
            width: 0.9,
          ),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey<String>(
                hasRecent
                    ? 'recent_$_recentAnsweredPlayerName'
                    : 'count_${answeredCount}_$totalCount',
              ),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasRecent
                      ? Icons.check_circle_rounded
                      : Icons.people_alt_rounded,
                  size: iconSize,
                  color: hasRecent ? Colors.green.shade700 : Colors.deepPurple,
                ),
                SizedBox(width: isLarge ? 6 : 4),
                Text(
                  labelText,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color:
                        hasRecent ? Colors.green.shade700 : Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.info_outline_rounded,
                  size: iconSize - 1,
                  color: hasRecent ? Colors.green.shade700 : Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionScreen(BuildContext context, {Key? key}) {
    final question = _questions[_currentIndex];
    double progress = question.durationSeconds > 0
        ? _remainingSeconds / question.durationSeconds
        : 0.0;

    final activePlayers =
        _playerStates.values.where((p) => !p.isQuit).toList();
    final answeredPlayersCount =
        activePlayers.where((p) => p.isAnswered).length;

    return Scaffold(
      key: key,
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
      body: Padding(
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
                    _buildAnimatedAnsweredStatusPill(
                      answeredCount: answeredPlayersCount,
                      totalCount: activePlayers.length,
                      isLarge: false,
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
                  _buildAnimatedAnsweredStatusPill(
                    answeredCount: answeredPlayersCount,
                    totalCount: activePlayers.length,
                    isLarge: true,
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
                onTapStatus: _showLivePlayersStatusSheet,
                recentAnsweredPlayerName: _recentAnsweredPlayerName,
              ),
          ],
        ),
      ),
    );
  }
}
