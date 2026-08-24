import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/quiz_models.dart';
import '../../data/repositories/quiz_repository.dart';
import 'ai_quiz_service.dart';

enum AITaskStatus { idle, generating, completed, failed }

class AIGenerationTask {
  final String id;
  final String prompt;
  final String? fileName;
  final int questionCount;
  final String difficulty;
  final int durationSeconds;
  final bool generateCover;
  final String modelName;
  AITaskStatus status;
  String statusMessage;
  String? error;
  String? generatedQuizId;
  String? generatedQuizTitle;
  String? generatedCoverUrl;
  DateTime createdAt;

  AIGenerationTask({
    required this.id,
    required this.prompt,
    this.fileName,
    required this.questionCount,
    required this.difficulty,
    required this.durationSeconds,
    this.generateCover = true,
    required this.modelName,
    this.status = AITaskStatus.generating,
    this.statusMessage = 'Preparing study materials...',
    this.error,
    this.generatedQuizId,
    this.generatedQuizTitle,
    this.generatedCoverUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AIGenerationManager extends ChangeNotifier {
  static final AIGenerationManager _instance = AIGenerationManager._internal();
  factory AIGenerationManager() => _instance;
  AIGenerationManager._internal();

  AIGenerationTask? _currentTask;
  final List<AIGenerationTask> _completedTasks = [];

  AIGenerationTask? get currentTask => _currentTask;
  bool get isGenerating => _currentTask?.status == AITaskStatus.generating;
  List<AIGenerationTask> get completedTasks => List.unmodifiable(_completedTasks);

  /// Starts an asynchronous AI Quiz generation task.
  /// Automatically saves the finished quiz directly to Supabase as a Draft Quiz.
  Future<void> startGeneration({
    required BuildContext context,
    required String prompt,
    Uint8List? fileBytes,
    String? fileName,
    String? fileMimeType,
    required int questionCount,
    required String difficulty,
    required int durationSeconds,
    bool generateCover = true,
    required String modelName,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = AIGenerationTask(
      id: taskId,
      prompt: prompt,
      fileName: fileName,
      questionCount: questionCount,
      difficulty: difficulty,
      durationSeconds: durationSeconds,
      generateCover: generateCover,
      modelName: modelName,
    );

    _currentTask = task;
    notifyListeners();

    _runBackgroundTask(
      task: task,
      fileBytes: fileBytes,
      fileName: fileName,
      fileMimeType: fileMimeType,
    );
  }

  Future<void> _runBackgroundTask({
    required AIGenerationTask task,
    Uint8List? fileBytes,
    String? fileName,
    String? fileMimeType,
  }) async {
    try {
      task.statusMessage = 'Reading study materials...';
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 900), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating) {
          task.statusMessage = 'Gemini AI analyzing concepts...';
          notifyListeners();
        }
      });

      Future.delayed(const Duration(milliseconds: 2200), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating) {
          task.statusMessage = 'Formulating multiple-choice questions & explanations...';
          notifyListeners();
        }
      });

      Future.delayed(const Duration(milliseconds: 4000), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating && task.generateCover) {
          task.statusMessage = 'Generating AI 3D cover illustration...';
          notifyListeners();
        }
      });

      final result = await AIQuizService.generateQuiz(
        promptOrInstructions: task.prompt,
        fileBytes: fileBytes,
        fileName: fileName,
        fileMimeType: fileMimeType,
        questionCount: task.questionCount,
        difficulty: task.difficulty,
        durationSeconds: task.durationSeconds,
        generateCover: task.generateCover,
        modelName: task.modelName,
      );

      final title = result['title'] as String? ?? 'AI Generated Quiz';
      final desc = result['description'] as String? ?? 'Generated with AI in LearnByte';
      final imageUrl = result['imageUrl'] as String?;
      final questionsData = result['questions'] as List<Map<String, dynamic>>? ?? [];

      task.statusMessage = 'Saving draft quiz to your library...';
      notifyListeners();

      // Save directly to Supabase
      final repo = QuizRepository();
      final user = Supabase.instance.client.auth.currentUser;

      final newQuiz = Quiz(
        id: '',
        creatorId: user?.id ?? '',
        title: title,
        description: desc,
        imageUrl: imageUrl,
        isPublic: false,
        createdAt: DateTime.now(),
      );

      final quizId = await repo.createQuiz(newQuiz);

      // Convert questions
      final List<Question> questions = [];
      for (int i = 0; i < questionsData.length; i++) {
        final qData = questionsData[i];
        final rawOpts = qData['options'] as List? ?? [];
        final List<Option> options = [];
        for (var opt in rawOpts) {
          options.add(
            Option(
              id: '',
              questionId: '',
              optionText: opt['text'] ?? '',
              isCorrect: opt['isCorrect'] == true,
            ),
          );
        }
        questions.add(
          Question(
            id: '',
            quizId: quizId,
            questionText: qData['text'] ?? '',
            durationSeconds: (qData['durationSeconds'] as num?)?.toInt() ?? 30,
            orderIndex: i,
            explanation: qData['explanation']?.toString(),
            options: options,
          ),
        );
      }

      await repo.saveQuestions(quizId, questions);

      task.status = AITaskStatus.completed;
      task.statusMessage = 'Quiz generated and saved successfully!';
      task.generatedQuizId = quizId;
      task.generatedQuizTitle = title;
      task.generatedCoverUrl = imageUrl;
      _completedTasks.insert(0, task);
      notifyListeners();
    } catch (e) {
      debugPrint('Background AI Generation failed: $e');
      task.status = AITaskStatus.failed;
      task.error = e.toString().replaceAll('Exception: ', '');
      task.statusMessage = 'Generation failed';
      notifyListeners();
    }
  }

  void dismissCurrentTask() {
    _currentTask = null;
    notifyListeners();
  }

  void clearCompletedTasks() {
    _completedTasks.clear();
    notifyListeners();
  }
}
