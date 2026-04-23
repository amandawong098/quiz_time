import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/quiz_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:quiz_time/l10n/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/utils/l10n_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  int _quizzesPlayed = 0;
  int _quizzesCreated = 0;
  Map<String, double> _subjectAccuracy = {};
  List<String> _dbSubjects = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = context.read<QuizRepository>();

      _dbSubjects = await repo.getSubjects();

      final createdQuizzes = await repo.getMyQuizzes();
      final allAttempts = await repo.getAllQuizAttempts();

      final uniqueQuizIds = allAttempts
          .map((attempt) => attempt['quiz_id'])
          .toSet();

      Map<String, int> subjectCorrect = {};
      Map<String, int> subjectTotal = {};

      for (var s in _dbSubjects) {
        subjectCorrect[s] = 0;
        subjectTotal[s] = 0;
      }

      for (var attempt in allAttempts) {
        String subject = attempt['quizzes']['subject'] ?? 'Other';

        if (!subjectTotal.containsKey(subject)) {
          subject = 'Other';
          if (!subjectTotal.containsKey('Other')) {
            subjectTotal['Other'] = 0;
            subjectCorrect['Other'] = 0;
          }
        }

        subjectCorrect[subject] =
            (subjectCorrect[subject] ?? 0) +
            (attempt['correct_answers'] as int);
        subjectTotal[subject] =
            (subjectTotal[subject] ?? 0) + (attempt['total_questions'] as int);
      }

      Map<String, double> newAccuracy = {};
      subjectTotal.forEach((key, total) {
        if (total > 0) {
          newAccuracy[key] = ((subjectCorrect[key] ?? 0) / total) * 100;
        } else {
          newAccuracy[key] = 0;
        }
      });

      if (mounted) {
        setState(() {
          _quizzesCreated = createdQuizzes.length;
          _quizzesPlayed = uniqueQuizIds.length;
          _subjectAccuracy = newAccuracy;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLanguagePicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.changeLanguage),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLanguageOption('Default (System)', null, ctx),
                _buildLanguageOption('English', const Locale('en'), ctx),
                _buildLanguageOption(
                  'Malay (Bahasa Melayu)',
                  const Locale('ms'),
                  ctx,
                ),
                _buildLanguageOption('Chinese (中文)', const Locale('zh'), ctx),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    String label,
    Locale? locale,
    BuildContext dialogContext,
  ) {
    return ListTile(
      title: Text(label),
      onTap: () {
        context.read<LocaleProvider>().setLocale(locale);
        Navigator.pop(dialogContext);
      },
    );
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is permanent. All your quizzes and history will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await context.read<AuthRepository>().deleteAccount();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(e.toString());
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart(AppLocalizations l10n) {
    if (_subjectAccuracy.isEmpty) return const SizedBox.shrink();

    final subjects = _subjectAccuracy.keys.toList();

    return SizedBox(
      height: 300,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          radarBorderData: const BorderSide(color: Colors.deepPurple, width: 1),
          tickCount: 5,
          ticksTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
          titlePositionPercentageOffset: 0.1,
          titleTextStyle: const TextStyle(color: Colors.black, fontSize: 12),
          getTitle: (index, angle) {
            if (index >= subjects.length) {
              return const RadarChartTitle(text: '');
            }
            return RadarChartTitle(
              text: L10nUtils.getLocalizedSubject(subjects[index], l10n),
            );
          },
          dataSets: [
            RadarDataSet(
              fillColor: Colors.deepPurple.withValues(alpha: 0.2),
              borderColor: Colors.deepPurple,
              entryRadius: 0,
              dataEntries: subjects
                  .map((s) => RadarEntry(value: _subjectAccuracy[s] ?? 0))
                  .toList(),
            ),
            RadarDataSet(
              fillColor: Colors.transparent,
              borderColor: Colors.transparent,
              entryRadius: 0,
              dataEntries: List.generate(
                subjects.length,
                (_) => const RadarEntry(value: 100),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.me)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage:
                                  user?.userMetadata?['avatar_url'] != null
                                  ? NetworkImage(
                                      user!.userMetadata!['avatar_url'],
                                    )
                                  : null,
                              child: user?.userMetadata?['avatar_url'] == null
                                  ? const Icon(Icons.person, size: 40)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final result = await context.push('/me/edit');
                                  if (result == true) {
                                    _loadStats();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.userMetadata?['name'] ?? 'User Name',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? 'email@domain.com',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              title: l10n.noOfQuizPlayed,
                              value: _quizzesPlayed.toString(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatBox(
                              title: l10n.noOfQuizCreated,
                              value: _quizzesCreated.toString(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    Card(
                      elevation: 0,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.3),
                      child: ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(
                          l10n.changeLanguage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showLanguagePicker,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 24),
                    Text(
                      l10n.performanceAnalysis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRadarChart(l10n),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await context.read<AuthRepository>().signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.logout),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  const _StatBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
