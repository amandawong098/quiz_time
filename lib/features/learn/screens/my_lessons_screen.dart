import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../core/services/ai_generation_manager.dart';
import '../../../core/services/ai_quiz_service.dart';
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
    AIGenerationManager().addListener(_onAIManagerStateChanged);
  }

  @override
  void dispose() {
    AIGenerationManager().removeListener(_onAIManagerStateChanged);
    super.dispose();
  }

  void _onAIManagerStateChanged() {
    if (mounted) {
      final task = AIGenerationManager().currentTask;
      if (task?.taskType == AITaskType.lesson &&
          task?.status == AITaskStatus.completed) {
        _loadLessons();
      }
      setState(() {});
    }
  }

  Future<void> _loadLessons() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();
      final allCourses = await repo.getCourses();
      final currentUser = Supabase.instance.client.auth.currentUser;
      final courses = allCourses.where((c) => c.creatorId == currentUser?.id).toList();
      
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

  Future<void> _showAddChapterWithAISheet(LessonCourse course) async {
    final existingChapters = _chaptersMap[course.id] ?? [];
    final existingTitles = existingChapters.map((c) => c.title).toList();

    final promptController = TextEditingController();
    String selectedAudience = 'All Audiences';
    PlatformFile? selectedFile;
    bool isPickingFile = false;

    final key = await AIQuizService.getApiKey();
    if (!mounted) return;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please configure your Gemini API Key first in AI Lesson Generator settings.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => context.push('/ai-lesson-generator'),
          ),
        ),
      );
      return;
    }

    final selectedModel = await AIQuizService.getSelectedModel();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F24) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.deepPurple,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Chapter with AI',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'To: ${course.title}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Recommendation guidance banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recommendation: Generating 1 chapter at a time provides the deepest explanations, figures, and interactive checkpoints.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Existing Chapters Context Chips
                    if (existingTitles.isNotEmpty) ...[
                      Text(
                        'Existing Chapters (${existingTitles.length}):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: existingTitles.map((t) {
                          return Chip(
                            label: Text(
                              t,
                              style: const TextStyle(fontSize: 11),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Topic / Prompt Input
                    TextField(
                      controller: promptController,
                      maxLines: 3,
                      minLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Chapter Topic or Instructions',
                        hintText: 'e.g. Proof of Stake vs Proof of Work, Byzantine Fault Tolerance...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Optional Study Material Attachment
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isPickingFile
                              ? null
                              : () async {
                                  setSheetState(() => isPickingFile = true);
                                  try {
                                    final result =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.any,
                                      withData: true,
                                    );
                                    if (result != null &&
                                        result.files.isNotEmpty) {
                                      final f = result.files.first;
                                      Uint8List? bytes = f.bytes;
                                      if (bytes == null && f.path != null) {
                                        bytes =
                                            await File(f.path!).readAsBytes();
                                      }
                                      setSheetState(() {
                                        selectedFile = PlatformFile(
                                          name: f.name,
                                          size: f.size,
                                          bytes: bytes,
                                          path: f.path,
                                        );
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint('Error picking file: $e');
                                  } finally {
                                    setSheetState(() => isPickingFile = false);
                                  }
                                },
                          icon: isPickingFile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.attach_file, size: 18),
                          label: Text(
                            selectedFile != null
                                ? 'Change File'
                                : 'Attach Notes/Slides (Optional)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (selectedFile != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Chip(
                              label: Text(
                                selectedFile!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onDeleted: () {
                                setSheetState(() => selectedFile = null);
                              },
                              deleteIconColor: Colors.redAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Audience Selector
                    Row(
                      children: [
                        const Text(
                          'Audience: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedAudience,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'All Audiences',
                                child: Text('All Audiences'),
                              ),
                              DropdownMenuItem(
                                value: 'Beginner',
                                child: Text('Beginner'),
                              ),
                              DropdownMenuItem(
                                value: 'Intermediate',
                                child: Text('Intermediate'),
                              ),
                              DropdownMenuItem(
                                value: 'Advanced',
                                child: Text('Advanced'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => selectedAudience = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Generate Button
                    ElevatedButton.icon(
                      onPressed: () {
                        final prompt = promptController.text.trim();
                        if (prompt.isEmpty && selectedFile == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a chapter topic or attach notes/slides.',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(sheetContext);

                        AIGenerationManager().startAddChapterGeneration(
                          context: context,
                          courseId: course.id,
                          courseTitle: course.title,
                          existingChapterTitles: existingTitles,
                          prompt: prompt,
                          fileBytes: selectedFile?.bytes,
                          fileName: selectedFile?.name,
                          audience: selectedAudience,
                          modelName: selectedModel,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'AI is generating a new chapter for "${course.title}" in the background! It will appear here once complete.',
                            ),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome, color: Colors.white),
                      label: const Text(
                        'Generate Chapter with AI',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // AI mistake disclaimer
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'AI can make mistakes. Please verify important educational information.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  List<String> _getWarnings() {
    final List<String> warnings = [];
    for (var course in _courses) {
      final chapters = _chaptersMap[course.id] ?? [];
      for (var ch in chapters) {
        final subs = _subChaptersMap[ch.id] ?? [];
        if (subs.length > 6) {
          warnings.add(
            "Chapter '${ch.title}' contains more than 6 sub-chapters (${subs.length} sub-chapters). We recommend keeping chapters short.",
          );
        }
        for (var sub in subs) {
          final slidesCount = _subChapterSlidesCountMap[sub.id] ?? 0;
          if (slidesCount > 7) {
            warnings.add(
              "Sub-chapter '${sub.title}' contains more than 7 slide pages ($slidesCount pages). We recommend keeping sub-chapters short to make learning bite-sized.",
            );
          }
        }
      }
    }
    return warnings;
  }

  Widget _buildWarningBanner(String message) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(bottom: BorderSide(color: Colors.amber.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
    final warnings = _getWarnings();
    return Column(
      children: [
        if (warnings.isNotEmpty)
          ...warnings.map((w) => _buildWarningBanner(w)),
        Expanded(
          child: RefreshIndicator(
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
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'add_chapter_ai') {
                      _showAddChapterWithAISheet(course);
                    } else if (val == 'add_chapter') {
                      _addChapter(course);
                    } else if (val == 'edit') {
                      _editCourse(course);
                    } else if (val == 'delete') {
                      _deleteCourse(course);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_chapter_ai',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 20),
                          SizedBox(width: 8),
                          Text('Add Chapter with AI', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_chapter',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Add Blank Chapter'),
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
                            'No chapters added yet.\nChoose how you want to add your first chapter:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _addChapter(course),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add Blank'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  side: BorderSide(color: Colors.deepPurple.shade200),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showAddChapterWithAISheet(course),
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                label: const Text('Add with AI'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
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
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.green),
                                                  onPressed: () {
                                                    context.push('/lesson-player?subChapterId=${sub.id}&preview=true');
                                                  },
                                                  tooltip: 'Play Sub-chapter',
                                                ),
                                                PopupMenuButton<String>(
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addChapter(course),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Blank Chapter'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.deepPurple,
                                side: BorderSide(color: Colors.deepPurple.shade200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddChapterWithAISheet(course),
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Add with AI'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lessons'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: FilledButton.tonalIcon(
              onPressed: () {
                context.push('/ai-lesson-generator');
              },
              icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
              label: const Text(
                'AI Generator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade50,
                foregroundColor: Colors.deepPurple.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Background AI Lesson Generation Status Banner
          Builder(
            builder: (context) {
              final aiTask = AIGenerationManager().currentTask;
              if (aiTask == null ||
                  aiTask.taskType != AITaskType.lesson ||
                  aiTask.status != AITaskStatus.generating) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Card(
                  color: Colors.deepPurple.shade50,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.deepPurple.shade200),
                  ),
                  child: ListTile(
                    leading: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    title: Text(
                      'AI Generating: ${aiTask.prompt.isNotEmpty ? aiTask.prompt : (aiTask.fileName ?? "Lesson")}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.deepPurple,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      aiTask.statusMessage,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        context.push('/ai-lesson-generator');
                      },
                      child: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _courses.isEmpty
                    ? _buildNoCoursesView()
                    : _buildCoursesListView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: _addCourse,
        child: const Icon(Icons.add),
      ),
    );
  }
}
