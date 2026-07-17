import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/discussion_models.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../learn/models/flashcard_models.dart';

class MyDiscussionsScreen extends StatefulWidget {
  const MyDiscussionsScreen({super.key});

  @override
  State<MyDiscussionsScreen> createState() => _MyDiscussionsScreenState();
}

class _MyDiscussionsScreenState extends State<MyDiscussionsScreen> {
  bool _isLoading = true;
  List<DiscussionTopic> _myTopics = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMyTopics();
  }

  Future<void> _loadMyTopics() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<DiscussionRepository>();
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        final topics = await repo.getTopics(
          query: _searchQuery,
          authorId: currentUserId,
        );
        if (mounted) {
          setState(() {
            _myTopics = topics;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
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

  Future<void> _deleteTopic(String topicId) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Discussion'),
        content: const Text('Are you sure you want to delete this discussion topic? This action cannot be undone and will delete all replies and votes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final repo = context.read<DiscussionRepository>();
                await repo.deleteTopic(topicId);
                _loadMyTopics();
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete topic: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Discussions'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyTopics,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search bar
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
                        decoration: const InputDecoration(
                          hintText: 'Search my threads...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          _searchQuery = val.trim();
                          _loadMyTopics();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Topics list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _myTopics.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 100),
                                child: Center(
                                  child: Text(
                                    'You haven\'t posted any discussions yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _myTopics.length,
                            itemBuilder: (context, index) {
                              final topic = _myTopics[index];
                              final displayDate = topic.updatedAt ?? topic.createdAt;
                              final dateStr = '${displayDate.day}/${displayDate.month}/${displayDate.year}';
                              final editedStr = topic.updatedAt != null ? ' (edited)' : '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    final result = await context.push('/discussion/${topic.id}');
                                    if (result == true || result == null) {
                                      _loadMyTopics();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (topic.courseId != null) ...[
                                              Flexible(
                                                child: InkWell(
                                                  onTap: () {
                                                    if (topic.subChapterId != null) {
                                                      context.push('/lesson-player?subChapterId=${topic.subChapterId}&isPreview=true&initialPageId=${topic.pageId}');
                                                    } else {
                                                      context.push('/?selectedCourseId=${topic.courseId}');
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
                                                                label = topic.courseTitle ?? 'Lesson';
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
                                            ] else if (topic.quizId != null) ...[
                                              Flexible(
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
                                            ] else if (topic.deckId != null) ...[
                                              Flexible(
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
                                            // Edit/Delete options menu
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onSelected: (val) async {
                                                if (val == 'edit') {
                                                  final result = await context.push(
                                                    '/create-topic',
                                                    extra: {'topic': topic},
                                                  );
                                                  if (result == true) {
                                                    _loadMyTopics();
                                                  }
                                                } else if (val == 'delete') {
                                                  _deleteTopic(topic.id);
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit, size: 16, color: Colors.grey),
                                                      SizedBox(width: 8),
                                                      Text('Edit'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete, size: 16, color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                              ],
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
                                        if (topic.attachments.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 8),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.attach_file, color: Colors.deepPurple, size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${topic.attachments.length} attachment(s)',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.bold,
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
