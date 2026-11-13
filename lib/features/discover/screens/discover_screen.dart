import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../core/widgets/cosmic_background.dart';
import '../../../core/widgets/quiz_filter_bar.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../profile/widgets/user_detail_bottom_sheet.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _searchQuery = '';
  String? _selectedQuestionRange;
  List<Quiz> _quizzes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<QuizRepository>();

      final results = await repo.getPublicQuizzes(
        query: _searchQuery,
        questionRange: _selectedQuestionRange,
      );
      if (mounted) {
        setState(() {
          _quizzes = results;
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

  String _getQuestionBadgeEmoji(int count) {
    if (count <= 5) return '☄️';
    if (count <= 10) return '🚀';
    if (count <= 20) return '🪐';
    return '🌌';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        flexibleSpace: const CosmicAppBarFlexibleSpace(seed: 22),
        actions: const [
          NotificationIconBadge(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            QuizFilterBar(
              searchQuery: _searchQuery,
              selectedQuestionRange: _selectedQuestionRange,
              onSearchChanged: (v) {
                _searchQuery = v;
                _loadQuizzes();
              },
              onQuestionRangeChanged: (v) {
                setState(() => _selectedQuestionRange = v);
                _loadQuizzes();
              },
              onReset: () {
                setState(() {
                  _searchQuery = '';
                  _selectedQuestionRange = null;
                });
                _loadQuizzes();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadQuizzes,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _quizzes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(child: Text('No quizzes found.')),
                              ),
                            ],
                          )
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: _quizzes.length,
                            itemBuilder: (context, index) {
                              final quiz = _quizzes[index];
                              return Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    context.push('/quiz/${quiz.id}');
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Cover Image or Cosmic Starfield Banner
                                      quiz.imageUrl != null
                                          ? Container(
                                              height: 80,
                                              decoration: BoxDecoration(
                                                image: DecorationImage(
                                                  image: NetworkImage(
                                                    quiz.imageUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )
                                          : SizedBox(
                                              height: 80,
                                              child: CosmicNebulaBox(
                                                borderRadius: BorderRadius.zero,
                                                seed: quiz.id.hashCode,
                                                showPlanet: true,
                                                child: Center(
                                                  child: Icon(
                                                    index % 3 == 0
                                                        ? Icons.rocket_launch_rounded
                                                        : (index % 3 == 1
                                                            ? Icons.auto_awesome_rounded
                                                            : Icons.public_rounded),
                                                    size: 28,
                                                    color: CosmicColors.starlightGold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                      // Content Area
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    quiz.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (quiz.description != null &&
                                                      quiz.description!
                                                          .trim()
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      quiz.description!,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade600,
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.deepPurple.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          _getQuestionBadgeEmoji(
                                                            quiz.questionCount,
                                                          ),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${quiz.questionCount} Qs',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .deepPurple
                                                                .shade700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (quiz.creatorId.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    InkWell(
                                                      onTap: () {
                                                        UserDetailBottomSheet.show(
                                                          context,
                                                          userId: quiz.creatorId,
                                                          name: quiz.creatorName ??
                                                              'Author',
                                                          avatarUrl:
                                                              quiz.creatorAvatarUrl,
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                      child: Padding(
                                                        padding: const EdgeInsets
                                                            .symmetric(vertical: 2),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            CircleAvatar(
                                                              radius: 8,
                                                              backgroundColor:
                                                                  Colors.deepPurple
                                                                      .shade100,
                                                              backgroundImage: (quiz.creatorAvatarUrl !=
                                                                          null &&
                                                                      quiz.creatorAvatarUrl!
                                                                          .isNotEmpty)
                                                                  ? NetworkImage(quiz
                                                                      .creatorAvatarUrl!)
                                                                  : null,
                                                              child: (quiz.creatorAvatarUrl ==
                                                                          null ||
                                                                      quiz.creatorAvatarUrl!
                                                                          .isEmpty)
                                                                  ? const Icon(
                                                                      Icons.person,
                                                                      size: 9,
                                                                      color: Colors
                                                                          .deepPurple)
                                                                  : null,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                quiz.creatorName ??
                                                                    'Author',
                                                                maxLines: 1,
                                                                overflow: TextOverflow
                                                                    .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight.w600,
                                                                  color: Colors
                                                                      .deepPurple
                                                                      .shade700,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
