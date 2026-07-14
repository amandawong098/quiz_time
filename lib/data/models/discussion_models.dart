class DiscussionAttachment {
  final String url;
  final String name;
  final String type; // 'image', 'video', 'gif', 'link', 'file'

  DiscussionAttachment({
    required this.url,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'type': type,
      };

  factory DiscussionAttachment.fromJson(Map<String, dynamic> json) {
    return DiscussionAttachment(
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? 'Attachment',
      type: json['type'] as String? ?? 'file',
    );
  }
}

class DiscussionTopic {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String title;
  final String content;
  final String tag;
  final List<DiscussionAttachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Lesson specific references (nullable)
  final String? courseId;
  final String? chapterId;
  final String? subChapterId;
  final String? pageId;

  // Quiz specific references (nullable)
  final String? quizId;
  final String? questionId;

  // Flashcard specific references (nullable)
  final String? deckId;
  final String? cardId;

  // Joined metadata titles and positions
  final String? courseTitle;
  final String? chapterTitle;
  final String? subChapterTitle;
  final int? pagePosition;

  // Joined quiz metadata
  final String? quizTitle;
  final String? questionText;
  final int? questionOrderIndex;

  // Joined flashcard metadata
  final String? deckTitle;
  final String? cardQuestionText;

  // Computed properties
  final int upvotesCount;
  final int downvotesCount;
  final int userVoteType; // 1 = upvote, -1 = downvote, 0 = none

  int get score => upvotesCount - downvotesCount;

  String? get multimediaType => attachments.isNotEmpty ? attachments.first.type : null;

  DiscussionTopic({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.title,
    required this.content,
    required this.tag,
    required this.attachments,
    required this.createdAt,
    required this.upvotesCount,
    required this.downvotesCount,
    required this.userVoteType,
    this.updatedAt,
    this.courseId,
    this.chapterId,
    this.subChapterId,
    this.pageId,
    this.quizId,
    this.questionId,
    this.deckId,
    this.cardId,
    this.courseTitle,
    this.chapterTitle,
    this.subChapterTitle,
    this.pagePosition,
    this.quizTitle,
    this.questionText,
    this.questionOrderIndex,
    this.deckTitle,
    this.cardQuestionText,
  });

  factory DiscussionTopic.fromJson(Map<String, dynamic> json, String currentUserId) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final votesList = json['topic_votes'] as List? ?? [];
    
    int upvotes = 0;
    int downvotes = 0;
    int currentUserVote = 0;

    for (var v in votesList) {
      final voteType = v['vote_type'] as int;
      final userId = v['user_id'] as String;
      if (voteType == 1) {
        upvotes++;
      } else if (voteType == -1) {
        downvotes++;
      }
      if (userId == currentUserId) {
        currentUserVote = voteType;
      }
    }

    // Parse attachments (with backward compatibility)
    final attachmentsList = json['attachments'] as List? ?? [];
    final List<DiscussionAttachment> parsedAttachments = attachmentsList
        .map((e) => DiscussionAttachment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final legacyUrl = json['multimedia_url'] as String?;
    final legacyType = json['multimedia_type'] as String?;
    final legacyName = json['attachment_name'] as String?;

    if (parsedAttachments.isEmpty && legacyUrl != null && legacyType != null) {
      parsedAttachments.add(DiscussionAttachment(
        url: legacyUrl,
        name: legacyName ?? 'Attachment',
        type: legacyType,
      ));
    }

    final courseData = json['lesson_courses'] as Map<String, dynamic>?;
    final chapterData = json['lesson_chapters'] as Map<String, dynamic>?;
    final subChapterData = json['lesson_sub_chapters'] as Map<String, dynamic>?;
    final pageData = json['lesson_pages'] as Map<String, dynamic>?;
    final quizData = json['quizzes'] as Map<String, dynamic>?;
    final questionData = json['questions'] as Map<String, dynamic>?;
    final deckData = json['flashcard_decks'] as Map<String, dynamic>?;
    final cardData = json['flashcards'] as Map<String, dynamic>?;

    return DiscussionTopic(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: profile?['name'] as String? ?? 'User Name',
      authorAvatarUrl: profile?['avatar_url'] as String?,
      title: json['title'] as String,
      content: json['content'] as String,
      tag: json['tag'] as String? ?? 'General',
      attachments: parsedAttachments,
      createdAt: DateTime.parse(json['created_at'] as String),
      upvotesCount: upvotes,
      downvotesCount: downvotes,
      userVoteType: currentUserVote,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      courseId: json['course_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      subChapterId: json['sub_chapter_id'] as String?,
      pageId: json['page_id'] as String?,
      quizId: json['quiz_id'] as String?,
      questionId: json['question_id'] as String?,
      deckId: json['deck_id'] as String?,
      cardId: json['card_id'] as String?,
      courseTitle: courseData?['title'] as String?,
      chapterTitle: chapterData?['title'] as String?,
      subChapterTitle: subChapterData?['title'] as String?,
      pagePosition: pageData?['position'] as int?,
      quizTitle: quizData?['title'] as String?,
      questionText: questionData?['question_text'] as String?,
      questionOrderIndex: questionData?['order_index'] as int?,
      deckTitle: deckData?['title'] as String?,
      cardQuestionText: cardData?['front'] as String?,
    );
  }
}

class DiscussionReply {
  final String id;
  final String topicId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String content;
  final List<DiscussionAttachment> attachments;
  final DateTime createdAt;
  final String? parentId;
  final String? replyToId;
  final DateTime? updatedAt;
  
  // Computed properties
  final int upvotesCount;
  final int downvotesCount;
  final int userVoteType; // 1 = upvote, -1 = downvote, 0 = none

  int get score => upvotesCount - downvotesCount;

  DiscussionReply({
    required this.id,
    required this.topicId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.content,
    required this.attachments,
    required this.createdAt,
    required this.upvotesCount,
    required this.downvotesCount,
    required this.userVoteType,
    this.parentId,
    this.replyToId,
    this.updatedAt,
  });

  factory DiscussionReply.fromJson(Map<String, dynamic> json, String currentUserId) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final votesList = json['reply_votes'] as List? ?? [];
    
    int upvotes = 0;
    int downvotes = 0;
    int currentUserVote = 0;

    for (var v in votesList) {
      final voteType = v['vote_type'] as int;
      final userId = v['user_id'] as String;
      if (voteType == 1) {
        upvotes++;
      } else if (voteType == -1) {
        downvotes++;
      }
      if (userId == currentUserId) {
        currentUserVote = voteType;
      }
    }

    // Parse attachments (with backward compatibility)
    final attachmentsList = json['attachments'] as List? ?? [];
    final List<DiscussionAttachment> parsedAttachments = attachmentsList
        .map((e) => DiscussionAttachment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final legacyUrl = json['multimedia_url'] as String?;
    final legacyType = json['multimedia_type'] as String?;
    final legacyName = json['attachment_name'] as String?;

    if (parsedAttachments.isEmpty && legacyUrl != null && legacyType != null) {
      parsedAttachments.add(DiscussionAttachment(
        url: legacyUrl,
        name: legacyName ?? 'Attachment',
        type: legacyType,
      ));
    }

    return DiscussionReply(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      authorId: json['author_id'] as String,
      authorName: profile?['name'] as String? ?? 'User Name',
      authorAvatarUrl: profile?['avatar_url'] as String?,
      content: json['content'] as String,
      attachments: parsedAttachments,
      createdAt: DateTime.parse(json['created_at'] as String),
      upvotesCount: upvotes,
      downvotesCount: downvotes,
      userVoteType: currentUserVote,
      parentId: json['parent_id'] as String?,
      replyToId: json['reply_to_id'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }
}
