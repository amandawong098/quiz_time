import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';

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
  List<QuizAttempt> _attempts = [];

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
      if (mounted) {
        setState(() {
          _quiz = data['quiz'] as Quiz;
          _questions = data['questions'] as List<Question>;
          _attempts = attempts;
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



  Widget _buildDetailedAnalysis(QuizAttempt attempt) {
    if (attempt.userAnswers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Detailed Analysis',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(attempt.userAnswers.length, (index) {
          final answerData = attempt.userAnswers[index];
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
    if (_quiz == null) {
      return const Scaffold(body: Center(child: Text('No quizzes found.')));
    }

    final lastAttempt = _attempts.isNotEmpty ? _attempts.last : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Details')),
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
                      label: Text(_quiz!.grade ?? ''),
                    ),
                    Chip(
                      label: Text(_quiz!.subject ?? ''),
                    ),
                    Chip(label: Text('${_questions.length} Questions')),
                  ],
                ),
                if (lastAttempt != null) ...[
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Last Attempt Summary',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryBox(
                        title: 'Correct',
                        value: lastAttempt.correctAnswers.toString(),
                      ),
                      _SummaryBox(
                        title: 'Wrong',
                        value: lastAttempt.wrongAnswers.toString(),
                      ),
                      _SummaryBox(
                        title: 'Avg Time',
                        value:
                            '${lastAttempt.avgTimePerQuestion?.toStringAsFixed(1) ?? 0}s',
                      ),
                    ],
                  ),
                  _buildDetailedAnalysis(lastAttempt),
                ],
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/quiz/${widget.quizId}/take');
                    },
                    child: Text(
                      lastAttempt == null ? 'Start Quiz' : 'Play Again!',
                    ),
                  ),
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
