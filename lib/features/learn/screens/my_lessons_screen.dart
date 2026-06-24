import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../models/lesson_models.dart';

class MyLessonsScreen extends StatefulWidget {
  const MyLessonsScreen({super.key});

  @override
  State<MyLessonsScreen> createState() => _MyLessonsScreenState();
}

class _MyLessonsScreenState extends State<MyLessonsScreen> {
  bool _isLoading = true;
  List<LessonCourse> _courses = [];
  Map<String, List<LessonChapter>> _chaptersMap = {};
  Map<String, List<LessonSubChapter>> _subChaptersMap = {};
  Map<String, int> _subChapterSlidesCountMap = {};

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();
      final courses = await repo.getCourses();
      
      final Map<String, List<LessonChapter>> chaptersMap = {};
      final Map<String, List<LessonSubChapter>> subChaptersMap = {};
      final Map<String, int> subChapterSlidesCountMap = {};

      for (var course in courses) {
        if (!mounted) return;
        final chapters = await repo.getChapters(course.id);
        chaptersMap[course.id] = chapters;
        
        for (var ch in chapters) {
          if (!mounted) return;
          final subs = await repo.getSubChapters(ch.id);
          subChaptersMap[ch.id] = subs;

          for (var sub in subs) {
            if (!mounted) return;
            final pages = await repo.getPages(sub.id);
            subChapterSlidesCountMap[sub.id] = pages.length;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _courses = courses;
        _chaptersMap = chaptersMap;
        _subChaptersMap = subChaptersMap;
        _subChapterSlidesCountMap = subChapterSlidesCountMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading lessons: ${e.toString()}')),
      );
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    required String labelText,
    String? initialValue,
    String hintText = '',
  }) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText.isNotEmpty ? hintText : null,
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name cannot be empty';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCourse() async {
    final result = await context.push('/create-lesson');
    if (result == true) {
      _loadLessons();
    }
  }

  Future<void> _editCourse(LessonCourse course) async {
    final result = await context.push(
      '/create-lesson',
      extra: {'lesson': course},
    );
    if (result == true) {
      _loadLessons();
    }
  }

  Future<void> _deleteCourse(LessonCourse course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson?'),
        content: Text(
          'Are you sure you want to delete "${course.title}"? All of its chapters, sub-chapters and slides will be deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.deleteCourse(course.id);
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting lesson: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _addChapter(LessonCourse course) async {
    final title = await _showNameDialog(
      title: 'Add Chapter in "${course.title}"',
      labelText: 'Chapter Title',
      hintText: 'e.g. Multiplication',
    );

    if (!mounted) return;
    if (title != null && title.isNotEmpty) {
      try {
        final repo = context.read<LessonRepository>();
        final existingChapters = _chaptersMap[course.id] ?? [];
        await repo.createChapter(
          title: title,
          position: existingChapters.length,
          courseId: course.id,
        );
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating chapter: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editChapter(String courseId, LessonChapter ch) async {
    final title = await _showNameDialog(
      title: 'Edit Chapter',
      labelText: 'Chapter Title',
      initialValue: ch.title,
    );

    if (!mounted) return;
    if (title != null && title.isNotEmpty) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.updateChapter(ch.id, title, ch.position, courseId);
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error editing chapter: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteChapter(LessonChapter ch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter?'),
        content: Text(
          'Are you sure you want to delete "${ch.title}"? All of its sub-chapters and slides will be deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.deleteChapter(ch.id);
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting chapter: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _addSubChapter(LessonChapter ch) async {
    final title = await _showNameDialog(
      title: 'Add Sub-chapter in "${ch.title}"',
      labelText: 'Sub-chapter Title',
      hintText: 'e.g. Multiplying 2-Digit Numbers',
    );

    if (!mounted) return;
    if (title != null && title.isNotEmpty) {
      try {
        final repo = context.read<LessonRepository>();
        final existingCount = _subChaptersMap[ch.id]?.length ?? 0;
        await repo.createSubChapter(
          chapterId: ch.id,
          title: title,
          position: existingCount,
        );
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating sub-chapter: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editSubChapter(LessonSubChapter sub) async {
    final title = await _showNameDialog(
      title: 'Edit Sub-chapter',
      labelText: 'Sub-chapter Title',
      initialValue: sub.title,
    );

    if (!mounted) return;
    if (title != null && title.isNotEmpty) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.updateSubChapter(
          id: sub.id,
          title: title,
          position: sub.position,
          xpReward: sub.xpReward,
        );
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating sub-chapter: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deleteSubChapter(LessonSubChapter sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sub-chapter?'),
        content: Text(
          'Are you sure you want to delete "${sub.title}"? All of its pages/slides will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.deleteSubChapter(sub.id);
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting sub-chapter: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _moveChapter(LessonCourse course, int index, bool moveUp) async {
    final chapters = _chaptersMap[course.id] ?? [];
    if (moveUp && index == 0) return;
    if (!moveUp && index == chapters.length - 1) return;

    final targetIndex = moveUp ? index - 1 : index + 1;
    final ch1 = chapters[index];
    final ch2 = chapters[targetIndex];

    int pos1 = ch2.position;
    int pos2 = ch1.position;
    if (pos1 == pos2) {
      pos1 = targetIndex;
      pos2 = index;
    }

    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();
      await repo.updateChapter(ch1.id, ch1.title, pos1, course.id);
      await repo.updateChapter(ch2.id, ch2.title, pos2, course.id);
      await _loadLessons();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving chapter: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _moveSubChapter(LessonChapter ch, int index, bool moveUp) async {
    final subs = _subChaptersMap[ch.id] ?? [];
    if (moveUp && index == 0) return;
    if (!moveUp && index == subs.length - 1) return;

    final targetIndex = moveUp ? index - 1 : index + 1;
    final sub1 = subs[index];
    final sub2 = subs[targetIndex];

    int pos1 = sub2.position;
    int pos2 = sub1.position;
    if (pos1 == pos2) {
      pos1 = targetIndex;
      pos2 = index;
    }

    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();
      await repo.updateSubChapter(
        id: sub1.id,
        title: sub1.title,
        position: pos1,
        xpReward: sub1.xpReward,
      );
      await repo.updateSubChapter(
        id: sub2.id,
        title: sub2.title,
        position: pos2,
        xpReward: sub2.xpReward,
      );
      await _loadLessons();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving sub-chapter: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildNoCoursesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No lessons created yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a lesson to start structuring your learning materials.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _addCourse,
            icon: const Icon(Icons.add),
            label: const Text('Create New Lesson'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesListView() {
    return RefreshIndicator(
      onRefresh: _loadLessons,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _courses.length,
        itemBuilder: (context, courseIdx) {
          final course = _courses[courseIdx];
          final chapters = _chaptersMap[course.id] ?? [];

          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.deepPurple.shade50,
                  ),
                  child: course.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            course.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: course.isPublic ? Colors.green.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: course.isPublic ? Colors.green.shade300 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  course.isPublic ? 'Public' : 'Private',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: course.isPublic ? Colors.green.shade700 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (course.description != null && course.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              course.description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => context.push('/learn/lesson-player?courseId=${course.id}'),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'add_chapter') {
                      _addChapter(course);
                    } else if (val == 'edit') {
                      _editCourse(course);
                    } else if (val == 'delete') {
                      _deleteCourse(course);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_chapter',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Add Chapter'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Lesson'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Lesson', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                children: [
                  const Divider(height: 1),
                  if (chapters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No chapters added yet.\nClick the button below to add your first chapter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          IconButton(
                            onPressed: () => _addChapter(course),
                            icon: const Icon(Icons.add, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(chapters.length, (chIdx) {
                      final ch = chapters[chIdx];
                      final subs = _subChaptersMap[ch.id] ?? [];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.shade50),
                        ),
                        child: Column(
                          children: [
                            ExpansionTile(
                              initiallyExpanded: true,
                              leading: Icon(
                                Icons.book_rounded,
                                color: Colors.deepPurple.shade700,
                                size: 24,
                              ),
                              title: Text(
                                ch.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'add_sub') {
                                    _addSubChapter(ch);
                                  } else if (val == 'edit') {
                                    _editChapter(course.id, ch);
                                  } else if (val == 'delete') {
                                    _deleteChapter(ch);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'add_sub',
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_circle_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text('Add Sub-chapter'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit Chapter Title'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red, size: 18),
                                        SizedBox(width: 8),
                                        Text('Delete Chapter', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                const Divider(height: 1),
                                if (subs.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'No sub-chapters added yet.\nClick the button below to add your first sub-chapter.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        IconButton(
                                          onPressed: () => _addSubChapter(ch),
                                          icon: const Icon(Icons.add, color: Colors.white),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.deepPurple,
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...List.generate(subs.length, (subIdx) {
                                    final sub = subs[subIdx];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(color: Colors.deepPurple.shade100.withValues(alpha: 0.5)),
                                      ),
                                      color: Colors.white,
                                      child: Column(
                                        children: [
                                          ListTile(
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 2,
                                            ),
                                            leading: const Icon(
                                              Icons.description_outlined,
                                              color: Colors.deepPurple,
                                              size: 20,
                                            ),
                                            title: Text(
                                              sub.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'XP Reward: ${sub.xpReward} • ${_subChapterSlidesCountMap[sub.id] ?? 0} slides',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            trailing: PopupMenuButton<String>(
                                              onSelected: (val) {
                                                if (val == 'edit') {
                                                  _editSubChapter(sub);
                                                } else if (val == 'delete') {
                                                  _deleteSubChapter(sub);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit, size: 20),
                                                      SizedBox(width: 8),
                                                      Text('Edit Title'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete, color: Colors.red, size: 20),
                                                      SizedBox(width: 8),
                                                      Text('Delete Sub-chapter', style: TextStyle(color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            onTap: () async {
                                              await context.push(
                                                '/my-lessons/sub-chapter/${sub.id}/slides',
                                                extra: {'subChapterTitle': sub.title},
                                              );
                                              _loadLessons();
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12.0, bottom: 8.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: subIdx == 0 ? null : () => _moveSubChapter(ch, subIdx, true),
                                                  tooltip: 'Move Sub-chapter Up',
                                                ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: subIdx == subs.length - 1 ? null : () => _moveSubChapter(ch, subIdx, false),
                                                  tooltip: 'Move Sub-chapter Down',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 16.0, bottom: 8.0, top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                                    onPressed: chIdx == 0 ? null : () => _moveChapter(course, chIdx, true),
                                    tooltip: 'Move Chapter Up',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                    onPressed: chIdx == chapters.length - 1 ? null : () => _moveChapter(course, chIdx, false),
                                    tooltip: 'Move Chapter Down',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lessons'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? _buildNoCoursesView()
              : _buildCoursesListView(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: _addCourse,
        child: const Icon(Icons.add),
      ),
    );
  }
}
