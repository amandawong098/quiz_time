import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/discussion_models.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../models/lesson_models.dart';

class LessonDiscussionsSheet extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final VoidCallback? onTopicCreated;

  const LessonDiscussionsSheet({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.onTopicCreated,
  });

  @override
  State<LessonDiscussionsSheet> createState() => _LessonDiscussionsSheetState();
}

class _LessonDiscussionsSheetState extends State<LessonDiscussionsSheet> {
  bool _isLoading = true;
  List<DiscussionTopic> _allTopics = [];
  List<DiscussionTopic> _filteredTopics = [];
  String _sortBy = 'Top Upvotes';
  // 'all' = no filter, 'general' = lesson-level only, or a chapter ID
  String _selectedChapterFilter = 'all';
  String? _selectedSubChapterId;
  String? _selectedPageId;
  final TextEditingController _searchController = TextEditingController();

  List<LessonChapter> _chapters = [];
  Map<String, List<LessonSubChapter>> _subChaptersMap = {};
  Map<String, List<LessonPage>> _pagesMap = {};

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _loadLessonStructure();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLessonStructure() async {
    try {
      final lessonRepo = LessonRepository();
      final chapters = await lessonRepo.getChapters(widget.courseId);
      final Map<String, List<LessonSubChapter>> subChaps = {};
      final Map<String, List<LessonPage>> pages = {};
      
      for (var ch in chapters) {
        final subs = await lessonRepo.getSubChapters(ch.id);
        subChaps[ch.id] = subs;
        for (var sub in subs) {
          final pgs = await lessonRepo.getPages(sub.id);
          pages[sub.id] = pgs;
        }
      }
      
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _subChaptersMap = subChaps;
          _pagesMap = pages;
        });
      }
    } catch (e) {
      debugPrint('Error loading lesson structure: $e');
    }
  }

  Future<void> _loadTopics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final repo = context.read<DiscussionRepository>();
      final results = await repo.getTopics(
        courseId: widget.courseId,
      );
      if (mounted) {
        setState(() {
          _allTopics = results;
          _isLoading = false;
        });
        _applyFiltersAndSort();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFiltersAndSort() {
    final query = _searchController.text.toLowerCase();
    var list = List<DiscussionTopic>.from(_allTopics);

    // 1. Chapter filter
    if (_selectedChapterFilter == 'general') {
      // Only lesson-level (no chapter/sub/page)
      list = list.where((t) =>
          t.chapterId == null && t.subChapterId == null && t.pageId == null).toList();
    } else if (_selectedChapterFilter != 'all') {
      // Specific chapter ID
      list = list.where((t) => t.chapterId == _selectedChapterFilter).toList();
    }

    // 2. Sub-chapter filter
    if (_selectedSubChapterId != null) {
      list = list.where((t) => t.subChapterId == _selectedSubChapterId).toList();
    }

    // 3. Page filter
    if (_selectedPageId != null) {
      list = list.where((t) => t.pageId == _selectedPageId).toList();
    }

    // 4. Search query
    if (query.isNotEmpty) {
      list = list.where((t) =>
          t.title.toLowerCase().contains(query) ||
          t.content.toLowerCase().contains(query)).toList();
    }

    // 5. Sort
    if (_sortBy == 'Latest') {
      list.sort((a, b) {
        final dateA = a.updatedAt ?? a.createdAt;
        final dateB = b.updatedAt ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
    } else if (_sortBy == 'Top Upvotes') {
      list.sort((a, b) => b.score.compareTo(a.score));
    }

    setState(() {
      _filteredTopics = list;
    });
  }

  // Whether the chapter filter points to a real chapter (not 'all' or 'general')
  bool get _hasChapterSelected =>
      _selectedChapterFilter != 'all' && _selectedChapterFilter != 'general';

  List<DropdownMenuItem<String>> _buildChapterItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All')),
      const DropdownMenuItem(value: 'general', child: Text('General')),
    ];
    for (int i = 0; i < _chapters.length; i++) {
      items.add(DropdownMenuItem(
        value: _chapters[i].id,
        child: Text(
          'Ch ${i + 1}: ${_chapters[i].title}',
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }
    return items;
  }

  List<DropdownMenuItem<String>> _buildSortOptions() {
    return const [
      DropdownMenuItem(
        value: 'Latest',
        child: Text('Latest'),
      ),
      DropdownMenuItem(
        value: 'Top Upvotes',
        child: Text('Top Upvotes'),
      ),
    ];
  }

  Widget _buildDropdownBox({
    required String label,
    required Widget child,
    required bool enabled,
    required bool isDark,
  }) {
    return SizedBox(
      height: 44,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.only(left: 8, right: 4, top: 6, bottom: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: enabled
                  ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                  : Colors.grey.shade300,
            ),
          ),
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 10,
            color: enabled
                ? (isDark ? Colors.grey.shade300 : Colors.grey.shade700)
                : Colors.grey.shade400,
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
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
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lesson Discussions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.courseTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    if (!mounted) return;
                    final created = await context.push<bool>(
                      '/create-topic',
                      extra: {
                        'courseId': widget.courseId,
                      },
                    );
                    if (created == true && mounted) {
                      _loadTopics();
                      widget.onTopicCreated?.call();
                    }
                  },
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Post Topic'),
                  style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Row 1: Search
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
                              _applyFiltersAndSort();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (_) => _applyFiltersAndSort(),
                ),
                const SizedBox(height: 6),
                // Row 2: Chapter | Sub-chapter | Page
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Chapter
                      Expanded(
                        child: _buildDropdownBox(
                          label: 'Chapter',
                          enabled: true,
                          isDark: isDark,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedChapterFilter,
                            underline: const SizedBox(),
                            isDense: true,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            items: _buildChapterItems(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedChapterFilter = val;
                                  _selectedSubChapterId = null;
                                  _selectedPageId = null;
                                });
                                _applyFiltersAndSort();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Sub-chapter
                      Expanded(
                        child: _buildDropdownBox(
                          label: 'Sub-chapter',
                          enabled: _hasChapterSelected,
                          isDark: isDark,
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedSubChapterId,
                            underline: const SizedBox(),
                            isDense: true,
                            style: TextStyle(
                              fontSize: 11,
                              color: _hasChapterSelected
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey.shade400,
                            ),
                            items: _hasChapterSelected
                                ? [
                                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                                    for (final sub in _subChaptersMap[_selectedChapterFilter] ?? [])
                                      DropdownMenuItem<String?>(value: sub.id, child: Text(sub.title, overflow: TextOverflow.ellipsis)),
                                  ]
                                : [const DropdownMenuItem<String?>(value: null, child: Text('—'))],
                            onChanged: _hasChapterSelected
                                ? (val) {
                                    setState(() {
                                      _selectedSubChapterId = val;
                                      _selectedPageId = null;
                                    });
                                    _applyFiltersAndSort();
                                  }
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Page
                      Expanded(
                        child: _buildDropdownBox(
                          label: 'Page',
                          enabled: _selectedSubChapterId != null,
                          isDark: isDark,
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedPageId,
                            underline: const SizedBox(),
                            isDense: true,
                            style: TextStyle(
                              fontSize: 11,
                              color: _selectedSubChapterId != null
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey.shade400,
                            ),
                            items: _selectedSubChapterId != null
                                ? [
                                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                                    for (final pg in _pagesMap[_selectedSubChapterId] ?? [])
                                      DropdownMenuItem<String?>(value: pg.id, child: Text('Slide ${pg.position + 1}')),
                                  ]
                                : [const DropdownMenuItem<String?>(value: null, child: Text('—'))],
                            onChanged: _selectedSubChapterId != null
                                ? (val) {
                                    setState(() => _selectedPageId = val);
                                    _applyFiltersAndSort();
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Row 3: Sort By + Refresh
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownBox(
                        label: 'Sort By',
                        enabled: true,
                        isDark: isDark,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _sortBy,
                          underline: const SizedBox(),
                          isDense: true,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          items: _buildSortOptions(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortBy = val);
                              _applyFiltersAndSort();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.deepPurple),
                      tooltip: 'Reset Filters',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _selectedChapterFilter = 'all';
                          _selectedSubChapterId = null;
                          _selectedPageId = null;
                          _sortBy = 'Top Upvotes';
                        });
                        _applyFiltersAndSort();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
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
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No discussions found.\nStart the conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: _filteredTopics.length,
                        itemBuilder: (context, index) {
                          final topic = _filteredTopics[index];
                          final displayDate = topic.updatedAt ?? topic.createdAt;
                          final dateStr = '${displayDate.day}/${displayDate.month}/${displayDate.year}';
                          final editedStr = topic.updatedAt != null ? ' (edited)' : '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              ),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final result = await context.push('/discussion/${topic.id}');
                                if ((result == true || result == null) && mounted) {
                                  _loadTopics();
                                  widget.onTopicCreated?.call();
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
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: Colors.deepPurple.shade100,
                                          backgroundImage: topic.authorAvatarUrl != null
                                              ? NetworkImage(topic.authorAvatarUrl!)
                                              : null,
                                          child: topic.authorAvatarUrl == null
                                              ? const Icon(Icons.person, size: 9)
                                              : null,
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
                                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (topic.pageId != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.deepPurple.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.menu_book_rounded,
                                              size: 10,
                                              color: Colors.deepPurple,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '${topic.chapterTitle ?? ""} > ${topic.subChapterTitle ?? ""} > Slide ${(topic.pagePosition ?? 0) + 1}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepPurple,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else if (topic.subChapterId != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.deepPurple.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.menu_book_rounded,
                                              size: 10,
                                              color: Colors.deepPurple,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                '${topic.chapterTitle ?? ""} > ${topic.subChapterTitle ?? ""}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepPurple,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else if (topic.chapterId != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.deepPurple.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.menu_book_rounded,
                                              size: 10,
                                              color: Colors.deepPurple,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Chapter: ${topic.chapterTitle ?? ""}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepPurple,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 14,
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${topic.score}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.mode_comment_outlined,
                                          size: 14,
                                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'View Thread',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
