class Quiz {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String grade;
  final String subject;
  final bool isPublic;
  final String? imageUrl;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    required this.grade,
    required this.subject,
    required this.isPublic,
    this.imageUrl,
    required this.createdAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      creatorId: json['creator_id'],
      title: json['title'],
      description: json['description'],
      grade: json['grade'],
      subject: json['subject'],
      isPublic: json['is_public'] ?? false,
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'grade': grade,
      'subject': subject,
      'is_public': isPublic,
      'image_url': imageUrl,
    };
  }
}

class Question {
  final String id;
  final String quizId;
  final String questionText;
  final int durationSeconds;
  final int orderIndex;
  final List<Option> options;

  Question({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.durationSeconds,
    required this.orderIndex,
    this.options = const [],
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      quizId: json['quiz_id'],
      questionText: json['question_text'],
      durationSeconds: json['duration_seconds'] ?? 30,
      orderIndex: json['order_index'],
      options: json['options'] != null
          ? (json['options'] as List).map((o) => Option.fromJson(o)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'question_text': questionText,
      'duration_seconds': durationSeconds,
      'order_index': orderIndex,
    };
  }
}

class Option {
  final String id;
  final String questionId;
  final String optionText;
  final bool isCorrect;

  Option({
    required this.id,
    required this.questionId,
    required this.optionText,
    required this.isCorrect,
  });

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      id: json['id'],
      questionId: json['question_id'],
      optionText: json['option_text'],
      isCorrect: json['is_correct'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'option_text': optionText,
      'is_correct': isCorrect,
    };
  }
}

class QuizAttempt {
  final String id;
  final String userId;
  final String quizId;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final double? avgTimePerQuestion;
  final DateTime createdAt;
  final List<dynamic> userAnswers;

  QuizAttempt({
    required this.id,
    required this.userId,
    required this.quizId,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    this.avgTimePerQuestion,
    required this.createdAt,
    this.userAnswers = const [],
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id'],
      userId: json['user_id'],
      quizId: json['quiz_id'],
      score: json['score'],
      totalQuestions: json['total_questions'],
      correctAnswers: json['correct_answers'],
      wrongAnswers: json['wrong_answers'],
      avgTimePerQuestion: json['avg_time_per_question'] != null
          ? (json['avg_time_per_question'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(json['created_at']),
      userAnswers: json['user_answers'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'quiz_id': quizId,
      'score': score,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'wrong_answers': wrongAnswers,
      'avg_time_per_question': avgTimePerQuestion,
      'user_answers': userAnswers,
    };
  }
}
