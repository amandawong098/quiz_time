import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../data/repositories/friendship_repository.dart';

class TakeQuizScreen extends StatefulWidget {
  final String quizId;
  final String? challengeId;
  final bool shuffle;
  final bool isPreview;
  final String? initialQuestionId;
  const TakeQuizScreen({
    super.key,
    required this.quizId,
    this.challengeId,
    this.shuffle = false,
    this.isPreview = false,
    this.initialQuestionId,
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
  bool _isPaused = false;

  Set<String> _selectedOptionIds = {};
  bool _isAnswerChecked = false;
  bool? _lastAnswerCorrect;

  int _correctCount = 0;
  int _wrongCount = 0;
  List<int> _timeTakenPerQuestion = [];
  int _currentQuestionStartTime = 0;
  List<Map<String, dynamic>> _userAnswers = [];

  @override
  void initState() {
    super.initState();
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

      bool isShuffle = false;
      if (widget.challengeId != null) {
        final client = Supabase.instance.client;
        final challenge = await client
            .from('quiz_challenges')
            .select('shuffle')
            .eq('id', widget.challengeId!)
            .single();
        isShuffle = challenge['shuffle'] as bool? ?? false;
      }

      if (mounted) {
        setState(() {
          _questions = data['questions'] as List<Question>;
          if ((isShuffle || widget.shuffle) && widget.initialQuestionId == null) {
            _questions.shuffle();
          }
          if (widget.initialQuestionId != null) {
            final targetIdx = _questions.indexWhere((q) => q.id == widget.initialQuestionId);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _startQuestion() {
    _selectedOptionIds.clear();
    _isAnswerChecked = false;
    _lastAnswerCorrect = null;
    _remainingSeconds = _questions[_currentIndex].durationSeconds;
    _currentQuestionStartTime = DateTime.now().millisecondsSinceEpoch;

    _timer?.cancel();
    if (!widget.isPreview) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_isPaused) return;

        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            _checkAnswer(); // Auto check if time is up
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

    setState(() {
      _isAnswerChecked = true;

      final currentQ = _questions[_currentIndex];
      bool isCorrect = false;

      final correctOptionIds = currentQ.options
          .where((o) => o.isCorrect)
          .map((o) => o.id)
          .toSet();

      if (correctOptionIds.isNotEmpty) {
        isCorrect =
            _selectedOptionIds.length == correctOptionIds.length &&
            _selectedOptionIds.every((id) => correctOptionIds.contains(id));
      }

      if (isCorrect) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
      _lastAnswerCorrect = isCorrect;

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

    // Auto next after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
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

    if (widget.isPreview) {
      if (mounted) {
        context.pop();
      }
      return;
    }

    double avgTime = 0;
    if (_timeTakenPerQuestion.isNotEmpty) {
      avgTime =
          _timeTakenPerQuestion.reduce((a, b) => a + b) /
          _timeTakenPerQuestion.length /
          1000.0;
    }

    final totalQuestions = _questions.isEmpty ? 1 : _questions.length;
    int score = isQuit ? 0 : (_correctCount * 100) ~/ totalQuestions;
    double accuracy = isQuit ? 0.0 : (_correctCount / totalQuestions) * 100.0;

    final attempt = QuizAttempt(
      id: '', // Will be assigned by DB
      userId: '', // Repository handles this
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

      // Award XP points: 2 XP per correct answer (do not award in preview mode)
      final int xpAwarded = _correctCount * 2;
      if (!widget.isPreview && xpAwarded > 0) {
        try {
          final client = Supabase.instance.client;
          final user = client.auth.currentUser;
          if (user != null) {
            int currentXp = 0;
            int currentWeeklyXp = 0;
            final metadata = user.userMetadata;
            if (metadata != null && metadata.containsKey('xp')) {
              currentXp = int.tryParse(metadata['xp'].toString()) ?? 0;
            }
            if (metadata != null && metadata.containsKey('weekly_xp')) {
              currentWeeklyXp = int.tryParse(metadata['weekly_xp'].toString()) ?? 0;
            }
            final newXp = currentXp + xpAwarded;
            final newWeeklyXp = currentWeeklyXp + xpAwarded;

            // Update Auth user metadata
            await client.auth.updateUser(
              UserAttributes(
                data: {
                  ...metadata ?? {},
                  'xp': newXp,
                  'weekly_xp': newWeeklyXp,
                },
              ),
            );

            // Update profiles table in public schema
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
                'score': score,
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
    // Safe database update without relying on BuildContext
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
    double progress = _remainingSeconds / question.durationSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Pause timer while dialog is open
        final wasPaused = _isPaused;
        setState(() => _isPaused = true);

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
        } else {
          if (mounted) {
            setState(() => _isPaused = wasPaused);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
          actions: [
            if (!widget.isPreview)
              IconButton(
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                onPressed: () {
                  setState(() {
                    _isPaused = !_isPaused;
                  });
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isPaused
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.pause_circle_outline,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Paused',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Resume'),
                        onPressed: () => setState(() => _isPaused = false),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        label: const Text(
                          'End Quiz',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('End Quiz'),
                              content: const Text(
                                'Are you sure you want to exit? Your progress will be lost.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Yes',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            _finishQuiz(isQuit: true);
                          }
                        },
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.isPreview) ...[
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: progress, end: progress),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return LinearProgressIndicator(value: value);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '00:${_remainingSeconds.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.right,
                      ),
                    ] else ...[
                      const Center(
                        child: Text(
                          'Quiz Preview Mode (Non-Scored)',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      question.questionText,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (_isAnswerChecked && _selectedOptionIds.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Timeout!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          children: [
                            if (_isAnswerChecked)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _lastAnswerCorrect == true
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _lastAnswerCorrect == true
                                          ? Colors.green.shade300
                                          : Colors.red.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _lastAnswerCorrect == true
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: _lastAnswerCorrect == true
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _lastAnswerCorrect == true
                                            ? 'Correct!'
                                            : 'Incorrect!',
                                        style: TextStyle(
                                          color: _lastAnswerCorrect == true
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: question.options.length,
                                itemBuilder: (context, index) {
                                  final option = question.options[index];
                                  final isMultipleChoice =
                                      question.options
                                          .where((o) => o.isCorrect)
                                          .length >
                                      1;
                                  final isSelected = _selectedOptionIds
                                      .contains(option.id);

                                  if (isMultipleChoice) {
                                    return Card(
                                      color: _isAnswerChecked
                                          ? (option.isCorrect
                                                ? Colors.green.shade200
                                                : (isSelected
                                                      ? Colors.red.shade200
                                                      : null))
                                          : null,
                                      child: CheckboxListTile(
                                        title: Text(option.optionText),
                                        value: isSelected,
                                        activeColor: Colors.deepPurple,
                                        onChanged: _isAnswerChecked
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedOptionIds.add(
                                                      option.id,
                                                    );
                                                  } else {
                                                    _selectedOptionIds.remove(
                                                      option.id,
                                                    );
                                                  }
                                                });
                                              },
                                      ),
                                    );
                                  } else {
                                    return Card(
                                      color: _isAnswerChecked
                                          ? (option.isCorrect
                                                ? Colors.green.shade200
                                                : (isSelected
                                                      ? Colors.red.shade200
                                                      : null))
                                          : null,
                                      child: RadioListTile<String>(
                                        title: Text(option.optionText),
                                        value: option.id,
                                        groupValue: isSelected
                                            ? option.id
                                            : null,
                                        activeColor: Colors.deepPurple,
                                        onChanged: _isAnswerChecked
                                            ? null
                                            : (val) {
                                                setState(
                                                  () => _selectedOptionIds = {
                                                    option.id,
                                                  },
                                                );
                                                _checkAnswer();
                                              },
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (!_isAnswerChecked &&
                                question.options
                                        .where((o) => o.isCorrect)
                                        .length >
                                    1)
                              SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 56.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
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
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
