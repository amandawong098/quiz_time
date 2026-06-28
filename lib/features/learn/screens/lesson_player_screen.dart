import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../models/lesson_models.dart';
import '../models/lesson_progress.dart';
import '../../../core/widgets/video_preview_widget.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String? subChapterId;
  final String? courseId;
  final bool isPreview;
  const LessonPlayerScreen({
    super.key,
    this.subChapterId,
    this.courseId,
    this.isPreview = false,
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

  // Mock Lesson state (when subChapterId is null)
  final int _totalSlides = 3;
  int? _slide2SelectedIndex;
  bool _slide2Checked = false;
  bool? _slide2Correct;

  final Set<int> _slide3SelectedIndices = {};
  bool _slide3Checked = false;
  bool? _slide3Correct;

  final List<String> _slide2Options = [
    '3: LOW, MEDIUM and HIGH',
    '2: ON and OFF',
  ];
  final int _slide2CorrectIndex = 1;

  final List<String> _slide3Options = ['0', '1', '-1', '2'];
  final Set<int> _slide3CorrectIndices = {0, 1};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.subChapterId != null || widget.courseId != null) {
      _loadDynamicLesson();
    } else {
      _loadMockLessonProgress();
    }
    if (widget.isPreview) {
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

  Future<void> _loadMockLessonProgress() async {
    if (widget.isPreview) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final key = _getProgressKey(user.id);
        if (key != null) {
          final saved = prefs.getInt(key);
          if (saved != null && saved >= 0 && saved < _totalSlides) {
            setState(() {
              _currentSlide = saved;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(saved);
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveProgressStep(int pageIndex) async {
    if (widget.isPreview) return;
    if (widget.subChapterId != null) {
      await _progressTracker.saveSlideIndex(widget.subChapterId!, pageIndex);
    } else {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        final prefs = await SharedPreferences.getInstance();
        final key = _getProgressKey(user.id);
        if (key != null) {
          final currentSaved = prefs.getInt(key) ?? 0;
          if (pageIndex > currentSaved) {
            await prefs.setInt(key, pageIndex);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _clearProgressStep() async {
    if (widget.subChapterId != null) {
      await _progressTracker.clearSlideIndex(widget.subChapterId!);
    } else {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        final prefs = await SharedPreferences.getInstance();
        final key = _getProgressKey(user.id);
        if (key != null) {
          await prefs.remove(key);
        }
      } catch (_) {}
    }
  }

  String? _getProgressKey(String userId) {
    if (widget.subChapterId != null) {
      return 'lesson_slide_index_${userId}_sub_${widget.subChapterId}';
    } else if (widget.courseId != null) {
      return 'lesson_slide_index_${userId}_course_${widget.courseId}';
    } else {
      return 'lesson_slide_index_${userId}_mock';
    }
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
            final subPages = await repo.getPages(sub.id);
            for (var page in subPages) {
              pages.add(page);
              _pageSubChapterMap[page.id] = sub.id;
              final blocks = await repo.getBlocks(page.id);
              pageBlocks[page.id] = blocks;
            }
          }
        }
      } else if (widget.subChapterId != null) {
        final subPages = await repo.getPages(widget.subChapterId!);
        for (var page in subPages) {
          pages.add(page);
          _pageSubChapterMap[page.id] = widget.subChapterId!;
          final blocks = await repo.getBlocks(page.id);
          pageBlocks[page.id] = blocks;
        }
      }

      int initialPage = 0;
      if (!widget.isPreview) {
        if (widget.subChapterId != null) {
          await _progressTracker.loadFromSupabase();
          initialPage = _progressTracker.getSavedSlideIndex(widget.subChapterId!);
          if (initialPage >= pages.length) {
            initialPage = 0;
          }
        } else if (widget.courseId != null) {
          try {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              final prefs = await SharedPreferences.getInstance();
              final key = _getProgressKey(user.id);
              if (key != null) {
                final saved = prefs.getInt(key);
                if (saved != null && saved >= 0 && saved < pages.length) {
                  initialPage = saved;
                }
              }
            }
          } catch (_) {}
        }
      }

      setState(() {
        _dynamicPages = pages;
        _dynamicPageBlocks = pageBlocks;
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

  Future<void> _handleBackPress() async {
    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Lesson?'),
            content: Text(
              widget.isPreview
                  ? 'Are you sure you want to quit this lesson? Your preview progress will not be saved.'
                  : 'Are you sure you want to quit this lesson? Your progress will be saved so you can continue from this page next time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit && mounted) {
      context.pop();
    }
  }

  void _checkSlide2Answer(int index) {
    if (_slide2Checked) return;
    setState(() {
      _slide2SelectedIndex = index;
      _slide2Checked = true;
      _slide2Correct = index == _slide2CorrectIndex;
    });
  }

  void _checkSlide3Answer() {
    if (_slide3Checked) return;
    setState(() {
      _slide3Checked = true;
      _slide3Correct =
          _slide3SelectedIndices.length == _slide3CorrectIndices.length &&
          _slide3SelectedIndices.every(
            (i) => _slide3CorrectIndices.contains(i),
          );
    });
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
    final isDynamic = widget.subChapterId != null || widget.courseId != null;
    if (!widget.isPreview) {
      await _clearProgressStep();
      if (isDynamic) {
        if (widget.subChapterId != null) {
          await _progressTracker.complete(widget.subChapterId!);
        } else if (widget.courseId != null && _dynamicPages.isNotEmpty) {
          final currentPageObj = _dynamicPages[_currentSlide];
          final currentSubChapterId = _pageSubChapterMap[currentPageObj.id];
          if (currentSubChapterId != null) {
            await _progressTracker.complete(currentSubChapterId);
          }
        }
      } else {
        await _progressTracker.complete('thinking_machine');
      }
    }
  }

  void _completeLesson() {
    final isDynamic = widget.subChapterId != null || widget.courseId != null;
    final completionFuture = _saveCompletionState();

    if (widget.isPreview) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Preview Complete'),
          content: const Text('You have successfully previewed this lesson sub-chapter!'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Lesson Complete!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'XP +10 Earned',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.deepPurple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isDynamic
                          ? 'You have successfully completed this lesson. You can now proceed to the next lesson sub-chapter!'
                          : 'You have successfully completed "Thinking Like a Machine". You can now proceed to the next lesson sub-chapter!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                              title: caption.isNotEmpty ? caption : 'Embedded Video',
                            )
                          : Image.network(url, fit: BoxFit.cover),
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
      _questionStates.putIfAbsent(
        b.id,
        () => SlideQuestionState(),
      );
    }

    final allChecked = testBlocks.every((b) => _questionStates[b.id]?.checked == true);

    if (allChecked) {
      final anyWrong = testBlocks.any((b) => _questionStates[b.id]?.isCorrect != true);
      if (anyWrong) {
        return _buildTryAgainButton(() {
          setState(() {
            for (var b in testBlocks) {
              final state = _questionStates[b.id];
              if (state != null && state.isCorrect != true) {
                state.checked = false;
                state.isCorrect = null;
                state.selectedIndex = null;
                state.selectedIndices.clear();
              }
            }
          });
        });
      }
      return _buildContinueButton(() {
        _handleContinue(totalSlides);
      });
    } else {
      // Find unchecked checkbox tests
      final uncheckedCheckboxes = testBlocks
          .where((b) =>
              (b.content['is_multiple_choice'] as bool? ?? false) &&
              _questionStates[b.id]?.checked != true)
          .toList();

      if (uncheckedCheckboxes.isNotEmpty) {
        // Can submit only when all unchecked checkbox tests have at least one choice selected
        final canSubmit = uncheckedCheckboxes.every((b) =>
            (_questionStates[b.id]?.selectedIndices.isNotEmpty) == true);

        return Padding(
          padding: const EdgeInsets.all(24.0),
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
              onPressed: canSubmit
                  ? () {
                      setState(() {
                        for (var b in uncheckedCheckboxes) {
                          final state = _questionStates[b.id]!;
                          state.checked = true;
                          final options = b.content['options'] as List<dynamic>? ?? [];
                          final correctIndices = <int>{};
                          for (int k = 0; k < options.length; k++) {
                            if ((options[k] as Map)['is_correct'] == true) {
                              correctIndices.add(k);
                            }
                          }
                          state.isCorrect =
                              state.selectedIndices.length == correctIndices.length &&
                              state.selectedIndices.every((i) => correctIndices.contains(i));
                        }
                      });
                    }
                  : null,
              child: const Text(
                'Submit Answer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        );
      } else {
        // Only radio tests left to answer (which auto-submit upon tapping), so just show empty space
        return const SizedBox(height: 24);
      }
    }
  }

  Widget _buildTryAgainButton(VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
            'Try Again',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
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
    );
  }

  // ------------------------------------------
  // MOCK SIDES RENDERING
  // ------------------------------------------
  Widget _buildReadingSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Computational Thinking',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'In the previous lesson, you learned that computers are really good at performing tiny simple operations very fast. Complex modern tasks like video streaming or online banking transactions can be broken down into these simple calculations.',
            style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
          ),
          const SizedBox(height: 28),
          _buildCpuChipDiagram(),
          const SizedBox(height: 28),
          const Text(
            'In this lesson, you\'ll learn how to think like a computer to bring you one step closer to becoming a human-machine hybrid.',
            style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSingleChoiceSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'How many different positions have the individual switches inside a computer?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          if (_slide2Checked) ...[
            _buildCheckStatusBanner(_slide2Correct ?? false),
            const SizedBox(height: 8),
          ],
          Column(
            children: _slide2Options.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;

              final isSelected = _slide2SelectedIndex == index;
              final isCorrectOption = index == _slide2CorrectIndex;

              Color? cardColor;
              BorderSide borderSide = BorderSide(color: Colors.grey.shade300);

              if (_slide2Checked) {
                if (isCorrectOption) {
                  cardColor = Colors.green.shade200;
                  borderSide = BorderSide(
                    color: Colors.green.shade400,
                    width: 2,
                  );
                } else if (isSelected) {
                  cardColor = Colors.red.shade200;
                  borderSide = BorderSide(color: Colors.red.shade400, width: 2);
                }
              } else if (isSelected) {
                borderSide = const BorderSide(
                  color: Colors.deepPurple,
                  width: 2,
                );
              }

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: borderSide,
                ),
                child: RadioListTile<int>(
                  title: Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: index,
                  groupValue: _slide2SelectedIndex,
                  activeColor: Colors.deepPurple,
                  onChanged: _slide2Checked
                      ? null
                      : (val) {
                          if (val != null) {
                            _checkSlide2Answer(val);
                          }
                        },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Computers use binary code to represent information. Binary means that there are only two possibilities for the state of a switch. To make things simpler, numbers are used to represent the OFF/ON states of a switch.',
            style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          _buildBinarySwitchesDiagram(),
          const SizedBox(height: 28),
          const Text(
            'Which numbers are used for the binary code?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          if (_slide3Checked) ...[
            _buildCheckStatusBanner(_slide3Correct ?? false),
            const SizedBox(height: 8),
          ],
          Column(
            children: _slide3Options.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;

              final isSelected = _slide3SelectedIndices.contains(index);
              final isCorrectOption = _slide3CorrectIndices.contains(index);

              Color? cardColor;
              BorderSide borderSide = BorderSide(color: Colors.grey.shade300);

              if (_slide3Checked) {
                if (isCorrectOption) {
                  cardColor = Colors.green.shade200;
                  borderSide = BorderSide(
                    color: Colors.green.shade400,
                    width: 2,
                  );
                } else if (isSelected) {
                  cardColor = Colors.red.shade200;
                  borderSide = BorderSide(color: Colors.red.shade400, width: 2);
                }
              } else if (isSelected) {
                borderSide = const BorderSide(
                  color: Colors.deepPurple,
                  width: 2,
                );
              }

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: borderSide,
                ),
                child: CheckboxListTile(
                  title: Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: isSelected,
                  activeColor: Colors.deepPurple,
                  onChanged: _slide3Checked
                      ? null
                      : (val) {
                          setState(() {
                            if (val == true) {
                              _slide3SelectedIndices.add(index);
                            } else {
                              _slide3SelectedIndices.remove(index);
                            }
                          });
                        },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
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

  Widget _buildFooterActions() {
    if (_currentSlide == 0) {
      return Container(
        padding: const EdgeInsets.all(24.0),
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
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      );
    } else if (_currentSlide == 1) {
      if (_slide2Checked) {
        final isCorrect = _slide2Correct ?? false;
        if (!isCorrect) {
          return _buildTryAgainButton(() {
            setState(() {
              _slide2Checked = false;
              _slide2SelectedIndex = null;
              _slide2Correct = null;
            });
          });
        }
        return Padding(
          padding: const EdgeInsets.all(24.0),
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
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        );
      } else {
        return const SizedBox(height: 24);
      }
    } else {
      if (_slide3Checked) {
        final isCorrect = _slide3Correct ?? false;
        if (!isCorrect) {
          return _buildTryAgainButton(() {
            setState(() {
              _slide3Checked = false;
              _slide3SelectedIndices.clear();
              _slide3Correct = null;
            });
          });
        }
        return Padding(
          padding: const EdgeInsets.all(24.0),
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
              onPressed: _completeLesson,
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        );
      } else {
        final hasSelection = _slide3SelectedIndices.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.all(24.0),
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
              onPressed: hasSelection ? _checkSlide3Answer : null,
              child: const Text(
                'Submit Answer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        );
      }
    }
  }

  Widget _buildCpuChipDiagram() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.memory, size: 64, color: Colors.deepPurple.shade700),
            const SizedBox(height: 8),
            Text(
              'CPU chip: executes billions of simple instructions per second',
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepPurple.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBinarySwitchesDiagram() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.toggle_on,
                  size: 56,
                  color: Colors.deepPurple.shade700,
                ),
                const SizedBox(width: 24),
                Icon(Icons.toggle_off, size: 56, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Switch state inside computer: ON (1) vs OFF (0)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepPurple.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDynamic = widget.subChapterId != null || widget.courseId != null;
    final totalSlides = isDynamic ? _dynamicPages.length : _totalSlides;

    if (isDynamic && totalSlides == 0) {
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: _handleBackPress,
          ),
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
                  physics: LessonScrollPhysics(
                    isPageUnlocked: (page) {
                      if (!isDynamic) {
                        if (page == 0) return true;
                        if (page == 1) return _slide2Checked;
                        return _slide3Checked;
                      } else {
                        final pageObj = _dynamicPages[page];
                        final blocks = _dynamicPageBlocks[pageObj.id] ?? [];
                        final testBlocks = blocks.where((b) => b.blockType == 'test').toList();
                        if (testBlocks.isEmpty) return true;
                        return testBlocks.every((b) => _questionStates[b.id]?.checked == true);
                      }
                    },
                  ),
                  onPageChanged: (page) {
                    setState(() {
                      _currentSlide = page;
                    });
                    _saveProgressStep(page);
                  },
                  children: isDynamic
                      ? _dynamicPages.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final pageObj = entry.value;
                          final blocks = _dynamicPageBlocks[pageObj.id] ?? [];
                          return _buildDynamicPage(pageObj, blocks, idx);
                        }).toList()
                      : [
                          _buildReadingSlide(),
                          _buildSingleChoiceSlide(),
                          _buildMultipleChoiceSlide(),
                        ],
                ),
              ),
              isDynamic
                  ? _buildDynamicFooter(
                      _currentSlide,
                      _dynamicPages.isNotEmpty
                          ? _dynamicPageBlocks[_dynamicPages[_currentSlide]
                                    .id] ??
                                []
                          : [],
                      totalSlides,
                    )
                  : _buildFooterActions(),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom ScrollPhysics subclass to enforce lesson linear progression
class LessonScrollPhysics extends ScrollPhysics {
  final bool Function(int page) isPageUnlocked;

  const LessonScrollPhysics({required this.isPageUnlocked, super.parent});

  @override
  LessonScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LessonScrollPhysics(
      isPageUnlocked: isPageUnlocked,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value > position.pixels) {
      final double viewportWidth = position.viewportDimension;
      if (viewportWidth > 0) {
        final int currentPage = (position.pixels / viewportWidth).floor();
        if (!isPageUnlocked(currentPage)) {
          final double pageBoundary = currentPage * viewportWidth;
          if (value > pageBoundary) {
            return value - position.pixels;
          }
        }
      }
    }
    return super.applyBoundaryConditions(position, value);
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
        children.add(_buildHeading(context, trimmed.substring(2), 24, FontWeight.bold));
      } else if (trimmed.startsWith('## ')) {
        children.add(_buildHeading(context, trimmed.substring(3), 22, FontWeight.bold));
      } else if (trimmed.startsWith('### ')) {
        children.add(_buildHeading(context, trimmed.substring(4), 20, FontWeight.bold));
      } else if (trimmed.startsWith('#### ')) {
        children.add(_buildHeading(context, trimmed.substring(5), 18, FontWeight.bold));
      } else if (trimmed.startsWith('##### ')) {
        children.add(_buildHeading(context, trimmed.substring(6), 16, FontWeight.bold));
      } else if (trimmed.startsWith('###### ')) {
        children.add(_buildHeading(context, trimmed.substring(7), 14, FontWeight.bold));
      } else if (trimmed.startsWith('• ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Text('• ', style: GoogleFonts.poppins(fontSize: 16, height: 1.4)),
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
                Text('• ', style: GoogleFonts.poppins(fontSize: 16, height: 1.4)),
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

  Widget _buildHeading(BuildContext context, String content, double fontSize, FontWeight weight) {
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

  TextSpan _parseInlineStyles(BuildContext context, String line, {TextStyle? baseStyle}) {
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
