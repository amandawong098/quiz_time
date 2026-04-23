import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_models.dart';

class QuizRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch all public quizzes AND user's own private quizzes (for Discover)
  Future<List<Quiz>> getPublicQuizzes({
    String? query,
    String? grade,
    String? subject,
    String? questionRange,
  }) async {
    var req = _supabase
        .from('quizzes')
        .select()
        .or(
          'is_public.eq.true,creator_id.eq.${_supabase.auth.currentUser!.id}',
        );

    if (query != null && query.isNotEmpty) {
      req = req.ilike('title', '%$query%');
    }
    if (grade != null && grade.isNotEmpty && grade != 'All') {
      req = req.eq('grade', grade);
    }
    if (subject != null && subject.isNotEmpty && subject != 'All') {
      req = req.eq('subject', subject);
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

  // Fetch quizzes created by current user
  Future<List<Quiz>> getMyQuizzes({
    String? query,
    String? grade,
    String? subject,
    String? questionRange,
    bool? isPublic,
  }) async {
    var req = _supabase
        .from('quizzes')
        .select()
        .eq('creator_id', _supabase.auth.currentUser!.id);

    if (isPublic != null) {
      req = req.eq('is_public', isPublic);
    }

    if (query != null && query.isNotEmpty) {
      req = req.ilike('title', '%$query%');
    }
    if (grade != null && grade.isNotEmpty && grade != 'All') {
      req = req.eq('grade', grade);
    }
    if (subject != null && subject.isNotEmpty && subject != 'All') {
      req = req.eq('subject', subject);
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
    // Delete existing to replace (simple approach)
    await _supabase.from('questions').delete().eq('quiz_id', quizId);

    for (int i = 0; i < questions.length; i++) {
      var q = questions[i];
      final qResponse = await _supabase
          .from('questions')
          .insert({
            'quiz_id': quizId,
            'question_text': q.questionText,
            'duration_seconds': q.durationSeconds,
            'order_index': i,
          })
          .select()
          .single();

      String newQuestionId = qResponse['id'];

      for (var opt in q.options) {
        await _supabase.from('options').insert({
          'question_id': newQuestionId,
          'option_text': opt.optionText,
          'is_correct': opt.isCorrect,
        });
      }
    }
  }

  // Fetch attempts for a specific quiz for the current user
  Future<List<QuizAttempt>> getQuizAttempts(String quizId) async {
    final response = await _supabase
        .from('quiz_attempts')
        .select()
        .eq('quiz_id', quizId)
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('created_at', ascending: true);
    return (response as List).map((e) => QuizAttempt.fromJson(e)).toList();
  }

  // Fetch all attempts for the current user across all quizzes
  Future<List<Map<String, dynamic>>> getAllQuizAttempts({
    String? query,
    String? grade,
    String? subject,
    String? questionRange,
  }) async {
    var req = _supabase
        .from('quiz_attempts')
        .select('*, quizzes!inner(*)')
        .eq('user_id', _supabase.auth.currentUser!.id);

    if (query != null && query.isNotEmpty) {
      req = req.ilike('quizzes.title', '%$query%');
    }
    if (grade != null && grade.isNotEmpty && grade != 'All') {
      req = req.eq('quizzes.grade', grade);
    }
    if (subject != null && subject.isNotEmpty && subject != 'All') {
      req = req.eq('quizzes.subject', subject);
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

  Future<List<String>> getGrades() async {
    final response = await _supabase.from('grades').select('name');
    return (response as List).map((e) => e['name'] as String).toList();
  }

  Future<List<String>> getSubjects() async {
    final response = await _supabase.from('subjects').select('name');
    return (response as List).map((e) => e['name'] as String).toList();
  }
}
