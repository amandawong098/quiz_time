import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/discussion_models.dart';
import '../models/flashcard_models.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/flashcard_repository.dart';

class FlashcardDiscussionsSheet extends StatefulWidget {
  final String deckId;
  final String? cardId;
  final String deckTitle;
  final String? cardFrontText;
  final int? cardNumber;
  final bool isLocked;
  final VoidCallback? onTopicCreated;

  const FlashcardDiscussionsSheet({
    super.key,
    required this.deckId,
    this.cardId,
    required this.deckTitle,
    this.cardFrontText,
    this.cardNumber,
    this.isLocked = false,
    this.onTopicCreated,
  });

  @override
  State<FlashcardDiscussionsSheet> createState() => _FlashcardDiscussionsSheetState();
}

class _FlashcardDiscussionsSheetState extends State<FlashcardDiscussionsSheet> {
  bool _isLoading = true;
  List<FlashcardItem> _cards = [];
  FlashcardDeck? _deck;
  List<DiscussionTopic> _allTopics = [];
  List<DiscussionTopic> _filteredTopics = [];
  String _selectedFilter = 'All';
  String _sortBy = 'Top Upvotes';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.cardId ?? 'All';
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
    await _loadCards();
    await _loadTopics();
  }

  Future<void> _loadCards() async {
    try {
      final repo = context.read<FlashcardRepository>();
      final deck = await repo.getDeckById(widget.deckId);
      final cards = await repo.getFlashcards(widget.deckId);
      if (mounted) {
        setState(() {
          _cards = cards;
          _deck = deck;
        });
      }
    } catch (e) {
      debugPrint('Error loading deck cards: $e');
    }
  }

  Future<void> _loadTopics() async {
    try {
      final repo = context.read<DiscussionRepository>();
      final results = await repo.getTopics(
        deckId: widget.deckId,
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

    // 1. Filter by scope
    if (_selectedFilter == 'General') {
      list = list.where((t) => t.cardId == null).toList();
    } else if (_selectedFilter != 'All') {
      list = list.where((t) => t.cardId == _selectedFilter).toList();
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

    bool hasSelectedFilter = _selectedFilter == 'All' || _selectedFilter == 'General';

    for (int i = 0; i < _cards.length; i++) {
      if (_cards[i].id == _selectedFilter) {
        hasSelectedFilter = true;
      }
      items.add(DropdownMenuItem(
        value: _cards[i].id,
        child: Text('Card ${i + 1}'),
      ));
    }

    if (!hasSelectedFilter) {
      items.add(DropdownMenuItem(
        value: _selectedFilter,
        child: Text(widget.cardNumber != null ? 'Card ${widget.cardNumber}' : 'Loading Card...'),
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

    final sheetTitle = widget.cardNumber != null
        ? 'Card ${widget.cardNumber} Discussions'
        : 'Deck Discussions';

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
                            widget.deckTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isLocked) ...[
                      if (_deck != null && _deck!.isPublic == false)
                        TextButton.icon(
                          onPressed: null,
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
                                'deckId': widget.deckId,
                                'cardId': widget.cardId,
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
                if (!widget.isLocked && _deck != null && _deck!.isPublic == false) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Discussions are turned off for private decks.',
                      style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                if (!widget.isLocked) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search discussions...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                      _applyFiltersAndSort();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) {
                            setState(() {});
                            _applyFiltersAndSort();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.deepPurple),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _selectedFilter = widget.cardId ?? 'All';
                            _sortBy = 'Top Upvotes';
                          });
                          _loadTopics();
                        },
                        tooltip: 'Refresh discussions',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            labelText: 'Scope',
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                          items: _buildFilterOptions(),
                          onChanged: (widget.cardId != null)
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() => _selectedFilter = val);
                                    _applyFiltersAndSort();
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _sortBy,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            labelText: 'Sort By',
                            labelStyle: const TextStyle(fontSize: 12),
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
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: widget.isLocked
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),
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
                            "Whoops! Looks like you haven't played this flashcard deck yet. To keep things fair and avoid spoiling the cards, discussions are locked until you submit your first revision attempt. Go revise these flashcards first! 🚀",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                    : _filteredTopics.isEmpty
                    ? SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No discussions yet.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: _filteredTopics.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final topic = _filteredTopics[index];
                          final localDate = topic.createdAt.toLocal();
                          final dateStr = '${localDate.day}/${localDate.month}/${localDate.year}';
                          final editedStr = topic.updatedAt != null ? ' (edited)' : '';
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                final result = await context.push('/discussion/${topic.id}');
                                if (result == true && mounted) {
                                  _loadTopics();
                                }
                              },
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
                                    if (topic.cardId != null) ...[
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
                                              Icons.style_rounded,
                                              size: 10,
                                              color: Colors.deepPurple,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Card ${topic.cardId == widget.cardId && widget.cardNumber != null ? widget.cardNumber : (_cards.indexWhere((c) => c.id == topic.cardId) + 1)}',
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
