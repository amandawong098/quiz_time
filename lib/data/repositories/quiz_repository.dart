import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_models.dart';

class QuizRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch all public quizzes AND user's own private quizzes (for Discover)
  Future<List<Quiz>> getPublicQuizzes({
    String? query,
    String? questionRange,
  }) async {
    var req = _supabase
        .from('quizzes')
        .select('*, questions(id)');
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) {
      req = req.or('is_public.eq.true,creator_id.eq.$uid');
    } else {
      req = req.eq('is_public', true);
    }

    if (query != null && query.isNotEmpty) {
      req = req.ilike('title', '%$query%');
    }
    if (questionRange != null &&
        questionRange.isNotEmpty &&
        questionRange != 'Any') {
      if (questionRange == '1-5') {
        req = req.gte('question_count', 1).lte('question_count', 5);
      } else if (questionRange == '5-10') {
        req = req.gte('question_count', 5).lte('question_count', 10);
      } else if (questionRange == '10-20') {
        req = req.gte('question_count', 10).lte('question_count', 20);
      } else if (questionRange == '>20') {
        req = req.gt('question_count', 20);
      }
    }

    final response = await req.order('created_at', ascending: false);
    final List<Quiz> quizzes =
        (response as List).map((e) => Quiz.fromJson(e)).toList();

    final creatorIds =
        quizzes.map((q) => q.creatorId).where((id) => id.isNotEmpty).toSet().toList();

    if (creatorIds.isNotEmpty) {
      try {
        final profilesRes = await _supabase
            .from('profiles')
            .select('id, name, avatar_url')
            .inFilter('id', creatorIds);
        final Map<String, Map<String, dynamic>> profileMap = {
          for (var p in (profilesRes as List))
            p['id'] as String: p as Map<String, dynamic>
        };

        for (var i = 0; i < quizzes.length; i++) {
          final p = profileMap[quizzes[i].creatorId];
          if (p != null) {
            quizzes[i] = Quiz(
              id: quizzes[i].id,
              creatorId: quizzes[i].creatorId,
              title: quizzes[i].title,
              description: quizzes[i].description,
              isPublic: quizzes[i].isPublic,
              imageUrl: quizzes[i].imageUrl,
              createdAt: quizzes[i].createdAt,
              questionCount: quizzes[i].questionCount,
              creatorName: p['name'] as String?,
              creatorAvatarUrl: p['avatar_url'] as String?,
            );
          }
        }
      } catch (_) {}
    }
    return quizzes;
  }

  // Fetch quizzes created by current user
  Future<List<Quiz>> getMyQuizzes({
    String? query,
    String? questionRange,
    bool? isPublic,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    var req = _supabase
        .from('quizzes')
        .select('*, questions(id)')
        .eq('creator_id', uid);

    if (isPublic != null) {
      req = req.eq('is_public', isPublic);
    }

    if (query != null && query.isNotEmpty) {
      req = req.ilike('title', '%$query%');
    }
    if (questionRange != null &&
        questionRange.isNotEmpty &&
        questionRange != 'Any') {
      if (questionRange == '1-5') {
        req = req.gte('question_count', 1).lte('question_count', 5);
      } else if (questionRange == '5-10') {
        req = req.gte('question_count', 5).lte('question_count', 10);
      } else if (questionRange == '10-20') {
        req = req.gte('question_count', 10).lte('question_count', 20);
      } else if (questionRange == '>20') {
        req = req.gt('question_count', 20);
      }
    }

    final response = await req.order('created_at', ascending: false);
    return (response as List).map((e) => Quiz.fromJson(e)).toList();
  }

  // Fetch full quiz with questions and options
  Future<Map<String, dynamic>> getQuizDetails(String quizId) async {
    final response = await _supabase
        .from('quizzes')
        .select('*, questions(*, options(*))')
        .eq('id', quizId)
        .single();

    Quiz quiz = Quiz.fromJson(response);
    List<Question> questions = (response['questions'] as List)
        .map((q) => Question.fromJson(q))
        .toList();
    questions.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return {'quiz': quiz, 'questions': questions};
  }

  // Create a new quiz
  Future<String> createQuiz(Quiz quiz) async {
    final response = await _supabase
        .from('quizzes')
        .insert({
          'creator_id': _supabase.auth.currentUser!.id,
          ...quiz.toJson(),
        })
        .select()
        .single();
    return response['id'];
  }

  // Update a quiz
  Future<void> updateQuiz(Quiz quiz) async {
    await _supabase.from('quizzes').update(quiz.toJson()).eq('id', quiz.id);
  }

  // Delete a quiz
  Future<void> deleteQuiz(String quizId) async {
    await _supabase.from('quizzes').delete().eq('id', quizId);
  }

  // Save questions and options
  Future<void> saveQuestions(String quizId, List<Question> questions) async {
    // Get existing questions in database for this quiz
    final existingResponse = await _supabase
        .from('questions')
        .select('id')
        .eq('quiz_id', quizId);
    final existingIds = (existingResponse as List)
        .map((e) => e['id'] as String)
        .toSet();

    // Identify which questions to delete
    final newIds =
        questions.map((q) => q.id).where((id) => id.isNotEmpty).toSet();
    final idsToDelete =
        existingIds.where((id) => !newIds.contains(id)).toList();

    // Delete questions that were removed
    if (idsToDelete.isNotEmpty) {
      await _supabase.from('questions').delete().inFilter('id', idsToDelete);
    }

    final existingToUpdate = <({int index, Question question})>[];
    final newToInsert = <({int index, Question question})>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (q.id.isNotEmpty && existingIds.contains(q.id)) {
        existingToUpdate.add((index: i, question: q));
      } else {
        newToInsert.add((index: i, question: q));
      }
    }

    final allOptionRows = <Map<String, dynamic>>[];
    final pendingTasks = <Future<dynamic>>[];

    // 1. Update existing questions in parallel and bulk-delete their old options
    if (existingToUpdate.isNotEmpty) {
      final updatedQuestionIds =
          existingToUpdate.map((entry) => entry.question.id).toList();

      pendingTasks.add(
        _supabase
            .from('options')
            .delete()
            .inFilter('question_id', updatedQuestionIds),
      );

      for (final entry in existingToUpdate) {
        final q = entry.question;
        pendingTasks.add(
          _supabase.from('questions').update({
            'question_text': q.questionText,
            'duration_seconds': q.durationSeconds,
            'order_index': entry.index,
            'explanation': q.explanation,
          }).eq('id', q.id),
        );

        for (final opt in q.options) {
          allOptionRows.add({
            'question_id': q.id,
            'option_text': opt.optionText,
            'is_correct': opt.isCorrect,
          });
        }
      }
    }

    // 2. Bulk-insert all new questions in one request
    Future<List<dynamic>>? insertQuestionsFuture;
    if (newToInsert.isNotEmpty) {
      final newPayloads = newToInsert.map((entry) {
        final q = entry.question;
        return {
          'quiz_id': quizId,
          'question_text': q.questionText,
          'duration_seconds': q.durationSeconds,
          'order_index': entry.index,
          'explanation': q.explanation,
        };
      }).toList();

      insertQuestionsFuture = _supabase
          .from('questions')
          .insert(newPayloads)
          .select('id, order_index');
      pendingTasks.add(insertQuestionsFuture);
    }

    if (pendingTasks.isNotEmpty) {
      await Future.wait(pendingTasks);
    }

    if (insertQuestionsFuture != null) {
      final insertedRows = await insertQuestionsFuture;
      final idByOrderIndex = <int, String>{
        for (final row in insertedRows)
          row['order_index'] as int: row['id'] as String,
      };

      for (final entry in newToInsert) {
        final newQuestionId = idByOrderIndex[entry.index];
        if (newQuestionId == null) continue;
        for (final opt in entry.question.options) {
          allOptionRows.add({
            'question_id': newQuestionId,
            'option_text': opt.optionText,
            'is_correct': opt.isCorrect,
          });
        }
      }
    }

    // 3. Bulk-insert all options across all questions in one request
    if (allOptionRows.isNotEmpty) {
      await _supabase.from('options').insert(allOptionRows);
    }

    // 4. Sync question_count column in quizzes table
    await _supabase
        .from('quizzes')
        .update({'question_count': questions.length})
        .eq('id', quizId);
  }

  // Fetch attempts for a specific quiz for the current user
  Future<List<QuizAttempt>> getQuizAttempts(String quizId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final response = await _supabase
        .from('quiz_attempts')
        .select()
        .eq('quiz_id', quizId)
        .eq('user_id', uid)
        .order('created_at', ascending: true);
    return (response as List).map((e) => QuizAttempt.fromJson(e)).toList();
  }

  // Fetch all attempts for the current user across all quizzes
  Future<List<Map<String, dynamic>>> getAllQuizAttempts({
    String? query,
    String? questionRange,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    var req = _supabase
        .from('quiz_attempts')
        .select('*, quizzes!inner(*)')
        .eq('user_id', uid);

    if (query != null && query.isNotEmpty) {
      req = req.ilike('quizzes.title', '%$query%');
    }
    if (questionRange != null &&
        questionRange.isNotEmpty &&
        questionRange != 'Any') {
      if (questionRange == '1-5') {
        req = req
            .gte('quizzes.question_count', 1)
            .lte('quizzes.question_count', 5);
      } else if (questionRange == '5-10') {
        req = req
            .gte('quizzes.question_count', 5)
            .lte('quizzes.question_count', 10);
      } else if (questionRange == '10-20') {
        req = req
            .gte('quizzes.question_count', 10)
            .lte('quizzes.question_count', 20);
      } else if (questionRange == '>20') {
        req = req.gt('quizzes.question_count', 20);
      }
    }

    final response = await req.order('created_at', ascending: false);
    return (response as List)
        .map((e) {
          return e as Map<String, dynamic>;
        })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Save a new attempt
  Future<String> saveQuizAttempt(QuizAttempt attempt) async {
    final response = await _supabase
        .from('quiz_attempts')
        .insert({
          ...attempt.toJson(),
          'user_id': _supabase.auth.currentUser!.id,
        })
        .select()
        .single();
    return response['id'];
  }

  // Search subjects by name (for autocomplete)
  Future<List<String>> searchSubjects(String query) async {
    final response = await _supabase
        .from('subjects')
        .select('name')
        .ilike('name', '%$query%')
        .order('name')
        .limit(10);
    return (response as List).map((e) => e['name'] as String).toList();
  }

  // Get all subjects (for initial load / filter bar)
  Future<List<String>> getSubjects() async {
    final response = await _supabase
        .from('subjects')
        .select('name')
        .order('name');
    return (response as List).map((e) => e['name'] as String).toList();
  }

  // Create a new subject
  Future<void> createSubject(String name) async {
    await _supabase.from('subjects').insert({'name': name.trim()});
  }
}
