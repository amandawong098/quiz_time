import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../../data/repositories/discussion_repository.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/models/discussion_models.dart';

class DiscussionsDummyScreen extends StatefulWidget {
  const DiscussionsDummyScreen({super.key});

  @override
  State<DiscussionsDummyScreen> createState() => _DiscussionsDummyScreenState();
}

class _DiscussionsDummyScreenState extends State<DiscussionsDummyScreen> {
  bool _isLoading = true;
  List<DiscussionTopic> _topics = [];

  String _searchQuery = '';
  String _activeTag = 'All Discussions';
  final List<String> _tags = ['All Discussions', 'General'];

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _loadTopics();
  }

  Future<void> _loadLessons() async {
    try {
      final courses = await LessonRepository().getCourses();
      if (mounted) {
        setState(() {
          _tags.clear();
          _tags.addAll(['All Discussions', 'General']);
          _tags.addAll(courses.map((c) => c.title));
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<DiscussionRepository>();
      final results = await repo.getTopics(
        query: _searchQuery,
        tag: _activeTag,
      );
      if (mounted) {
        setState(() {
          _topics = results;
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
      // Reload topics list to reflect fresh vote count calculations
      final results = await repo.getTopics(
        query: _searchQuery,
        tag: _activeTag,
      );
      if (mounted) {
        setState(() {
          _topics = results;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote failed: $e')),
      );
    }
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
                        decoration: const InputDecoration(
                          hintText: 'Search forum threads...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          _searchQuery = val.trim();
                          _loadTopics();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Horizontal Categories chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tags.map((tag) {
                    final isActive = _activeTag == tag;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: isActive,
                        selectedColor: Colors.deepPurple.shade100,
                        checkmarkColor: Colors.deepPurple,
                        labelStyle: TextStyle(
                          color: isActive ? Colors.deepPurple.shade900 : null,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _activeTag = tag);
                            _loadTopics();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
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
                                                  if (topic.subChapterTitle != null) ...[
                                                    Flexible(
                                                      child: InkWell(
                                                        onTap: () {
                                                          if (topic.subChapterId != null) {
                                                            context.push('/lesson-player?subChapterId=${topic.subChapterId}&isPreview=true&initialPageId=${topic.pageId}');
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
                                                              const Icon(Icons.slideshow_rounded, size: 12, color: Colors.deepPurple),
                                                              const SizedBox(width: 4),
                                                              Flexible(
                                                                child: Builder(
                                                                  builder: (context) {
                                                                    final slideNo = (topic.pagePosition ?? 0) + 1;
                                                                    return Text(
                                                                      '${topic.courseTitle ?? "Lesson"} > ${topic.chapterTitle ?? ""} > ${topic.subChapterTitle ?? ""} > Slide $slideNo',
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
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
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
}
