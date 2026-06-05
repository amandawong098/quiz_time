import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';

class QuizReviewScreen extends StatefulWidget {
  final String quizId;
  final String attemptId;
  const QuizReviewScreen({
    super.key,
    required this.quizId,
    required this.attemptId,
  });

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  bool _isLoading = true;
  QuizAttempt? _attempt;

  @override
  void initState() {
    super.initState();
    _loadData();
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
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_attempt!.userAnswers.length, (index) {
          final answerData = _attempt!.userAnswers[index];
          final questionText = answerData['question_text'] ?? 'Question';
          final selectedOptionId = answerData['selected_option_id'];
          final List options = answerData['options'] ?? [];

          return Card(
            color: selectedOptionId == null ? Colors.grey.shade200 : null,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Questions ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selectedOptionId == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Unattempted (Timeout)',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isCorrect = opt['is_correct'] == true;
                    final isSelected = opt['id'] == selectedOptionId;

                    Color? bgColor;
                    if (isCorrect) {
                      bgColor = selectedOptionId == null
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
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: _attempt!.score / 100,
                    strokeWidth: 15,
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
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SummaryBox(
                  title: 'Correct',
                  value: _attempt!.correctAnswers.toString(),
                ),
                _SummaryBox(
                  title: 'Wrong',
                  value: _attempt!.wrongAnswers.toString(),
                ),
                _SummaryBox(
                  title: 'Avg Time',
                  value:
                      '${_attempt!.avgTimePerQuestion?.toStringAsFixed(1) ?? 0}s',
                ),
              ],
            ),

            _buildDetailedAnalysis(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                context.pushReplacement('/quiz/${widget.quizId}/take');
              },
              child: const Text('Play Again!'),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
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
}
