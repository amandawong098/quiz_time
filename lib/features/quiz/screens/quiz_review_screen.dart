import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import 'package:quiz_time/l10n/app_localizations.dart';

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
  List<QuizAttempt> _allAttempts = [];

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
          _allAttempts = attempts;
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

  Widget _buildPerformanceChart() {
    if (_allAttempts.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    for (int i = 0; i < _allAttempts.length; i++) {
      double accuracy =
          (_allAttempts[i].correctAnswers / _allAttempts[i].totalQuestions) *
          100;
      spots.add(FlSpot((i + 1).toDouble(), accuracy));
    }

    return SizedBox(
      height: 250,
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0, top: 16.0),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            minX: 1,
            maxX: _allAttempts.length.toDouble() < 5
                ? 5
                : _allAttempts.length.toDouble(),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.deepPurple,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}%',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) => Text(
                    '#${value.toInt()}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withValues(alpha: 0.1),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedAnalysis(AppLocalizations l10n) {
    if (_attempt == null || _attempt!.userAnswers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.detailedAnalysis,
            style: const TextStyle(fontWeight: FontWeight.bold),
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
                    '${l10n.questions} ${index + 1}',
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
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        l10n.unattemptedTimeout,
                        style: const TextStyle(
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
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_attempt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.attemptNotFound)),
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
        title: Text(l10n.review),
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
                  ? l10n.tryAgain
                  : (_attempt!.score < 80 ? l10n.goodJob : l10n.outstanding),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SummaryBox(
                  title: l10n.correct,
                  value: _attempt!.correctAnswers.toString(),
                ),
                _SummaryBox(
                  title: l10n.wrong,
                  value: _attempt!.wrongAnswers.toString(),
                ),
                _SummaryBox(
                  title: l10n.avgTime,
                  value:
                      '${_attempt!.avgTimePerQuestion?.toStringAsFixed(1) ?? 0}s',
                ),
              ],
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.performanceGrowth,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            _buildPerformanceChart(),
            const SizedBox(height: 32),
            _buildDetailedAnalysis(l10n),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                context.pushReplacement('/quiz/${widget.quizId}/take');
              },
              child: Text(l10n.playAgain),
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
