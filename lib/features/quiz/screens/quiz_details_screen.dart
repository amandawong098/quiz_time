import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import 'package:quiz_time/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';

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
  Locale? _currentLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_currentLocale != locale) {
      _currentLocale = locale;
      _loadData();
    }
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
            content: Text(
              AppLocalizations.of(context)!.errorOccurred(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Widget _buildPerformanceChart() {
    if (_attempts.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    for (int i = 0; i < _attempts.length; i++) {
      double accuracy =
          (_attempts[i].correctAnswers / _attempts[i].totalQuestions) * 100;
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
            maxX: _attempts.length.toDouble() < 5
                ? 5
                : _attempts.length.toDouble(),
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

  Widget _buildDetailedAnalysis(QuizAttempt attempt, AppLocalizations l10n) {
    if (attempt.userAnswers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.detailedAnalysis,
            style: const TextStyle(fontWeight: FontWeight.bold),
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
    if (_quiz == null) {
      return Scaffold(body: Center(child: Text(l10n.noQuizzesFound)));
    }

    final lastAttempt = _attempts.isNotEmpty ? _attempts.last : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.quizDetails)),
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
                      label: Text(
                        L10nUtils.getLocalizedGrade(_quiz!.grade, l10n),
                      ),
                    ),
                    Chip(
                      label: Text(
                        L10nUtils.getLocalizedSubject(_quiz!.subject, l10n),
                      ),
                    ),
                    Chip(label: Text('${_questions.length} ${l10n.questions}')),
                  ],
                ),
                if (lastAttempt != null) ...[
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.lastAttemptSummary,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryBox(
                        title: l10n.correct,
                        value: lastAttempt.correctAnswers.toString(),
                      ),
                      _SummaryBox(
                        title: l10n.wrong,
                        value: lastAttempt.wrongAnswers.toString(),
                      ),
                      _SummaryBox(
                        title: l10n.avgTime,
                        value:
                            '${lastAttempt.avgTimePerQuestion?.toStringAsFixed(1) ?? 0}s',
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
                  _buildDetailedAnalysis(lastAttempt, l10n),
                ],
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/quiz/${widget.quizId}/take');
                    },
                    child: Text(
                      lastAttempt == null ? l10n.startQuiz : l10n.playAgain,
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
