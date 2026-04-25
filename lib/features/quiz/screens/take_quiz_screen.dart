import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';

import 'package:quiz_time/l10n/app_localizations.dart';

class TakeQuizScreen extends StatefulWidget {
  final String quizId;
  const TakeQuizScreen({super.key, required this.quizId});

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

  String? _selectedOptionId;
  bool _isAnswerChecked = false;

  int _correctCount = 0;
  int _wrongCount = 0;
  final List<int> _timeTakenPerQuestion = [];
  int _currentQuestionStartTime = 0;
  final List<Map<String, dynamic>> _userAnswers = [];

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final repo = context.read<QuizRepository>();
      final data = await repo.getQuizDetails(widget.quizId);
      if (mounted) {
        setState(() {
          _questions = data['questions'] as List<Question>;
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
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorOccurred(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _startQuestion() {
    _selectedOptionId = null;
    _isAnswerChecked = false;
    _remainingSeconds = _questions[_currentIndex].durationSeconds;
    _currentQuestionStartTime = DateTime.now().millisecondsSinceEpoch;

    _timer?.cancel();
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
      if (_selectedOptionId != null) {
        final opt = currentQ.options.firstWhere(
          (o) => o.id == _selectedOptionId,
        );
        isCorrect = opt.isCorrect;
      }

      if (isCorrect) {
        _correctCount++;
      } else {
        _wrongCount++;
      }

      _userAnswers.add({
        'question_text': currentQ.questionText,
        'selected_option_id': _selectedOptionId,
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

  Future<void> _finishQuiz() async {
    double avgTime = 0;
    if (_timeTakenPerQuestion.isNotEmpty) {
      avgTime =
          _timeTakenPerQuestion.reduce((a, b) => a + b) /
          _timeTakenPerQuestion.length /
          1000.0;
    }

    int score = (_correctCount * 100) ~/ _questions.length;

    final attempt = QuizAttempt(
      id: '', // Will be assigned by DB
      userId: '', // Repository handles this
      quizId: widget.quizId,
      score: score,
      totalQuestions: _questions.length,
      correctAnswers: _correctCount,
      wrongAnswers: _wrongCount,
      avgTimePerQuestion: avgTime,
      createdAt: DateTime.now(),
      userAnswers: _userAnswers,
    );

    try {
      final repo = context.read<QuizRepository>();
      final attemptId = await repo.saveQuizAttempt(attempt);
      if (mounted) {
        context.pushReplacement(
          '/quiz/${widget.quizId}/review',
          extra: {'attemptId': attemptId},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToSave(e.toString()),
            ),
          ),
        );
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noQuizzesFound)),
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
            title: Text(l10n.exitQuizConfirmTitle),
            content: Text(l10n.exitQuizConfirmDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.no),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n.yes,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        if (shouldPop == true) {
          if (mounted) context.pop();
        } else {
          if (mounted) {
            setState(() => _isPaused = wasPaused);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.questionXofY(_currentIndex + 1, _questions.length)),
          actions: [
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
                      Text(
                        l10n.pausedTitle,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.resume),
                        onPressed: () => setState(() => _isPaused = false),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        label: Text(
                          l10n.endQuiz,
                          style: const TextStyle(color: Colors.red),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.endQuiz),
                              content: Text(l10n.exitQuizConfirmDesc),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.no),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(
                                    l10n.yes,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            _finishQuiz();
                          }
                        },
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 32),
                    Text(
                      question.questionText,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (_isAnswerChecked && _selectedOptionId == null)
                      Expanded(
                        child: Center(
                          child: Text(
                            l10n.timeout,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: question.options.length,
                          itemBuilder: (context, index) {
                            final option = question.options[index];

                            return Card(
                              color: _isAnswerChecked
                                  ? (option.isCorrect
                                        ? Colors.green.shade200
                                        : (option.id == _selectedOptionId
                                              ? Colors.red.shade200
                                              : null))
                                  : null,
                              child: RadioListTile<String>(
                                title: Text(option.optionText),
                                value: option.id,
                                groupValue: _selectedOptionId,
                                onChanged: _isAnswerChecked
                                    ? null
                                    : (val) {
                                        setState(() => _selectedOptionId = val);
                                        _checkAnswer();
                                      },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
