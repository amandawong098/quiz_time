import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../learn/models/flashcard_models.dart';
import '../../../data/models/discussion_models.dart';
import '../../profile/widgets/user_detail_bottom_sheet.dart';

class DiscussionsDummyScreen extends StatefulWidget {
  const DiscussionsDummyScreen({super.key});

  @override
  State<DiscussionsDummyScreen> createState() => _DiscussionsDummyScreenState();
}

class _DiscussionsDummyScreenState extends State<DiscussionsDummyScreen> {
  bool _isLoading = true;
  List<DiscussionTopic> _topics = [];

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTypeFilter = 'All'; // 'All', 'Lessons', 'Quizzes', 'Flashcards', 'General'
  String _sortBy = 'Top Upvotes'; // 'Top Upvotes', 'Latest'

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _isLoading = true);
    }
    try {
      final repo = context.read<DiscussionRepository>();
      final results = await repo.getTopics(
        query: _searchQuery,
      );
      if (mounted) {
        setState(() {
          // Filter client-side
          List<DiscussionTopic> filtered = results;
          if (_selectedTypeFilter == 'Lessons') {
            filtered = results.where((t) => t.courseId != null).toList();
          } else if (_selectedTypeFilter == 'Quizzes') {
            filtered = results.where((t) => t.quizId != null).toList();
          } else if (_selectedTypeFilter == 'Flashcards') {
            filtered = results.where((t) => t.deckId != null).toList();
          } else if (_selectedTypeFilter == 'General') {
            filtered = results.where((t) => t.courseId == null && t.quizId == null && t.deckId == null).toList();
          }

          // Sort client-side
          if (_sortBy == 'Top Upvotes') {
            filtered.sort((a, b) {
              final scoreCompare = b.score.compareTo(a.score);
              if (scoreCompare != 0) return scoreCompare;
              return b.createdAt.compareTo(a.createdAt);
            });
          } else if (_sortBy == 'Latest') {
            filtered.sort((a, b) {
              final dateA = a.updatedAt ?? a.createdAt;
              final dateB = b.updatedAt ?? b.createdAt;
              return dateB.compareTo(dateA);
            });
          }

          _topics = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load discussions: $e')),
        );
      }
    }
  }

  Future<void> _voteTopic(String topicId, int voteType) async {
    try {
      final repo = context.read<DiscussionRepository>();
      await repo.voteTopic(topicId, voteType);
      await _loadTopics(showSpinner: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote failed: $e')),
        );
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildFilterTile(String value, String label, IconData icon, Color activeColor) {
              final isSelected = _selectedTypeFilter == value;
              return ListTile(
                leading: Icon(icon, color: isSelected ? activeColor : Colors.grey),
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? activeColor : null,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_circle_rounded, color: activeColor) : null,
                onTap: () {
                  setState(() {
                    _selectedTypeFilter = value;
                  });
                  _loadTopics();
                  Navigator.pop(context);
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Text(
                        'Filter Discussions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                    buildFilterTile('All', 'All Discussions', Icons.forum_rounded, Colors.deepPurple),
                    buildFilterTile('Lessons', 'Lessons', Icons.menu_book_rounded, Colors.blue),
                    buildFilterTile('Quizzes', 'Quizzes', Icons.assignment_turned_in_rounded, Colors.amber.shade800),
                    buildFilterTile('Flashcards', 'Flashcards', Icons.style_rounded, Colors.purple),
                    buildFilterTile('General', 'General (No Context)', Icons.chat_bubble_rounded, Colors.grey.shade700),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildVotingWidget({required DiscussionTopic topic}) {
    final upvoted = topic.userVoteType == 1;
    final downvoted = topic.userVoteType == -1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_upward_rounded,
            color: upvoted ? Colors.deepPurple : Colors.grey.shade400,
            size: 24,
          ),
          onPressed: () => _voteTopic(topic.id, 1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(height: 2),
        Text(
          topic.score.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: upvoted
                ? Colors.deepPurple
                : (downvoted ? Colors.red : Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 2),
        IconButton(
          icon: Icon(
            Icons.arrow_downward_rounded,
            color: downvoted ? Colors.red : Colors.grey.shade400,
            size: 24,
          ),
          onPressed: () => _voteTopic(topic.id, -1),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildAttachmentIndicator(String? type) {
    if (type == null) return const SizedBox.shrink();

    IconData icon;
    Color color;

    switch (type) {
      case 'image':
        icon = Icons.image;
        color = Colors.green;
        break;
      case 'video':
        icon = Icons.video_collection;
        color = Colors.red;
        break;
      case 'link':
        icon = Icons.link;
        color = Colors.blue;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            'Attachment attached',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussions'),
        elevation: 0,
        actions: const [NotificationIconBadge()],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTopics,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Input Bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade500),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search forum threads...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                          _loadTopics();
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                          _loadTopics();
                        },
                        tooltip: 'Clear search',
                      ),
                    IconButton(
                      icon: Icon(
                        _selectedTypeFilter == 'All' ? Icons.filter_list_rounded : Icons.filter_list_alt,
                        color: _selectedTypeFilter == 'All' ? Colors.grey.shade500 : Colors.deepPurple,
                      ),
                      onPressed: _showFilterBottomSheet,
                      tooltip: 'Filter by category',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_selectedTypeFilter != 'All') ...[
                    InputChip(
                      avatar: Icon(
                        _selectedTypeFilter == 'Lessons'
                            ? Icons.menu_book_rounded
                            : _selectedTypeFilter == 'Quizzes'
                                ? Icons.assignment_turned_in_rounded
                                : _selectedTypeFilter == 'Flashcards'
                                    ? Icons.style_rounded
                                    : Icons.chat_bubble_rounded,
                        size: 14,
                        color: _selectedTypeFilter == 'Lessons'
                            ? Colors.blue
                            : _selectedTypeFilter == 'Quizzes'
                                ? Colors.amber.shade900
                                : _selectedTypeFilter == 'Flashcards'
                                    ? Colors.purple
                                    : Colors.grey.shade700,
                      ),
                      label: Text(_selectedTypeFilter),
                      onDeleted: () {
                        setState(() {
                          _selectedTypeFilter = 'All';
                        });
                        _loadTopics();
                      },
                      deleteIconColor: Colors.deepPurple,
                      backgroundColor: Colors.deepPurple.shade50,
                      side: BorderSide(color: Colors.deepPurple.shade100),
                      labelStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'All Discussions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      const Text(
                        'Sort by: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.deepPurple),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Top Upvotes',
                            child: Text('Top Upvotes'),
                          ),
                          DropdownMenuItem(
                            value: 'Latest',
                            child: Text('Latest'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _sortBy = val;
                            });
                            _loadTopics();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Topics Timeline List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _topics.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(
                                  child: Text(
                                    'No discussions found.\nBe the first to start a conversation!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _topics.length,
                            itemBuilder: (context, index) {
                              final topic = _topics[index];
                              final displayDate = topic.updatedAt ?? topic.createdAt;
                              final dateStr = '${displayDate.day}/${displayDate.month}/${displayDate.year}';
                              final editedStr = topic.updatedAt != null ? ' (edited)' : '';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    final result = await context.push('/discussion/${topic.id}');
                                    if (result == true || result == null) {
                                      _loadTopics();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Voting arrow block
                                        _buildVotingWidget(topic: topic),
                                        const SizedBox(width: 16),
                                        // Main content text details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                   if (topic.courseId != null) ...[
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(right: 8.0),
                                                        child: InkWell(
                                                          onTap: () {
                                                            if (topic.pageId != null && topic.subChapterId != null) {
                                                              context.push('/lesson-player?subChapterId=${topic.subChapterId}&isPreview=true&initialPageId=${topic.pageId}');
                                                            } else {
                                                              context.go('/?selectedCourseId=${topic.courseId}');
                                                            }
                                                          },
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue.shade50,
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: Colors.blue.shade200),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.menu_book_rounded, size: 12, color: Colors.blue),
                                                                const SizedBox(width: 4),
                                                                Flexible(
                                                                  child: Builder(
                                                                    builder: (context) {
                                                                      final String label;
                                                                      if (topic.pageId != null) {
                                                                        final slideNo = (topic.pagePosition ?? 0) + 1;
                                                                        label = '${topic.courseTitle ?? "Lesson"} > ${topic.chapterTitle ?? ""} > ${topic.subChapterTitle ?? ""} > Slide $slideNo';
                                                                      } else if (topic.subChapterId != null) {
                                                                        label = '${topic.courseTitle ?? "Lesson"} > ${topic.chapterTitle ?? ""} > ${topic.subChapterTitle ?? ""}';
                                                                      } else if (topic.chapterId != null) {
                                                                        label = '${topic.courseTitle ?? "Lesson"} > ${topic.chapterTitle ?? ""}';
                                                                      } else {
                                                                        label = topic.courseTitle ?? "Lesson";
                                                                      }
                                                                      return Text(
                                                                        label,
                                                                        style: const TextStyle(
                                                                          fontSize: 9,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: Colors.blue,
                                                                        ),
                                                                        overflow: TextOverflow.ellipsis,
                                                                      );
                                                                    }
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ] else if (topic.quizId != null) ...[
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(right: 8.0),
                                                        child: InkWell(
                                                          onTap: () {
                                                            String path = '/quiz/${topic.quizId}/take?preview=true';
                                                            if (topic.questionId != null) {
                                                              path += '&initialQuestionId=${topic.questionId}';
                                                            }
                                                            context.push(path);
                                                          },
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.amber.shade50,
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: Colors.amber.shade200),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(Icons.assignment_turned_in_rounded, size: 12, color: Colors.amber.shade900),
                                                                const SizedBox(width: 4),
                                                                Flexible(
                                                                  child: Builder(
                                                                    builder: (context) {
                                                                      final label = topic.questionId != null
                                                                          ? '${topic.quizTitle ?? "Quiz"} > ${topic.questionText ?? "Question"}'
                                                                          : (topic.quizTitle ?? "Quiz");
                                                                      return Text(
                                                                        label,
                                                                        style: TextStyle(
                                                                          fontSize: 9,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: Colors.amber.shade900,
                                                                        ),
                                                                        overflow: TextOverflow.ellipsis,
                                                                      );
                                                                    }
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ] else if (topic.deckId != null) ...[
                                                    Expanded(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(right: 8.0),
                                                        child: InkWell(
                                                          onTap: () {
                                                            if (topic.cardId != null) {
                                                              _showCardPreview(context, topic.deckId!, topic.cardId!);
                                                            } else {
                                                              context.push('/flashcard-deck/${topic.deckId}/details');
                                                            }
                                                          },
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.deepPurple.shade50,
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: Colors.deepPurple.shade200),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.style, size: 12, color: Colors.deepPurple),
                                                                const SizedBox(width: 4),
                                                                Flexible(
                                                                  child: Builder(
                                                                    builder: (context) {
                                                                      final label = topic.cardId != null
                                                                          ? '${topic.deckTitle ?? "Flashcards"} > ${topic.cardQuestionText ?? "Card Question"}'
                                                                          : (topic.deckTitle ?? "Flashcards");
                                                                      return Text(
                                                                        label,
                                                                        style: const TextStyle(
                                                                          fontSize: 9,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: Colors.deepPurple,
                                                                        ),
                                                                        overflow: TextOverflow.ellipsis,
                                                                      );
                                                                    }
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade100,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.grey.shade300),
                                                      ),
                                                      child: Text(
                                                        topic.tag.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.grey.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '$dateStr$editedStr',
                                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                topic.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  height: 1.3,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                topic.content,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              _buildAttachmentIndicator(topic.multimediaType),
                                              const SizedBox(height: 12),
                                              GestureDetector(
                                                onTap: () => UserDetailBottomSheet.show(
                                                  context,
                                                  userId: topic.authorId,
                                                  name: topic.authorName,
                                                  avatarUrl: topic.authorAvatarUrl,
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
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
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
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
        ),
      ),
    );
  }

  void _showCardPreview(BuildContext context, String deckId, String cardId) async {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<FlashcardItem>>(
          future: FlashcardRepository().getFlashcards(deckId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('Failed to load card details.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            }
            final cards = snapshot.data!;
            final cardIndex = cards.indexWhere((c) => c.id == cardId);
            if (cardIndex == -1) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('Card not found in this deck.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            }
            final card = cards[cardIndex];
            return _CardPreviewDialog(card: card, cardIndex: cardIndex, totalCards: cards.length);
          },
        );
      },
    );
  }
}

class _CardPreviewDialog extends StatefulWidget {
  final FlashcardItem card;
  final int cardIndex;
  final int totalCards;
  const _CardPreviewDialog({
    required this.card,
    required this.cardIndex,
    required this.totalCards,
  });

  @override
  State<_CardPreviewDialog> createState() => _CardPreviewDialogState();
}

class _CardPreviewDialogState extends State<_CardPreviewDialog> {
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Card Preview (${widget.cardIndex + 1}/${widget.totalCards})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showBack = !_showBack;
                });
              },
              child: AspectRatio(
                aspectRatio: 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: _showBack ? Colors.deepPurple.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _showBack ? Colors.deepPurple.shade200 : Colors.grey.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0D000000),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showBack ? 'ANSWER' : 'QUESTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _showBack ? Colors.deepPurple : Colors.grey,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Text(
                              _showBack ? widget.card.back : widget.card.front,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _showBack ? Colors.deepPurple.shade900 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to flip',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
