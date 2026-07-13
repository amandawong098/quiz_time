import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../models/lesson_models.dart';
import './lesson_discussions_sheet.dart';
import '../models/lesson_progress.dart';

class LessonsTab extends StatefulWidget {
  final String? initialCourseId;
  final VoidCallback? onBrowseModeChanged;
  const LessonsTab({super.key, this.initialCourseId, this.onBrowseModeChanged});

  @override
  State<LessonsTab> createState() => LessonsTabState();
}

class LessonsTabState extends State<LessonsTab> {
  final LessonProgress _progressTracker = LessonProgress();
  final TextEditingController _searchController = TextEditingController();
  
  // State for active lesson and preview
  String? _selectedLessonCourseId;
  bool _isBrowsing = false;

  // State for database lessons
  bool _isLoadingDb = false;
  List<LessonCourse> _dbCourses = [];
  List<LessonChapter> _dbChapters = [];
  Map<String, List<LessonSubChapter>> _dbSubChaptersMap = {};
  Map<String, List<LessonChapter>> _allChaptersMap = {};
  Map<String, List<LessonSubChapter>> _allSubChaptersMap = {};

  String _searchQuery = '';
  String _activeTab = 'All';

  // Cache for course discussion count futures to prevent constant recreation on rebuilds
  final Map<String, Future<int>> _courseDiscussionCountFutures = {};

  Future<int> _getDiscussionCountFuture(String courseId) {
    return _courseDiscussionCountFutures.putIfAbsent(
      courseId,
      () => context
          .read<DiscussionRepository>()
          .getCourseTotalDiscussionsCount(courseId),
    );
  }

  // Public getter so parent can check if in browse mode vs active lesson
  bool get isShowingBrowseMode => _isBrowsing || _selectedLessonCourseId == null;

  @override
  void initState() {
    super.initState();
    _loadInitialCourseAndLessons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialCourseAndLessons() async {
    String? storedId = widget.initialCourseId;
    if (storedId == null) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final metadata = user.userMetadata;
          if (metadata != null && metadata.containsKey('current_lesson_course_id')) {
            storedId = metadata['current_lesson_course_id'] as String?;
          }
        } catch (_) {}

        if (storedId == null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            storedId = prefs.getString('current_lesson_course_id_${user.id}');
          } catch (_) {}
        }
      }
    } else {
      // If initialized with a specific course, start in browse mode to display its preview
      _isBrowsing = true;
    }

    setState(() {
      _selectedLessonCourseId = storedId;
    });
    await loadDbLessons();

    // If an initialCourseId was specified, open the preview sheet after build completes
    if (widget.initialCourseId != null && mounted) {
      final courseIdx = _dbCourses.indexWhere((c) => c.id == widget.initialCourseId);
      if (courseIdx != -1) {
        final course = _dbCourses[courseIdx];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showCoursePreviewSheet(course);
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant LessonsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCourseId != null && widget.initialCourseId != oldWidget.initialCourseId) {
      setState(() {
        _isBrowsing = true;
      });
      widget.onBrowseModeChanged?.call();
      final courseIdx = _dbCourses.indexWhere((c) => c.id == widget.initialCourseId);
      if (courseIdx != -1) {
        final course = _dbCourses[courseIdx];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showCoursePreviewSheet(course);
          }
        });
      }
    }
  }

  double _getCourseProgress(LessonCourse course, Map<String, List<LessonChapter>> chaptersMap, Map<String, List<LessonSubChapter>> subChaptersMap) {
    final chapters = chaptersMap[course.id] ?? [];
    int totalSubs = 0;
    int completedSubs = 0;
    for (var ch in chapters) {
      final subs = subChaptersMap[ch.id] ?? [];
      totalSubs += subs.length;
      for (var sub in subs) {
        if (_progressTracker.isCompleted(sub.id)) {
          completedSubs++;
        }
      }
    }
    if (totalSubs == 0) return 0.0;
    return completedSubs / totalSubs;
  }

  int _getCourseCategory(LessonCourse course, double progress) {
    final chapters = _allChaptersMap[course.id] ?? [];
    int totalSubs = 0;
    for (var ch in chapters) {
      totalSubs += (_allSubChaptersMap[ch.id] ?? []).length;
    }

    final isCompleted = totalSubs > 0 && progress == 1.0;
    final isCurrent = course.id == _selectedLessonCourseId || (progress > 0.0 && progress < 1.0);

    if (isCompleted) {
      return 2; // Completed at bottom
    } else if (isCurrent) {
      return 1; // Current in middle
    } else {
      return 0; // Not yet learned on top
    }
  }

  Future<void> loadDbLessons() async {
    if (!mounted) return;
    setState(() => _isLoadingDb = true);
    try {
      _courseDiscussionCountFutures.clear(); // Clear cache on reload
      await _progressTracker.loadFromSupabase();
      if (!mounted) return;
      final repo = context.read<LessonRepository>();
      final allCourses = await repo.getCourses();

      final user = Supabase.instance.client.auth.currentUser;
      final currentUserId = user?.id;
      final courses = allCourses.where((c) => c.isPublic || c.creatorId == currentUserId).toList();

      final Map<String, List<LessonChapter>> chaptersMap = {};
      final Map<String, List<LessonSubChapter>> subChaptersMap = {};

      for (var course in courses) {
        if (!mounted) return;
        final chapters = await repo.getChapters(course.id);
        chaptersMap[course.id] = chapters;
        for (var ch in chapters) {
          if (!mounted) return;
          final subs = await repo.getSubChapters(ch.id);
          subChaptersMap[ch.id] = subs;
        }
      }

      _allChaptersMap = chaptersMap;
      _allSubChaptersMap = subChaptersMap;

      courses.sort((a, b) {
        final progressA = _getCourseProgress(a, chaptersMap, subChaptersMap);
        final progressB = _getCourseProgress(b, chaptersMap, subChaptersMap);

        final catA = _getCourseCategory(a, progressA);
        final catB = _getCourseCategory(b, progressB);

        return catA.compareTo(catB);
      });

      List<LessonChapter> activeChapters = [];
      final Map<String, List<LessonSubChapter>> activeSubChaptersMap = {};

      if (_selectedLessonCourseId != null) {
        final dbCourseIdx = courses.indexWhere(
          (c) => c.id == _selectedLessonCourseId,
        );
        if (dbCourseIdx != -1) {
          activeChapters = chaptersMap[_selectedLessonCourseId] ?? [];
          for (var ch in activeChapters) {
            activeSubChaptersMap[ch.id] = subChaptersMap[ch.id] ?? [];
          }
        } else {
          _selectedLessonCourseId = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _dbCourses = courses;
        _dbChapters = activeChapters;
        _dbSubChaptersMap = activeSubChaptersMap;
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
      _isBrowsing = false;
    });
    widget.onBrowseModeChanged?.call();

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'current_lesson_course_id': course.id,
            },
          ),
        );
      }
    } catch (_) {}

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_lesson_course_id_${user.id}', course.id);
      }
    } catch (_) {}

    await loadDbLessons();
  }

  Future<void> _confirmRelearnLesson(LessonCourse course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Relearn Lesson?'),
        content: const Text(
          'Are you sure you want to relearn this lesson? Your progress will be reset but your XP will still be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Relearn',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingDb = true);
      try {
        final chapters = _allChaptersMap[course.id] ?? [];
        final List<String> subChapterIds = [];
        for (var ch in chapters) {
          final subs = _allSubChaptersMap[ch.id] ?? [];
          for (var sub in subs) {
            subChapterIds.add(sub.id);
          }
        }

        await _progressTracker.resetAll(subChapterIds);
        await loadDbLessons();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lesson "${course.title}" progress reset successfully!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting progress: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoadingDb = false);
        }
      }
    }
  }

  void _showCongratulationsDialog(LessonCourse course) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade700, Colors.indigo.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, size: 44, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              const Text(
                '🎉 Congratulations!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ve completed',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                course.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "You've covered it all. Ready to tackle the next challenge?",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmptyPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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

    final ongoing = _dbCourses.where((c) {
      final progress = _getCourseProgress(c, _allChaptersMap, _allSubChaptersMap);
      return _getCourseCategory(c, progress) == 1;
    }).toList();

    final unlearned = _dbCourses.where((c) {
      final progress = _getCourseProgress(c, _allChaptersMap, _allSubChaptersMap);
      return _getCourseCategory(c, progress) == 0;
    }).toList();

    final completed = _dbCourses.where((c) {
      final progress = _getCourseProgress(c, _allChaptersMap, _allSubChaptersMap);
      return _getCourseCategory(c, progress) == 2;
    }).toList();

    // Determine current displayed list
    List<LessonCourse> displayedCourses = [];
    if (_activeTab == 'All') {
      displayedCourses = _dbCourses;
    } else if (_activeTab == 'In Progress') {
      displayedCourses = ongoing;
    } else if (_activeTab == 'New') {
      displayedCourses = unlearned;
    } else if (_activeTab == 'Completed') {
      displayedCourses = completed;
    }

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayedCourses = displayedCourses.where((c) {
        return c.title.toLowerCase().contains(q) ||
            (c.description ?? '').toLowerCase().contains(q);
      }).toList();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row with title and optional X (back to lesson) button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Browse Lessons',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              if (_selectedLessonCourseId != null)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isBrowsing = false;
                    });
                    widget.onBrowseModeChanged?.call();
                  },
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Back to current lesson',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.black87,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 1. Search Bar (Fixed at top)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search lessons...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),

        // 2. Segmented Tab Selector Row (Fixed at top)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Row(
            children: [
              _buildTabPill('All', _dbCourses.length, isDark),
              const SizedBox(width: 8),
              _buildTabPill('In Progress', ongoing.length, isDark),
              const SizedBox(width: 8),
              _buildTabPill('New', unlearned.length, isDark),
              const SizedBox(width: 8),
              _buildTabPill('Completed', completed.length, isDark),
            ],
          ),
        ),

        // 3. Scrollable List/Content Area
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                if (displayedCourses.isEmpty)
                  _buildEmptyPlaceholder(
                    _searchQuery.isNotEmpty
                        ? 'No matching lessons found for "$_searchQuery".'
                        : 'No lessons available in this tab.',
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    itemCount: displayedCourses.length,
                    itemBuilder: (context, index) {
                      final course = displayedCourses[index];
                      final progress = _getCourseProgress(course, _allChaptersMap, _allSubChaptersMap);
                      final progressPct = (progress * 100).toInt();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () => _showCoursePreviewSheet(course),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: Colors.deepPurple.shade50,
                                  ),
                                  child: course.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.network(
                                            course.imageUrl!,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.school_rounded,
                                          color: Colors.deepPurple,
                                          size: 36,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              course.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (!course.isPublic)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6.0),
                                              child: Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (course.description != null &&
                                          course.description!.isNotEmpty) ...[
                                        Text(
                                          course.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: progress == 1.0
                                                  ? Colors.green.shade50
                                                  : (progress > 0
                                                      ? Colors.deepPurple.shade50
                                                      : Colors.grey.shade100),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              progress == 1.0
                                                  ? 'Completed'
                                                  : (progress > 0 ? 'Ongoing' : 'New'),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: progress == 1.0
                                                    ? Colors.green.shade700
                                                    : (progress > 0
                                                        ? Colors.deepPurple.shade700
                                                        : Colors.grey.shade700),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (progress > 0 && progress < 1.0) ...[
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  minHeight: 6,
                                                  backgroundColor: Colors.grey.shade100,
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$progressPct%',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                            ),
                                          ],
                                        ],
                                      ),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabPill(String title, int count, bool isDark) {
    final isSelected = _activeTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple
              : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurple
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showCoursePreviewSheet(LessonCourse course) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Get the cached future to avoid recreating it
    final discussionCountFuture = _getDiscussionCountFuture(course.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Swipe indicator handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Close button at top right
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
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
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    course.imageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.school_rounded,
                                  color: Colors.deepPurple,
                                  size: 56,
                                ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          course.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: course.isPublic
                                ? Colors.green.shade50
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: course.isPublic
                                  ? Colors.green.shade300
                                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            course.isPublic ? 'Public Lesson' : 'Private Lesson',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: course.isPublic
                                  ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (course.description != null &&
                            course.description!.isNotEmpty) ...[
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            course.description!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        ] else ...[
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            'No description provided for this lesson.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context); // Close sheet
                              _startLearningCourse(course); // Start course learning
                            },
                            child: const Text(
                              'Start Learning',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<int>(
                          future: discussionCountFuture,
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: Colors.deepPurple,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        LessonDiscussionsSheet(
                                      courseId: course.id,
                                      courseTitle: course.title,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.deepPurple,
                                  size: 20,
                                ),
                                label: Text(
                                  'View Discussion ($count)',
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
                              '/lesson-player?subChapterId=${sub.id}',
                            );
                            if (result == true) {
                              await loadDbLessons();
                              // Check if lesson is now fully completed
                              if (mounted && _selectedLessonCourseId != null) {
                                final courseIdx = _dbCourses.indexWhere((c) => c.id == _selectedLessonCourseId);
                                if (courseIdx != -1) {
                                  final completedCourse = _dbCourses[courseIdx];
                                  final courseProgress = _getCourseProgress(completedCourse, _allChaptersMap, _allSubChaptersMap);
                                  if (courseProgress >= 1.0) {
                                    _showCongratulationsDialog(completedCourse);
                                  }
                                }
                              }
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

    if (_isLoadingDb) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }

    if (isViewingActiveLesson && !_isBrowsing) {
      return RefreshIndicator(
        onRefresh: loadDbLessons,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          _isBrowsing = true;
                        });
                        widget.onBrowseModeChanged?.call();
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
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FutureBuilder<int>(
                  future: _getDiscussionCountFuture(activeCourse.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => LessonDiscussionsSheet(
                              courseId: activeCourse.id,
                              courseTitle: activeCourse.title,
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        label: Text(
                          'View Discussion ($count)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text(
                    'Relearn Lesson',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () => _confirmRelearnLesson(activeCourse),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadDbLessons,
      child: _buildDiscoveryView(),
    );
  }
}
