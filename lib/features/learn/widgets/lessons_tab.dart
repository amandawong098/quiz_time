import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../models/lesson_models.dart';
import '../models/lesson_progress.dart';

class LessonsTab extends StatefulWidget {
  const LessonsTab({super.key});

  @override
  State<LessonsTab> createState() => LessonsTabState();
}

class LessonsTabState extends State<LessonsTab> {
  final MockLessonProgress _progressTracker = MockLessonProgress();
  
  // State for active lesson and preview
  String? _selectedLessonCourseId;
  LessonCourse? _previewCourse;

  // State for database lessons
  bool _isLoadingDb = false;
  List<LessonCourse> _dbCourses = [];
  List<LessonChapter> _dbChapters = [];
  Map<String, List<LessonSubChapter>> _dbSubChaptersMap = {};

  @override
  void initState() {
    super.initState();
    _loadInitialCourseAndLessons();
  }

  Future<void> _loadInitialCourseAndLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString('current_lesson_course_id');
      setState(() {
        _selectedLessonCourseId = storedId;
      });
    } catch (_) {}
    await loadDbLessons();
  }

  Future<void> loadDbLessons() async {
    if (!mounted) return;
    setState(() => _isLoadingDb = true);
    try {
      final repo = context.read<LessonRepository>();
      final courses = await repo.getCourses();

      List<LessonChapter> chapters = [];
      final Map<String, List<LessonSubChapter>> subChaptersMap = {};

      if (_selectedLessonCourseId != null) {
        final dbCourseIdx = courses.indexWhere(
          (c) => c.id == _selectedLessonCourseId,
        );
        if (dbCourseIdx != -1) {
          final course = courses[dbCourseIdx];
          chapters = await repo.getChapters(course.id);
          for (var ch in chapters) {
            final subs = await repo.getSubChapters(ch.id);
            subChaptersMap[ch.id] = subs;
          }
        } else {
          // Reset selection if course no longer exists in DB
          _selectedLessonCourseId = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _dbCourses = courses;
        _dbChapters = chapters;
        _dbSubChaptersMap = subChaptersMap;
        _isLoadingDb = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDb = false;
      });
    }
  }

  Future<void> _startLearningCourse(LessonCourse course) async {
    setState(() {
      _selectedLessonCourseId = course.id;
      _previewCourse = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_lesson_course_id', course.id);
    } catch (_) {}

    await loadDbLessons();
  }

  Widget _buildDiscoveryView() {
    if (_dbCourses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64.0, horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No lessons available yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later for newly added learning materials.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Lessons',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a lesson to begin your learning journey.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          itemCount: _dbCourses.length,
          itemBuilder: (context, index) {
            final course = _dbCourses[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _previewCourse = course;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.deepPurple.shade50,
                        ),
                        child: course.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  course.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.school_rounded,
                                color: Colors.deepPurple,
                                size: 32,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (course.description != null &&
                                course.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                course.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildIntroView(LessonCourse course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _previewCourse = null;
                });
              },
              icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
              label: const Text(
                'Back to Explore',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.deepPurple.shade50,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: course.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              course.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.school_rounded,
                            color: Colors.deepPurple,
                            size: 64,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    course.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: course.isPublic
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: course.isPublic
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      course.isPublic ? 'Public Lesson' : 'Private Lesson',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: course.isPublic
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (course.description != null &&
                      course.description!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      course.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ] else ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'No description provided for this lesson.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _startLearningCourse(course),
                      child: const Text(
                        'Start Learning',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isSubChapterUnlocked(LessonSubChapter sub, List<LessonSubChapter> allSubs) {
    final globalIdx = allSubs.indexWhere((s) => s.id == sub.id);
    return globalIdx == 0 ||
        (globalIdx > 0 && _progressTracker.isCompleted(allSubs[globalIdx - 1].id));
  }

  Widget _buildDbChapters() {
    if (_dbChapters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'No chapters in this lesson yet.',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<LessonSubChapter> allSubs = [];
    for (var ch in _dbChapters) {
      allSubs.addAll(_dbSubChaptersMap[ch.id] ?? []);
    }

    // Find the current sub-chapter user should continue at
    String? activeSubChapterId;
    for (var sub in allSubs) {
      if (!_progressTracker.isCompleted(sub.id)) {
        activeSubChapterId = sub.id;
        break;
      }
    }

    String? activeChapterId;
    if (activeSubChapterId != null) {
      activeChapterId = _dbChapters.firstWhere(
        (ch) => (_dbSubChaptersMap[ch.id] ?? []).any((s) => s.id == activeSubChapterId),
        orElse: () => _dbChapters.first,
      ).id;
    } else if (_dbChapters.isNotEmpty) {
      // If everything is completed, expand the last chapter
      activeChapterId = _dbChapters.last.id;
    }

    return Column(
      children: _dbChapters.map((ch) {
        final subs = _dbSubChaptersMap[ch.id] ?? [];

        final isChCompleted = subs.isNotEmpty && subs.every((sub) => _progressTracker.isCompleted(sub.id));
        final isChLocked = subs.isNotEmpty && !_isSubChapterUnlocked(subs.first, allSubs);

        // Visual properties based on state
        Color cardBgColor;
        Color borderColor;
        Color iconColor;
        Color textColor;
        IconData headerIcon;
        Widget? trailingWidget;

        if (isChCompleted) {
          cardBgColor = Colors.green.shade50.withValues(alpha: 0.3);
          borderColor = Colors.green.shade200;
          iconColor = Colors.green.shade700;
          textColor = Colors.green.shade900;
          headerIcon = Icons.check_circle_rounded;
          trailingWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Completed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          );
        } else if (isChLocked) {
          cardBgColor = Colors.grey.shade50;
          borderColor = Colors.grey.shade200;
          iconColor = Colors.grey.shade400;
          textColor = Colors.grey.shade500;
          headerIcon = Icons.lock_outline;
          trailingWidget = const Icon(Icons.lock_outline, color: Colors.grey, size: 20);
        } else {
          cardBgColor = Colors.deepPurple.shade50.withValues(alpha: 0.5);
          borderColor = Colors.deepPurple.shade200;
          iconColor = Colors.deepPurple.shade800;
          textColor = Colors.deepPurple.shade900;
          headerIcon = Icons.book_rounded;
        }

        final isExpanded = ch.id == activeChapterId;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              unselectedWidgetColor: iconColor,
            ),
            child: ExpansionTile(
              key: Key('${ch.id}_${activeChapterId == ch.id}'),
              initiallyExpanded: isExpanded,
              onExpansionChanged: isChLocked ? (expanded) => false : null,
              leading: Icon(
                headerIcon,
                color: iconColor,
                size: 28,
              ),
              title: Text(
                ch.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              trailing: isChLocked
                  ? trailingWidget
                  : (isChCompleted
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (trailingWidget != null) ...[
                              trailingWidget,
                              const SizedBox(width: 8),
                            ],
                            const Icon(Icons.expand_more),
                          ],
                        )
                      : null),
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: subs.map((sub) {
                      final globalIdx = allSubs.indexWhere((s) => s.id == sub.id);
                      final bool isCompleted = _progressTracker.isCompleted(sub.id);
                      final bool isUnlocked = _isSubChapterUnlocked(sub, allSubs);
                      final bool isActive = isUnlocked && !isCompleted;

                      // Visual styling for sub-chapter badge
                      Color badgeBgColor;
                      Color badgeBorderColor;
                      Color badgeTextColor;

                      if (isCompleted) {
                        badgeBgColor = Colors.green.shade50;
                        badgeBorderColor = Colors.green.shade200;
                        badgeTextColor = Colors.green.shade800;
                      } else if (isUnlocked) {
                        badgeBgColor = Colors.deepPurple.shade50;
                        badgeBorderColor = Colors.deepPurple.shade200;
                        badgeTextColor = Colors.deepPurple.shade800;
                      } else {
                        badgeBgColor = Colors.grey.shade100;
                        badgeBorderColor = Colors.grey.shade300;
                        badgeTextColor = Colors.grey.shade600;
                      }

                      return GestureDetector(
                        onTap: () async {
                          if (!isUnlocked) {
                            String prevTitle = 'the previous lesson';
                            if (globalIdx > 0) {
                              prevTitle = allSubs[globalIdx - 1].title;
                            }
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Lesson Locked'),
                                content: Text(
                                  'Please complete "$prevTitle" first to unlock this lesson.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            final result = await context.push<bool>(
                              '/learn/lesson-player?subChapterId=${sub.id}',
                            );
                            if (result == true) {
                              loadDbLessons();
                            }
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: isActive ? 2 : 0,
                          color: isUnlocked
                              ? Colors.white
                              : Colors.grey.shade50.withValues(alpha: 0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isActive
                                  ? Colors.deepPurple.shade200
                                  : Colors.grey.shade200,
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isUnlocked
                                            ? Colors.deepPurple.shade50
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.description_outlined,
                                        color: isUnlocked
                                            ? Colors.deepPurple.shade700
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Lesson',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            sub.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isUnlocked
                                                  ? Colors.black87
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeBgColor,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: badgeBorderColor),
                                            ),
                                            child: Text(
                                              'XP +${sub.xpReward}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: badgeTextColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCompleted)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                        size: 28,
                                      )
                                    else if (!isUnlocked)
                                      Icon(
                                        Icons.lock_outline,
                                        color: Colors.grey.shade400,
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCourseIdx = _dbCourses.indexWhere((c) => c.id == _selectedLessonCourseId);
    final activeCourse = activeCourseIdx != -1 ? _dbCourses[activeCourseIdx] : null;

    final isViewingActiveLesson = _selectedLessonCourseId != null && activeCourse != null;

    // Calculate progress for active course
    double progress = 0.0;
    if (isViewingActiveLesson) {
      int totalSubs = 0;
      int completedSubs = 0;
      for (var ch in _dbChapters) {
        final subs = _dbSubChaptersMap[ch.id] ?? [];
        totalSubs += subs.length;
        for (var sub in subs) {
          if (_progressTracker.isCompleted(sub.id)) {
            completedSubs++;
          }
        }
      }
      progress = totalSubs > 0 ? completedSubs / totalSubs : 0.0;
    }

    return RefreshIndicator(
      onRefresh: loadDbLessons,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoadingDb)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 64.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_previewCourse != null)
              _buildIntroView(_previewCourse!)
            else if (isViewingActiveLesson) ...[
              // Active Lesson Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activeCourse.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedLessonCourseId = null;
                        });
                      },
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text('Browse All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Course Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDbChapters(),
            ] else
              _buildDiscoveryView(),
          ],
        ),
      ),
    );
  }
}
