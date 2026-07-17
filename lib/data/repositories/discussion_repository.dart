import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/discussion_models.dart';

class DiscussionRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _currentUserId => _supabase.auth.currentUser!.id;

  // Fetch topics joined with author profile and votes
  // Fetch topics joined with author profile and votes
  Future<List<DiscussionTopic>> getTopics({
    String? query,
    String? tag,
    String? authorId,
    String? pageId,
    String? courseId,
    String? quizId,
    String? questionId,
    String? deckId,
    String? cardId,
  }) async {
    var req = _supabase
        .from('discussion_topics')
        .select('*, profiles(*), topic_votes(*), lesson_courses(title), lesson_chapters(title), lesson_sub_chapters(title), lesson_pages(position), quizzes(title), questions(question_text, order_index), flashcard_decks(title), flashcards(front)');

    if (authorId != null) {
      req = req.eq('author_id', authorId);
    }
    if (pageId != null) {
      req = req.eq('page_id', pageId);
    }
    if (courseId != null) {
      req = req.eq('course_id', courseId);
    }
    if (quizId != null) {
      req = req.eq('quiz_id', quizId);
    }
    if (questionId != null) {
      req = req.eq('question_id', questionId);
    }
    if (deckId != null) {
      req = req.eq('deck_id', deckId);
    }
    if (cardId != null) {
      req = req.eq('card_id', cardId);
    }
    if (query != null && query.isNotEmpty) {
      req = req.or('title.ilike.%$query%,content.ilike.%$query%');
    }
    if (tag != null && tag.isNotEmpty && tag != 'All Discussions') {
      req = req.eq('tag', tag);
    }

    final response = await req.order('created_at', ascending: false);
    return (response as List)
        .map((e) => DiscussionTopic.fromJson(e, _currentUserId))
        .toList();
  }

  // Fetch details of a single topic
  Future<DiscussionTopic> getTopicDetails(String topicId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('*, profiles(*), topic_votes(*), lesson_courses(title), lesson_chapters(title), lesson_sub_chapters(title), lesson_pages(position), quizzes(title), questions(question_text, order_index), flashcard_decks(title), flashcards(front)')
        .eq('id', topicId)
        .single();

    return DiscussionTopic.fromJson(response, _currentUserId);
  }

  // Fetch replies joined with profiles and votes
  Future<List<DiscussionReply>> getReplies(String topicId) async {
    final response = await _supabase
        .from('discussion_replies')
        .select('*, profiles(*), reply_votes(*)')
        .eq('topic_id', topicId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((e) => DiscussionReply.fromJson(e, _currentUserId))
        .toList();
  }

  Future<String> createTopic({
    required String title,
    required String content,
    required String tag,
    required List<DiscussionAttachment> attachments,
    String? courseId,
    String? chapterId,
    String? subChapterId,
    String? pageId,
    String? quizId,
    String? questionId,
    String? deckId,
    String? cardId,
  }) async {
    final response = await _supabase
        .from('discussion_topics')
        .insert({
          'author_id': _currentUserId,
          'title': title,
          'content': content,
          'tag': tag,
          'attachments': attachments.map((e) => e.toJson()).toList(),
          'course_id': courseId,
          'chapter_id': chapterId,
          'sub_chapter_id': subChapterId,
          'page_id': pageId,
          'quiz_id': quizId,
          'question_id': questionId,
          'deck_id': deckId,
          'card_id': cardId,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  // Get post counts for all pages inside a subchapter in a single query
  Future<Map<String, int>> getPageDiscussionsCount(String subChapterId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('page_id')
        .eq('sub_chapter_id', subChapterId);
    
    final Map<String, int> counts = {};
    final list = response as List;
    for (var row in list) {
      final pageId = row['page_id'] as String?;
      if (pageId != null) {
        counts[pageId] = (counts[pageId] ?? 0) + 1;
      }
    }
    return counts;
  }

  // Get post counts for all questions inside a quiz in a single query
  Future<Map<String, int>> getQuizQuestionsDiscussionsCount(String quizId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('question_id')
        .eq('quiz_id', quizId);
    
    final Map<String, int> counts = {};
    final list = response as List;
    for (var row in list) {
      final qId = row['question_id'] as String?;
      if (qId != null) {
        counts[qId] = (counts[qId] ?? 0) + 1;
      }
    }
    return counts;
  }

  // Get general discussions count for a lesson/course (where page_id, chapter_id, sub_chapter_id are null)
  Future<int> getCourseGeneralDiscussionsCount(String courseId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('id')
        .eq('course_id', courseId)
        .isFilter('page_id', null)
        .isFilter('chapter_id', null)
        .isFilter('sub_chapter_id', null);
    return (response as List).length;
  }

  // Get total discussions count for a lesson/course (both general and page-specific)
  Future<int> getCourseTotalDiscussionsCount(String courseId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('id')
        .eq('course_id', courseId);
    return (response as List).length;
  }

  // Get total discussions count for a quiz (both general and question-specific)
  Future<int> getQuizTotalDiscussionsCount(String quizId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('id')
        .eq('quiz_id', quizId);
    return (response as List).length;
  }

  // Insert reply row with multiple attachments support
  Future<String> createReply({
    required String topicId,
    required String content,
    required List<DiscussionAttachment> attachments,
    String? parentId,
    String? replyToId,
  }) async {
    final response = await _supabase
        .from('discussion_replies')
        .insert({
          'topic_id': topicId,
          'author_id': _currentUserId,
          'content': content,
          'attachments': attachments.map((e) => e.toJson()).toList(),
          'parent_id': parentId,
          'reply_to_id': replyToId,
        })
        .select()
        .single();

    final String replyId = response['id'] as String;

    _sendReplyNotification(
      topicId: topicId,
      parentId: parentId,
      replyToId: replyToId,
    ).catchError((e) {
      debugPrint('Error sending reply notification: $e');
    });

    return replyId;
  }

  // Update a reply row
  Future<void> updateReply({
    required String replyId,
    required String content,
    required List<DiscussionAttachment> attachments,
  }) async {
    await _supabase
        .from('discussion_replies')
        .update({
          'content': content,
          'attachments': attachments.map((e) => e.toJson()).toList(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', replyId);
  }

  // Delete a reply row
  Future<void> deleteReply(String replyId) async {
    await _supabase
        .from('discussion_replies')
        .delete()
        .eq('id', replyId);
  }

  // Upvote / downvote topic vote logic (with toggling & retract capability)
  Future<void> voteTopic(String topicId, int voteType) async {
    final existing = await _supabase
        .from('topic_votes')
        .select()
        .eq('topic_id', topicId)
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (existing != null) {
      final int prevVote = existing['vote_type'] as int;
      if (prevVote == voteType) {
        // Retract vote (toggle off)
        await _supabase
            .from('topic_votes')
            .delete()
            .eq('topic_id', topicId)
            .eq('user_id', _currentUserId);
      } else {
        // Change vote type (e.g. upvote to downvote)
        await _supabase
            .from('topic_votes')
            .update({'vote_type': voteType})
            .eq('topic_id', topicId)
            .eq('user_id', _currentUserId);
      }
    } else {
      // Create new vote
      await _supabase.from('topic_votes').insert({
        'topic_id': topicId,
        'user_id': _currentUserId,
        'vote_type': voteType,
      });
    }

    if (voteType == 1) {
      final bool shouldNotify = existing == null || (existing['vote_type'] as int) != 1;
      if (shouldNotify) {
        try {
          final topicData = await _supabase
              .from('discussion_topics')
              .select('author_id, title')
              .eq('id', topicId)
              .single();
          final authorId = topicData['author_id'] as String;
          final title = topicData['title'] as String;
          if (authorId != _currentUserId) {
            final voterName = await _getCurrentUserName();
            await _createNotification(
              targetUserId: authorId,
              title: 'Discussion Upvoted',
              message: '$voterName upvoted your discussion: $title',
              type: 'discussion_upvote',
              data: {'topic_id': topicId},
            );
          }
        } catch (e) {
          debugPrint('Error processing upvote notification: $e');
        }
      }
    }
  }

  // Upvote / downvote reply vote logic (with toggling & retract capability)
  Future<void> voteReply(String replyId, int voteType) async {
    final existing = await _supabase
        .from('reply_votes')
        .select()
        .eq('reply_id', replyId)
        .eq('user_id', _currentUserId)
        .maybeSingle();

    if (existing != null) {
      final int prevVote = existing['vote_type'] as int;
      if (prevVote == voteType) {
        // Retract vote (toggle off)
        await _supabase
            .from('reply_votes')
            .delete()
            .eq('reply_id', replyId)
            .eq('user_id', _currentUserId);
      } else {
        // Change vote type
        await _supabase
            .from('reply_votes')
            .update({'vote_type': voteType})
            .eq('reply_id', replyId)
            .eq('user_id', _currentUserId);
      }
    } else {
      // Create new vote
      await _supabase.from('reply_votes').insert({
        'reply_id': replyId,
        'user_id': _currentUserId,
        'vote_type': voteType,
      });
    }

    if (voteType == 1) {
      final bool shouldNotify = existing == null || (existing['vote_type'] as int) != 1;
      if (shouldNotify) {
        try {
          final replyData = await _supabase
              .from('discussion_replies')
              .select('author_id, content, topic_id')
              .eq('id', replyId)
              .single();
          final authorId = replyData['author_id'] as String;
          final content = replyData['content'] as String;
          final topicId = replyData['topic_id'] as String;
          if (authorId != _currentUserId) {
            final voterName = await _getCurrentUserName();
            final snippet = content.length > 30 ? '${content.substring(0, 30)}...' : content;
            await _createNotification(
              targetUserId: authorId,
              title: 'Comment Upvoted',
              message: '$voterName upvoted your comment: "$snippet"',
              type: 'comment_upvote',
              data: {'topic_id': topicId},
            );
          }
        } catch (e) {
          debugPrint('Error processing reply upvote notification: $e');
        }
      }
    }
  }

  // Upload custom file / media to Supabase storage bucket
  Future<String> uploadAttachment(String filePath, String fileName) async {
    final file = File(filePath);
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    
    await _supabase.storage
        .from('discussion_attachments')
        .upload(uniqueName, file);

    return _supabase.storage
        .from('discussion_attachments')
        .getPublicUrl(uniqueName);
  }

  // Update a discussion topic row
  Future<void> updateTopic({
    required String topicId,
    required String title,
    required String content,
    required String tag,
    required List<DiscussionAttachment> attachments,
    String? courseId,
    String? chapterId,
    String? subChapterId,
    String? pageId,
    String? deckId,
    String? cardId,
  }) async {
    await _supabase
        .from('discussion_topics')
        .update({
          'title': title,
          'content': content,
          'tag': tag,
          'attachments': attachments.map((e) => e.toJson()).toList(),
          'course_id': courseId,
          'chapter_id': chapterId,
          'sub_chapter_id': subChapterId,
          'page_id': pageId,
          'deck_id': deckId,
          'card_id': cardId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', topicId);
  }

  // Get total discussions count for a flashcard deck
  Future<int> getDeckTotalDiscussionsCount(String deckId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('id')
        .eq('deck_id', deckId);
    return (response as List).length;
  }

  // Get post counts for all cards inside a deck in a single query
  Future<Map<String, int>> getDeckCardsDiscussionsCount(String deckId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('card_id')
        .eq('deck_id', deckId);
    
    final Map<String, int> counts = {};
    final list = response as List;
    for (var row in list) {
      final cardId = row['card_id'] as String?;
      if (cardId != null) {
        counts[cardId] = (counts[cardId] ?? 0) + 1;
      }
    }
    return counts;
  }

  // Delete a discussion topic row
  Future<void> deleteTopic(String topicId) async {
    await _supabase
        .from('discussion_topics')
        .delete()
        .eq('id', topicId);
  }

  Future<String> _getCurrentUserName() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('name')
          .eq('id', _currentUserId)
          .single();
      return res['name'] as String? ?? 'Someone';
    } catch (_) {
      return 'Someone';
    }
  }

  Future<void> _createNotification({
    required String targetUserId,
    required String title,
    required String message,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    if (targetUserId == _currentUserId) return;
    
    final payload = {
      'user_id': targetUserId,
      'title': title,
      'message': message,
      'is_read': false,
    };
    
    if (type != null) {
      payload['type'] = type;
    }
    if (data != null) {
      payload['data'] = data;
    }

    try {
      await _supabase.from('notifications').insert(payload);
    } catch (e) {
      if (e.toString().contains("column") && e.toString().contains("does not exist")) {
        try {
          payload.remove('type');
          payload.remove('data');
          await _supabase.from('notifications').insert(payload);
        } catch (e2) {
          debugPrint('Error inserting fallback notification: $e2');
        }
      } else {
        debugPrint('Error inserting notification: $e');
      }
    }
  }

  Future<void> _sendReplyNotification({
    required String topicId,
    String? parentId,
    String? replyToId,
  }) async {
    final replierName = await _getCurrentUserName();

    if (parentId == null && replyToId == null) {
      // Direct reply to the topic
      final topicData = await _supabase
          .from('discussion_topics')
          .select('author_id, title')
          .eq('id', topicId)
          .single();
      final authorId = topicData['author_id'] as String;
      final topicTitle = topicData['title'] as String;

      if (authorId != _currentUserId) {
        await _createNotification(
          targetUserId: authorId,
          title: 'New Reply on Topic',
          message: '$replierName replied to your topic: "$topicTitle"',
          type: 'discussion_reply',
          data: {'topic_id': topicId},
        );
      }
    } else {
      // Reply to a comment/nested reply
      final targetId = replyToId ?? parentId!;
      final targetData = await _supabase
          .from('discussion_replies')
          .select('author_id, content')
          .eq('id', targetId)
          .single();
      final targetAuthorId = targetData['author_id'] as String;
      final targetContent = targetData['content'] as String;

      if (targetAuthorId != _currentUserId) {
        final snippet = targetContent.length > 30 
            ? '${targetContent.substring(0, 30)}...' 
            : targetContent;
        await _createNotification(
          targetUserId: targetAuthorId,
          title: 'New Reply on Comment',
          message: '$replierName replied to your comment: "$snippet"',
          type: 'comment_reply',
          data: {'topic_id': topicId},
        );
      }
    }
  }
}
