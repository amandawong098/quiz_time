import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/discussion_models.dart';
import '../../../data/models/quiz_models.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/quiz_repository.dart';

class QuizDiscussionsSheet extends StatefulWidget {
  final String quizId;
  final String? questionId;
  final String quizTitle;
  final String? questionText;
  final int? questionNumber;
  final bool isLocked;
  final VoidCallback? onTopicCreated;

  const QuizDiscussionsSheet({
    super.key,
    required this.quizId,
    this.questionId,
    required this.quizTitle,
    this.questionText,
    this.questionNumber,
    this.isLocked = false,
    this.onTopicCreated,
  });

  @override
  State<QuizDiscussionsSheet> createState() => _QuizDiscussionsSheetState();
}

class _QuizDiscussionsSheetState extends State<QuizDiscussionsSheet> {
  bool _isLoading = true;
  List<Question> _questions = [];
  Quiz? _quiz;
  List<DiscussionTopic> _allTopics = [];
  List<DiscussionTopic> _filteredTopics = [];
  String _selectedFilter = 'All';
  String _sortBy = 'Top Upvotes';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.questionId ?? 'All';
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadQuestions();
    await _loadTopics();
  }

  Future<void> _loadQuestions() async {
    try {
      final repo = context.read<QuizRepository>();
      final data = await repo.getQuizDetails(widget.quizId);
      if (mounted) {
        setState(() {
          _questions = data['questions'] as List<Question>;
          _quiz = data['quiz'] as Quiz;
        });
      }
    } catch (e) {
      debugPrint('Error loading quiz questions: $e');
    }
  }

  Future<void> _loadTopics() async {
    try {
      final repo = context.read<DiscussionRepository>();
      // We retrieve ALL quiz discussions and perform filter & sorting client-side
      final results = await repo.getTopics(
        quizId: widget.quizId,
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

    // 1. Filter by scope (filter: 'All', 'General', or questionId)
    if (_selectedFilter == 'General') {
      list = list.where((t) => t.questionId == null).toList();
    } else if (_selectedFilter != 'All') {
      list = list.where((t) => t.questionId == _selectedFilter).toList();
    }

    // 2. Filter by search query
    if (query.isNotEmpty) {
      list = list.where((t) =>
          t.title.toLowerCase().contains(query) ||
          t.content.toLowerCase().contains(query)).toList();
    }

    // 3. Sort by criteria
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

  List<DropdownMenuItem<String>> _buildFilterOptions() {
    final List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem(
        value: 'All',
        child: Text('All Discussions'),
      ),
      const DropdownMenuItem(
        value: 'General',
        child: Text('General'),
      ),
    ];

    for (int i = 0; i < _questions.length; i++) {
      items.add(DropdownMenuItem(
        value: _questions[i].id,
        child: Text('Question ${i + 1}'),
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetTitle = widget.questionNumber != null
        ? 'Question ${widget.questionNumber} Discussions'
        : 'Quiz Discussions';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sheetTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.quizTitle,
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
                    if (!widget.isLocked) ...[
                      if (_quiz != null && _quiz!.isPublic == false)
                        TextButton.icon(
                          onPressed: null, // Disabled
                          icon: Icon(Icons.add_comment_outlined, size: 18, color: Colors.grey.shade400),
                          label: Text(
                            'Post Topic (Disabled)',
                            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: () async {
                            if (!mounted) return;
                            final created = await context.push<bool>(
                              '/create-topic',
                              extra: {
                                'quizId': widget.quizId,
                                'questionId': widget.questionId,
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
                  ],
                ),
                if (!widget.isLocked && _quiz != null && _quiz!.isPublic == false) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Discussions are turned off for private quizzes.',
                      style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!widget.isLocked) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFiltersAndSort();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (_) => _applyFiltersAndSort(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                    tooltip: 'Reset Filters',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _selectedFilter = 'All';
                        _sortBy = 'Top Upvotes';
                      });
                      _applyFiltersAndSort();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('scope_dropdown_$_selectedFilter'),
                        initialValue: _selectedFilter,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelText: 'Scope',
                          labelStyle: const TextStyle(fontSize: 10),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        items: _buildFilterOptions(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedFilter = val);
                            _applyFiltersAndSort();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('sort_dropdown_$_sortBy'),
                        initialValue: _sortBy,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelText: 'Sort By',
                          labelStyle: const TextStyle(fontSize: 10),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white : Colors.black,
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
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          const Divider(),
          Expanded(
            child: widget.isLocked
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_person_rounded,
                            size: 64,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '🔒 Spoilers Ahead!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Whoops! Looks like you haven't played this quiz yet. To keep things fair and avoid spoiling the answers, discussions are locked until you submit your first attempt. Go show this quiz who's boss first! 🚀",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isLoading
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
                            Text(
                              widget.questionId == null
                                  ? 'No discussions for this quiz yet.\nStart the conversation!'
                                  : 'No discussions on this question yet.\nAsk a question or start a discussion!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                                    if (topic.questionId != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.deepPurple.shade100),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.assignment_turned_in_rounded,
                                              size: 10,
                                              color: Colors.deepPurple,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Question ${(topic.questionOrderIndex ?? 0) + 1}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
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
