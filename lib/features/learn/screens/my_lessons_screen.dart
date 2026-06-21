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

      if (!mounted) return;
      setState(() {
        _courses = courses;
        _chaptersMap = chaptersMap;
        _subChaptersMap = subChaptersMap;
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
    final title = await _showNameDialog(
      title: 'Create New Lesson',
      labelText: 'Lesson Title',
      hintText: 'e.g. Mathematics',
    );

    if (!mounted) return;
    if (title != null && title.isNotEmpty) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.createCourse(title);
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating lesson: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editCourse(LessonCourse course) async {
    final title = await _showNameDialog(
      title: 'Edit Lesson Title',
      labelText: 'Lesson Title',
      initialValue: course.title,
    );

    if (!mounted) return;
    if (title != null && title.isNotEmpty) {
      try {
        final repo = context.read<LessonRepository>();
        await repo.updateCourse(course.id, title);
        _loadLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating lesson: ${e.toString()}')),
          );
        }
      }
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

  Widget _buildNoCoursesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
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
                leading: const Icon(
                  Icons.school,
                  color: Colors.deepPurple,
                  size: 28,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          Text('Edit Lesson Title'),
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
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No chapters. Add one from lesson options.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ...chapters.map((ch) {
                      final subs = _subChaptersMap[ch.id] ?? [];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.shade50),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: Icon(
                            Icons.play_circle_fill,
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
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  'No sub-chapters. Add one from chapter options.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              ...subs.map((sub) {
                                return ListTile(
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
                                    'XP Reward: ${sub.xpReward}',
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
                                  onTap: () {
                                    context.push(
                                      '/my-lessons/sub-chapter/${sub.id}/slides',
                                      extra: {'subChapterTitle': sub.title},
                                    );
                                  },
                                );
                              }),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: _addCourse,
        icon: const Icon(Icons.add),
        label: const Text('New Lesson'),
      ),
    );
  }
}
