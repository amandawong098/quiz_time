import 'dart:io';
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
    String? quizId,
    String? questionId,
  }) async {
    var req = _supabase
        .from('discussion_topics')
        .select('*, profiles(*), topic_votes(*), lesson_courses(title), lesson_chapters(title), lesson_sub_chapters(title), lesson_pages(position), quizzes(title), questions(question_text, order_index)');

    if (authorId != null) {
      req = req.eq('author_id', authorId);
    }
    if (pageId != null) {
      req = req.eq('page_id', pageId);
    }
    if (quizId != null) {
      req = req.eq('quiz_id', quizId);
    }
    if (questionId != null) {
      req = req.eq('question_id', questionId);
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
        .select('*, profiles(*), topic_votes(*), lesson_courses(title), lesson_chapters(title), lesson_sub_chapters(title), lesson_pages(position), quizzes(title), questions(question_text, order_index)')
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

  // Insert topic row with multiple attachments support
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

  // Get general discussions count for a quiz (where question_id is null)
  Future<int> getQuizGeneralDiscussionsCount(String quizId) async {
    final response = await _supabase
        .from('discussion_topics')
        .select('id')
        .eq('quiz_id', quizId)
        .isFilter('question_id', null);
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

    return response['id'] as String;
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
  }) async {
    await _supabase
        .from('discussion_topics')
        .update({
          'title': title,
          'content': content,
          'tag': tag,
          'attachments': attachments.map((e) => e.toJson()).toList(),
          'course_id': courseId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', topicId);
  }

  // Delete a discussion topic row
  Future<void> deleteTopic(String topicId) async {
    await _supabase
        .from('discussion_topics')
        .delete()
        .eq('id', topicId);
  }
}
