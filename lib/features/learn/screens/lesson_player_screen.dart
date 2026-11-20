import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/models/discussion_models.dart';
import '../models/lesson_models.dart';
import '../models/lesson_progress.dart';
import '../../gamification/gamification_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/widgets/byte_mascot.dart';
import '../../../core/widgets/video_preview_widget.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String? subChapterId;
  final String? courseId;
  final bool isPreview;
  final String? initialPageId;

  const LessonPlayerScreen({
    super.key,
    this.subChapterId,
    this.courseId,
    this.isPreview = false,
    this.initialPageId,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class SlideQuestionState {
  int? selectedIndex; // for radio
  final Set<int> selectedIndices = {}; // for checkbox
  bool checked = false;
  bool? isCorrect;
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late PageController _pageController;
  int _currentSlide = 0;
  final LessonProgress _progressTracker = LessonProgress();

  // Dynamic lesson database state
  bool _isLoading = false;
  List<LessonPage> _dynamicPages = [];
  Map<String, List<LessonBlock>> _dynamicPageBlocks = {};
  final Map<String, String> _pageSubChapterMap = {};
  final Map<String, SlideQuestionState> _questionStates = {};
  Map<String, int> _pageDiscussionCounts = {};
  bool _canViewDiscussion = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadDynamicLesson();
    final isAdmin = context.read<AuthRepository>().isAdmin;
    if (widget.isPreview && !isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Preview Mode'),
            content: const Text(
              'This is a preview only. Progress will not be saved and no XP points will be rewarded.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicLesson() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<LessonRepository>();
      final List<LessonPage> pages = [];
      final Map<String, List<LessonBlock>> pageBlocks = {};

      if (widget.courseId != null) {
        final chapters = await repo.getChapters(widget.courseId!);
        for (var ch in chapters) {
          final subs = await repo.getSubChapters(ch.id);
          for (var sub in subs) {
            final subPages = await repo.getPagesWithBlocks(sub.id);
            for (var page in subPages) {
              pages.add(page);
              _pageSubChapterMap[page.id] = sub.id;
              pageBlocks[page.id] = page.blocks ?? [];
            }
          }
        }
      } else if (widget.subChapterId != null) {
        final subPages = await repo.getPagesWithBlocks(widget.subChapterId!);
        for (var page in subPages) {
          pages.add(page);
          _pageSubChapterMap[page.id] = widget.subChapterId!;
          pageBlocks[page.id] = page.blocks ?? [];
        }
      }

      int initialPage = 0;
      if (widget.initialPageId != null) {
        final matchIdx = pages.indexWhere((p) => p.id == widget.initialPageId);
        if (matchIdx != -1) {
          initialPage = matchIdx;
        }
      }

      Map<String, int> counts = {};
      try {
        final discRepo = context.read<DiscussionRepository>();
        if (widget.subChapterId != null) {
          counts = await discRepo.getPageDiscussionsCount(widget.subChapterId!);
        } else if (widget.courseId != null) {
          final chapters = await repo.getChapters(widget.courseId!);
          for (var ch in chapters) {
            final subs = await repo.getSubChapters(ch.id);
            for (var sub in subs) {
              final subCounts = await discRepo.getPageDiscussionsCount(sub.id);
              counts.addAll(subCounts);
            }
          }
        }
      } catch (_) {}

      bool canView = false;
      try {
        final client = Supabase.instance.client;
        String? targetCourseId = widget.courseId;
        if (targetCourseId == null && widget.subChapterId != null) {
          final subRes = await client
              .from('lesson_sub_chapters')
              .select('chapter_id')
              .eq('id', widget.subChapterId!)
              .maybeSingle();
          final chapId = subRes?['chapter_id'] as String?;
          if (chapId != null) {
            final chapRes = await client
                .from('lesson_chapters')
                .select('course_id')
                .eq('id', chapId)
                .maybeSingle();
            targetCourseId = chapRes?['course_id'] as String?;
          }
        }
        if (targetCourseId == null && pages.isNotEmpty) {
          final meta = await repo.getPageMetadata(pages.first.id);
          final subData = meta?['lesson_sub_chapters'] as Map<String, dynamic>?;
          final chapData = subData?['lesson_chapters'] as Map<String, dynamic>?;
          targetCourseId = chapData?['course_id'] as String?;
        }
        if (targetCourseId != null) {
          final courseRes = await client
              .from('lesson_courses')
              .select('is_public')
              .eq('id', targetCourseId)
              .maybeSingle();
          final isPublic = courseRes?['is_public'] as bool? ?? false;
          canView = isPublic;
        }
      } catch (e) {
        debugPrint('Error checking discussion permission in player: $e');
      }

      setState(() {
        _dynamicPages = pages;
        _dynamicPageBlocks = pageBlocks;
        _pageDiscussionCounts = counts;
        _canViewDiscussion = canView;
        _currentSlide = initialPage;
        _isLoading = false;
      });

      if (initialPage > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(initialPage);
          }
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lesson: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadDiscussionCounts() async {
    try {
      final discRepo = context.read<DiscussionRepository>();
      final repo = context.read<LessonRepository>();
      final Map<String, int> allCounts = {};
      if (widget.subChapterId != null) {
        final subCounts = await discRepo.getPageDiscussionsCount(
          widget.subChapterId!,
        );
        allCounts.addAll(subCounts);
      } else if (widget.courseId != null) {
        final chapters = await repo.getChapters(widget.courseId!);
        for (var ch in chapters) {
          final subs = await repo.getSubChapters(ch.id);
          for (var sub in subs) {
            final subCounts = await discRepo.getPageDiscussionsCount(sub.id);
            allCounts.addAll(subCounts);
          }
        }
      }
      setState(() {
        _pageDiscussionCounts = allCounts;
      });
    } catch (_) {}
  }

  void _openDiscussionsForCurrentPage() {
    if (_dynamicPages.isEmpty || _currentSlide >= _dynamicPages.length) return;
    final page = _dynamicPages[_currentSlide];
    final subChapterId = _pageSubChapterMap[page.id] ?? widget.subChapterId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PageDiscussionsSheet(
          pageId: page.id,
          subChapterId: subChapterId,
          courseId: widget.courseId,
          onTopicCreated: () {
            _loadDiscussionCounts();
          },
        );
      },
    );
  }

  void _handleBackPress() {
    if (mounted) {
      context.pop();
    }
  }

  void _showPageJumpSheet(int totalSlides) {
    SoundService.instance.playOptionSelect();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.65,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Jump to Page',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '$totalSlides Pages',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: totalSlides,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final isCurrent = index == _currentSlide;
                    final page = _dynamicPages[index];
                    final blocks = _dynamicPageBlocks[page.id] ?? [];
                    String pageTitle = 'Page ${index + 1}';
                    for (final b in blocks) {
                      final candidate =
                          (b.content['text'] ??
                                  b.content['question'] ??
                                  b.content['file_name'] ??
                                  '')
                              .toString()
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim();
                      if (candidate.isNotEmpty) {
                        pageTitle = candidate;
                        break;
                      }
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (_pageController.hasClients) {
                          _pageController.jumpToPage(index);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.deepPurple.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? Colors.deepPurple
                                : Colors.grey.shade200,
                            width: isCurrent ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Colors.deepPurple
                                    : Colors.deepPurple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isCurrent
                                      ? Colors.white
                                      : Colors.deepPurple.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pageTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 14,
                                  color: isCurrent
                                      ? Colors.deepPurple.shade900
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              const Icon(
                                Icons.my_location_rounded,
                                size: 18,
                                color: Colors.deepPurple,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleContinue(int totalSlides) {
    if (_currentSlide < totalSlides - 1) {
      if (widget.courseId != null) {
        final currentPageObj = _dynamicPages[_currentSlide];
        final currentSubChapterId = _pageSubChapterMap[currentPageObj.id];

        final nextPageObj = _dynamicPages[_currentSlide + 1];
        final nextSubChapterId = _pageSubChapterMap[nextPageObj.id];

        if (currentSubChapterId != null &&
            currentSubChapterId != nextSubChapterId &&
            !widget.isPreview) {
          _progressTracker.complete(currentSubChapterId);
        }
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeLesson();
    }
  }

  Future<void> _saveCompletionState() async {
    final isAdmin = context.read<AuthRepository>().isAdmin;
    if (!widget.isPreview && !isAdmin) {
      if (widget.subChapterId != null) {
        await _progressTracker.complete(widget.subChapterId!);
      } else if (widget.courseId != null && _dynamicPages.isNotEmpty) {
        final currentPageObj = _dynamicPages[_currentSlide];
        final currentSubChapterId = _pageSubChapterMap[currentPageObj.id];
        if (currentSubChapterId != null) {
          await _progressTracker.complete(currentSubChapterId);
        }
      }
    }
  }

  void _completeLesson() {
    String? targetSubChapterId = widget.subChapterId;
    if (targetSubChapterId == null &&
        widget.courseId != null &&
        _dynamicPages.isNotEmpty) {
      final currentPageObj = _dynamicPages[_currentSlide];
      targetSubChapterId = _pageSubChapterMap[currentPageObj.id];
    }
    final bool wasAlreadyCompleted =
        targetSubChapterId != null &&
        _progressTracker.isCompleted(targetSubChapterId);

    final completionFuture = _saveCompletionState();

    final isAdmin = context.read<AuthRepository>().isAdmin;
    if (isAdmin) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Lesson Finished'),
          content: const Text(
            'You have completed reviewing this lesson sub-chapter.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop(true);
              },
              child: const Text('Back to Lessons'),
            ),
          ],
        ),
      );
      return;
    }

    if (widget.isPreview) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Preview Complete'),
          content: const Text(
            'You have successfully previewed this lesson sub-chapter!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Dismiss dialog
                context.pop(true); // Return back to lessons
              },
              child: const Text('Back to Lessons'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 32.0,
                  horizontal: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: wasAlreadyCompleted
                            ? Colors.orange.shade100
                            : Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        wasAlreadyCompleted
                            ? Icons.auto_stories_rounded
                            : Icons.emoji_events,
                        color: wasAlreadyCompleted
                            ? Colors.orange.shade800
                            : Colors.amber,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      wasAlreadyCompleted
                          ? 'Oops! No XP for you...'
                          : 'Lesson Complete!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      wasAlreadyCompleted
                          ? '+0 XP (Already Learnt)'
                          : 'XP +10 Earned',
                      style: TextStyle(
                        fontSize: 16,
                        color: wasAlreadyCompleted
                            ? Colors.orange.shade800
                            : Colors.deepPurple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      wasAlreadyCompleted
                          ? 'You\'ve already learnt this sub-chapter previously! Re-reading completed lessons is great for revision, but XP is only rewarded when completing it for the first time or after resetting your lesson progress.'
                          : 'You have successfully completed this lesson. You can now proceed to the next lesson sub-chapter!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setDialogState(() => isSaving = true);
                                try {
                                  await completionFuture;
                                  await GamificationService.instance
                                      .recordStudyCompletion();
                                } catch (_) {}
                                if (context.mounted) {
                                  Navigator.pop(context); // Dismiss dialog
                                  context.pop(true); // Return back to lessons
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Back to Lessons',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
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

  // ------------------------------------------
  // DYNAMIC SIDES RENDERING
  // ------------------------------------------
  Widget _buildDynamicPage(
    LessonPage page,
    List<LessonBlock> blocks,
    int pageIndex,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...blocks.map((block) {
            if (block.blockType == 'text') {
              final textContent = block.content['text'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: MarkdownRenderer(text: textContent),
              );
            } else if (block.blockType == 'media') {
              final url = block.content['url'] as String? ?? '';
              final type = block.content['type'] as String? ?? 'image';
              final caption = block.content['caption'] as String? ?? '';

              if (url.isEmpty) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: type == 'video'
                          ? VideoPreviewWidget(
                              videoUrl: url,
                              title: caption.isNotEmpty
                                  ? caption
                                  : 'Embedded Video',
                            )
                          : Container(
                              color: Colors.white,
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 120,
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey.shade400,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            } else if (block.blockType == 'file') {
              final url = block.content['url'] as String? ?? '';
              final name = block.content['name'] as String? ?? 'Attachment';
              final size = block.content['size'] as String? ?? '';

              if (url.isEmpty) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (size.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  size,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else if (block.blockType == 'test') {
              return _buildDynamicTestBlock(block, pageIndex);
            }
            return const SizedBox();
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDynamicTestBlock(LessonBlock block, int pageIndex) {
    final question = block.content['question'] as String? ?? '';
    final isMultipleChoice =
        block.content['is_multiple_choice'] as bool? ?? false;
    final List<dynamic> options =
        block.content['options'] as List<dynamic>? ?? [];

    final state = _questionStates.putIfAbsent(
      block.id,
      () => SlideQuestionState(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question.isNotEmpty) ...[
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Check banner ABOVE the options
        if (state.checked) ...[
          _buildCheckStatusBanner(state.isCorrect ?? false),
          const SizedBox(height: 8),
        ],
        Column(
          children: List.generate(options.length, (optIdx) {
            final opt = options[optIdx] as Map;
            final optionText = opt['text'] as String? ?? '';
            final isCorrectOption = opt['is_correct'] as bool? ?? false;

            final isSelected = isMultipleChoice
                ? state.selectedIndices.contains(optIdx)
                : state.selectedIndex == optIdx;

            Color? cardColor;
            BorderSide borderSide = BorderSide(color: Colors.grey.shade300);

            if (state.checked) {
              // Directly reveal the correct option in green, and highlight any wrong chosen option in red
              if (isCorrectOption) {
                cardColor = Colors.green.shade200;
                borderSide = BorderSide(color: Colors.green.shade400, width: 2);
              } else if (isSelected) {
                cardColor = Colors.red.shade200;
                borderSide = BorderSide(color: Colors.red.shade400, width: 2);
              }
            } else if (isSelected) {
              borderSide = const BorderSide(color: Colors.deepPurple, width: 2);
            }

            return Card(
              color: cardColor,
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: borderSide,
              ),
              child: isMultipleChoice
                  ? CheckboxListTile(
                      title: Text(
                        optionText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: isSelected,
                      activeColor: Colors.deepPurple,
                      onChanged: state.checked
                          ? null
                          : (val) {
                              SoundService.instance.playOptionSelect();
                              setState(() {
                                if (val == true) {
                                  state.selectedIndices.add(optIdx);
                                } else {
                                  state.selectedIndices.remove(optIdx);
                                }
                              });
                            },
                    )
                  : RadioListTile<int>(
                      title: Text(
                        optionText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: optIdx,
                      groupValue: state.selectedIndex,
                      activeColor: Colors.deepPurple,
                      onChanged: state.checked
                          ? null
                          : (val) {
                              if (isCorrectOption) {
                                SoundService.instance.playCorrectAnswer();
                              } else {
                                SoundService.instance.playWrongAnswer();
                              }
                              setState(() {
                                state.selectedIndex = val;
                                // Auto-check for single choice
                                state.checked = true;
                                state.isCorrect = isCorrectOption;
                              });
                            },
                    ),
            );
          }),
        ),
        // Directly reveal explanation if present (for both correct and wrong answers)
        if (state.checked &&
            block.content['explanation'] != null &&
            (block.content['explanation'] as String).trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Explanation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  block.content['explanation'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDynamicFooter(
    int pageIndex,
    List<LessonBlock> blocks,
    int totalSlides,
  ) {
    // Find all test blocks on this page
    final testBlocks = blocks.where((b) => b.blockType == 'test').toList();
    if (testBlocks.isEmpty) {
      return _buildContinueButton(() {
        _handleContinue(totalSlides);
      });
    }

    // Ensure state exists for each test block
    for (var b in testBlocks) {
      _questionStates.putIfAbsent(b.id, () => SlideQuestionState());
    }

    // Find unchecked checkbox tests (optional self-check; Continue is always enabled!)
    final uncheckedCheckboxes = testBlocks
        .where(
          (b) =>
              (b.content['is_multiple_choice'] as bool? ?? false) &&
              _questionStates[b.id]?.checked != true,
        )
        .toList();

    final canSubmit =
        uncheckedCheckboxes.isNotEmpty &&
        uncheckedCheckboxes.every(
          (b) => (_questionStates[b.id]?.selectedIndices.isNotEmpty) == true,
        );

    if (canSubmit) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 16.0,
            bottom: 56.0,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(
                      color: Colors.deepPurple,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    bool allSubmittedCorrect = true;
                    setState(() {
                      for (var b in uncheckedCheckboxes) {
                        final state = _questionStates[b.id]!;
                        state.checked = true;
                        final options =
                            b.content['options'] as List<dynamic>? ?? [];
                        final correctIndices = <int>{};
                        for (int k = 0; k < options.length; k++) {
                          if ((options[k] as Map)['is_correct'] == true) {
                            correctIndices.add(k);
                          }
                        }
                        state.isCorrect =
                            state.selectedIndices.length ==
                                correctIndices.length &&
                            state.selectedIndices.every(
                              (i) => correctIndices.contains(i),
                            );
                        if (state.isCorrect != true) {
                          allSubmittedCorrect = false;
                        }
                      }
                    });
                    if (allSubmittedCorrect) {
                      SoundService.instance.playCorrectAnswer();
                    } else {
                      SoundService.instance.playWrongAnswer();
                    }
                  },
                  child: const Text(
                    'Submit',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _handleContinue(totalSlides),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildContinueButton(() {
      _handleContinue(totalSlides);
    });
  }

  Widget _buildContinueButton(VoidCallback onPressed) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 16.0,
          bottom: 56.0,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onPressed,
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckStatusBanner(bool isCorrect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green.shade300 : Colors.red.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            isCorrect ? 'Correct!' : 'Incorrect!',
            style: TextStyle(
              color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalSlides = _dynamicPages.length;

    if (totalSlides == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson Player')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.collections_bookmark_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                widget.courseId != null
                    ? 'This lesson has no slide pages yet.'
                    : 'This sub-chapter has no slide pages yet.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final double progressRatio = (totalSlides > 0)
        ? (_currentSlide + 1) / totalSlides
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: _handleBackPress,
        ),
        centerTitle: true,
        title: GestureDetector(
          onTap: () => _showPageJumpSheet(totalSlides),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentSlide + 1} / $totalSlides',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.deepPurple.shade700,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (_canViewDiscussion &&
              _dynamicPages.isNotEmpty &&
              _currentSlide < _dynamicPages.length) ...[
            Builder(
              builder: (context) {
                final page = _dynamicPages[_currentSlide];
                final count = _pageDiscussionCounts[page.id] ?? 0;
                return TextButton.icon(
                  onPressed: _openDiscussionsForCurrentPage,
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 22,
                    color: Colors.deepPurple,
                  ),
                  label: Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressRatio,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentSlide = page;
                  });
                },
                children: _dynamicPages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final pageObj = entry.value;
                  final blocks = _dynamicPageBlocks[pageObj.id] ?? [];
                  return _buildDynamicPage(pageObj, blocks, idx);
                }).toList(),
              ),
            ),
            _buildDynamicFooter(
              _currentSlide,
              _dynamicPages.isNotEmpty
                  ? _dynamicPageBlocks[_dynamicPages[_currentSlide].id] ?? []
                  : [],
              totalSlides,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------
// DYNAMIC MARKDOWN TEXT RENDERER
// ------------------------------------------
class MarkdownRenderer extends StatelessWidget {
  final String text;

  const MarkdownRenderer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final List<Widget> children = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith('# ')) {
        children.add(
          _buildHeading(context, trimmed.substring(2), 24, FontWeight.bold),
        );
      } else if (trimmed.startsWith('## ')) {
        children.add(
          _buildHeading(context, trimmed.substring(3), 22, FontWeight.bold),
        );
      } else if (trimmed.startsWith('### ')) {
        children.add(
          _buildHeading(context, trimmed.substring(4), 20, FontWeight.bold),
        );
      } else if (trimmed.startsWith('#### ')) {
        children.add(
          _buildHeading(context, trimmed.substring(5), 18, FontWeight.bold),
        );
      } else if (trimmed.startsWith('##### ')) {
        children.add(
          _buildHeading(context, trimmed.substring(6), 16, FontWeight.bold),
        );
      } else if (trimmed.startsWith('###### ')) {
        children.add(
          _buildHeading(context, trimmed.substring(7), 14, FontWeight.bold),
        );
      } else if (trimmed.startsWith('• ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Text(
                  '• ',
                  style: GoogleFonts.poppins(fontSize: 16, height: 1.4),
                ),
                Expanded(
                  child: Text.rich(
                    _parseInlineStyles(context, trimmed.substring(2)),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (trimmed.startsWith('- ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Text(
                  '• ',
                  style: GoogleFonts.poppins(fontSize: 16, height: 1.4),
                ),
                Expanded(
                  child: Text.rich(
                    _parseInlineStyles(context, trimmed.substring(2)),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text.rich(_parseInlineStyles(context, trimmed)),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildHeading(
    BuildContext context,
    String content,
    double fontSize,
    FontWeight weight,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
      child: Text.rich(
        _parseInlineStyles(
          context,
          content,
          baseStyle: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: weight,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  TextSpan _parseInlineStyles(
    BuildContext context,
    String line, {
    TextStyle? baseStyle,
  }) {
    final defaultStyle =
        baseStyle ??
        GoogleFonts.poppins(fontSize: 15, height: 1.5, color: Colors.black87);
    final List<TextSpan> spans = [];

    final RegExp exp = RegExp(r'(\*\*|\*|~~|<u>|</u>)');
    final matches = exp.allMatches(line);

    if (matches.isEmpty) {
      return TextSpan(text: line, style: defaultStyle);
    }

    int lastIndex = 0;
    bool isBold = false;
    bool isItalic = false;
    bool isStrike = false;
    bool isUnderline = false;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: line.substring(lastIndex, match.start),
            style: defaultStyle.copyWith(
              fontWeight: isBold ? FontWeight.bold : defaultStyle.fontWeight,
              fontStyle: isItalic ? FontStyle.italic : defaultStyle.fontStyle,
              decoration: TextDecoration.combine([
                if (isStrike) TextDecoration.lineThrough,
                if (isUnderline) TextDecoration.underline,
              ]),
            ),
          ),
        );
      }

      final tag = match.group(0);
      if (tag == '**') {
        isBold = !isBold;
      } else if (tag == '*') {
        isItalic = !isItalic;
      } else if (tag == '~~') {
        isStrike = !isStrike;
      } else if (tag == '<u>') {
        isUnderline = true;
      } else if (tag == '</u>') {
        isUnderline = false;
      }

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(lastIndex),
          style: defaultStyle.copyWith(
            fontWeight: isBold ? FontWeight.bold : defaultStyle.fontWeight,
            fontStyle: isItalic ? FontStyle.italic : defaultStyle.fontStyle,
            decoration: TextDecoration.combine([
              if (isStrike) TextDecoration.lineThrough,
              if (isUnderline) TextDecoration.underline,
            ]),
          ),
        ),
      );
    }

    return TextSpan(children: spans, style: defaultStyle);
  }
}

// ------------------------------------------
// PAGE-LEVEL DISCUSSIONS PANEL OVERLAY
// ------------------------------------------
class _PageDiscussionsSheet extends StatefulWidget {
  final String pageId;
  final String? subChapterId;
  final String? courseId;
  final VoidCallback onTopicCreated;

  const _PageDiscussionsSheet({
    required this.pageId,
    this.subChapterId,
    this.courseId,
    required this.onTopicCreated,
  });

  @override
  State<_PageDiscussionsSheet> createState() => _PageDiscussionsSheetState();
}

class _PageDiscussionsSheetState extends State<_PageDiscussionsSheet> {
  bool _isLoading = true;
  List<DiscussionTopic> _topics = [];
  List<DiscussionTopic> _filteredTopics = [];
  bool _canPost = true;
  String? _postDisabledReason;
  bool _checkedPermission = false;
  String _sortBy = 'Top Upvotes';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkCourseVisibility();
    _loadTopics();
  }

  Future<void> _checkCourseVisibility() async {
    try {
      final client = Supabase.instance.client;
      String? targetCourseId = widget.courseId;

      if (targetCourseId == null && widget.subChapterId != null) {
        final subRes = await client
            .from('lesson_sub_chapters')
            .select('chapter_id')
            .eq('id', widget.subChapterId!)
            .maybeSingle();
        final chapId = subRes?['chapter_id'] as String?;
        if (chapId != null) {
          final chapRes = await client
              .from('lesson_chapters')
              .select('course_id')
              .eq('id', chapId)
              .maybeSingle();
          targetCourseId = chapRes?['course_id'] as String?;
        }
      }

      if (targetCourseId == null) {
        final meta = await LessonRepository().getPageMetadata(widget.pageId);
        final subData = meta?['lesson_sub_chapters'] as Map<String, dynamic>?;
        final chapData = subData?['lesson_chapters'] as Map<String, dynamic>?;
        targetCourseId = chapData?['course_id'] as String?;
      }

      if (targetCourseId != null) {
        if (!mounted) return;
        final authRepo = context.read<AuthRepository>();
        final discRepo = context.read<DiscussionRepository>();
        final perm = await discRepo.checkLearnerCanPostDiscussion(
          userId: client.auth.currentUser?.id,
          isUserAdmin: authRepo.isAdmin,
          courseId: targetCourseId,
        );

        if (mounted) {
          setState(() {
            _canPost = perm.canPost;
            _postDisabledReason = perm.reason;
            _checkedPermission = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canPost = false;
            _postDisabledReason = 'Discussions are disabled for this content.';
            _checkedPermission = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking course visibility: $e');
      if (mounted) {
        setState(() {
          _canPost = false;
          _checkedPermission = true;
        });
      }
    }
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<DiscussionRepository>();
      final results = await repo.getTopics(pageId: widget.pageId);
      if (mounted) {
        setState(() {
          _topics = results;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    var list = List<DiscussionTopic>.from(_topics);

    if (query.isNotEmpty) {
      list = list
          .where(
            (t) =>
                t.title.toLowerCase().contains(query) ||
                t.content.toLowerCase().contains(query),
          )
          .toList();
    }

    if (_sortBy == 'Latest') {
      list.sort((a, b) {
        final dateA = a.updatedAt ?? a.createdAt;
        final dateB = b.updatedAt ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
    } else {
      list.sort((a, b) => b.score.compareTo(a.score));
    }

    setState(() => _filteredTopics = list);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      height: mediaQuery.size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Page Discussions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                    ),
                    if (!_checkedPermission || !_canPost)
                      const SizedBox.shrink()
                    else
                      TextButton.icon(
                        onPressed: () async {
                          // Capture context-dependent objects before any async gap
                          final lessonRepo = context.read<LessonRepository>();
                          final router = GoRouter.of(context);
                          String? chapterId;
                          try {
                            if (widget.subChapterId != null) {
                              if (widget.courseId != null) {
                                final chapters = await lessonRepo.getChapters(
                                  widget.courseId!,
                                );
                                for (var ch in chapters) {
                                  final subs = await lessonRepo.getSubChapters(
                                    ch.id,
                                  );
                                  if (subs.any(
                                    (s) => s.id == widget.subChapterId,
                                  )) {
                                    chapterId = ch.id;
                                    break;
                                  }
                                }
                              }
                            }
                          } catch (_) {}

                          if (!mounted) return;

                          final created = await router.push<bool>(
                            '/create-topic',
                            extra: {
                              'courseId': widget.courseId,
                              'chapterId': chapterId,
                              'subChapterId': widget.subChapterId,
                              'pageId': widget.pageId,
                            },
                          );
                          if (created == true) {
                            _loadTopics();
                            widget.onTopicCreated();
                          }
                        },
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: const Text('Post Topic'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                      ),
                  ],
                ),
                if (_checkedPermission &&
                    !_canPost &&
                    _postDisabledReason != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _postDisabledReason!,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Search field
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search discussions...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
                const SizedBox(height: 6),
                // Sort By + Refresh
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelText: 'Sort By',
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _sortBy,
                            isDense: true,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Latest',
                                child: Text('Latest'),
                              ),
                              DropdownMenuItem(
                                value: 'Top Upvotes',
                                child: Text('Top Upvotes'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _sortBy = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.deepPurple,
                      ),
                      tooltip: 'Reset',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _sortBy = 'Top Upvotes';
                        });
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTopics.isEmpty
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No discussions on this page yet.\nAsk a question or start a discussion!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _filteredTopics.length,
                    itemBuilder: (context, index) {
                      final topic = _filteredTopics[index];
                      final displayDate = topic.updatedAt ?? topic.createdAt;
                      final dateStr =
                          '${displayDate.day}/${displayDate.month}/${displayDate.year}';
                      final editedStr = topic.updatedAt != null
                          ? ' (edited)'
                          : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final result = await context.push(
                              '/discussion/${topic.id}',
                            );
                            if (result == true || result == null) {
                              _loadTopics();
                              widget.onTopicCreated();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    UserByteAvatar(
                                      radius: 9,
                                      userId: topic.authorId,
                                      name: topic.authorName,
                                      avatarData: topic.authorAvatarUrl,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      topic.authorName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$dateStr$editedStr',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  topic.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topic.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${topic.score}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.mode_comment_outlined,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'View Thread',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
