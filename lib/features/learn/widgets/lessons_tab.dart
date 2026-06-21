import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../models/lesson_models.dart';
import '../models/lesson_progress.dart';

class LessonsTab extends StatefulWidget {
  const LessonsTab({super.key});

  @override
  State<LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<LessonsTab> {
  final MockLessonProgress _progressTracker = MockLessonProgress();
  bool _isChapterExpanded = true;
  String _selectedLessonCourse = 'Tech for Everyone';

  // State for database lessons
  bool _isLoadingDb = false;
  List<LessonCourse> _dbCourses = [];
  List<LessonChapter> _dbChapters = [];
  Map<String, List<LessonSubChapter>> _dbSubChaptersMap = {};

  final List<Map<String, dynamic>> _subChapters = [
    {'id': 'humans_machines', 'title': 'Humans vs Machines', 'xp': 10},
    {'id': 'thinking_machine', 'title': 'Thinking Like a Machine', 'xp': 10},
    {
      'id': 'instructions_machines',
      'title': 'Giving Instructions to Machines',
      'xp': 10,
    },
    {
      'id': 'algorithms_flowcharts',
      'title': 'Algorithms & Flowcharts',
      'xp': 10,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDbLessons();
  }

  Future<void> _loadDbLessons() async {
    if (!mounted) return;
    setState(() => _isLoadingDb = true);
    try {
      final repo = context.read<LessonRepository>();
      final courses = await repo.getCourses();

      // Load chapters and subchapters of selected course if it's a DB course
      List<LessonChapter> chapters = [];
      final Map<String, List<LessonSubChapter>> subChaptersMap = {};

      final dbCourseIdx = courses.indexWhere(
        (c) => c.title == _selectedLessonCourse,
      );
      if (dbCourseIdx != -1) {
        final course = courses[dbCourseIdx];
        chapters = await repo.getChapters(course.id);
        for (var ch in chapters) {
          final subs = await repo.getSubChapters(ch.id);
          subChaptersMap[ch.id] = subs;
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

  @override
  Widget build(BuildContext context) {
    final isMock = _selectedLessonCourse == 'Tech for Everyone';

    // Calculate progress
    double progress = 0.0;
    if (isMock) {
      int completedCount = 0;
      for (var sub in _subChapters) {
        if (_progressTracker.isCompleted(sub['id'])) {
          completedCount++;
        }
      }
      progress = completedCount / _subChapters.length;
    } else {
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
      onRefresh: _loadDbLessons,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Selection Dropdown
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    initialValue: _selectedLessonCourse,
                    onSelected: (String value) {
                      setState(() {
                        _selectedLessonCourse = value;
                      });
                      _loadDbLessons();
                    },
                    itemBuilder: (BuildContext context) {
                      final List<PopupMenuEntry<String>> items = [
                        const PopupMenuItem<String>(
                          value: 'Tech for Everyone',
                          child: Text(
                            'Tech for Everyone',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ];
                      for (var course in _dbCourses) {
                        if (course.title != 'Tech for Everyone') {
                          items.add(
                            PopupMenuItem<String>(
                              value: course.title,
                              child: Text(course.title),
                            ),
                          );
                        }
                      }
                      return items;
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 16.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedLessonCourse,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.deepPurple.shade900,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final isMock =
                          _selectedLessonCourse == 'Tech for Everyone';
                      if (isMock) {
                        context.push('/learn/lesson-player');
                      } else {
                        final dbCourse = _dbCourses.firstWhere(
                          (c) => c.title == _selectedLessonCourse,
                        );
                        context.push(
                          '/learn/lesson-player?courseId=${dbCourse.id}',
                        );
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
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

            if (_isLoadingDb)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (isMock)
              _buildMockChapters()
            else
              _buildDbChapters(),
          ],
        ),
      ),
    );
  }

  Widget _buildMockChapters() {
    return Column(
      children: [
        // Collapsible Chapter Header Card
        GestureDetector(
          onTap: () {
            setState(() {
              _isChapterExpanded = !_isChapterExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill,
                  color: Colors.deepPurple.shade800,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'How to Think like a Coder',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                ),
                Icon(
                  _isChapterExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.deepPurple.shade800,
                ),
              ],
            ),
          ),
        ),

        // Sub-chapter list
        if (_isChapterExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: _subChapters.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, dynamic> sub = entry.value;
                final String id = sub['id'];
                final String title = sub['title'];
                final int xp = sub['xp'];

                final bool isCompleted = _progressTracker.isCompleted(id);
                final bool isUnlocked = _progressTracker.isUnlocked(id);
                final bool isActive = isUnlocked && !isCompleted;

                return GestureDetector(
                  onTap: () {
                    if (!isUnlocked) {
                      String prevTitle = 'the previous lesson';
                      if (index > 0) {
                        prevTitle = _subChapters[index - 1]['title'];
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isUnlocked
                                            ? Colors.black87
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                    if (isUnlocked && !isCompleted) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          'XP +$xp',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
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
    );
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

    // Flatten all subchapters to calculate sequential unlock index
    final List<LessonSubChapter> allSubs = [];
    for (var ch in _dbChapters) {
      allSubs.addAll(_dbSubChaptersMap[ch.id] ?? []);
    }

    return Column(
      children: _dbChapters.map((ch) {
        final subs = _dbSubChaptersMap[ch.id] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurple.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill,
                    color: Colors.deepPurple.shade800,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ch.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: subs.map((sub) {
                  final globalIdx = allSubs.indexWhere((s) => s.id == sub.id);
                  final bool isCompleted = _progressTracker.isCompleted(sub.id);
                  final bool isUnlocked =
                      globalIdx == 0 ||
                      (globalIdx > 0 &&
                          _progressTracker.isCompleted(
                            allSubs[globalIdx - 1].id,
                          ));
                  final bool isActive = isUnlocked && !isCompleted;

                  return GestureDetector(
                    onTap: () {
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
                                      if (isUnlocked && !isCompleted) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'XP +${sub.xpReward}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
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
        );
      }).toList(),
    );
  }
}
