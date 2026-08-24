import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/quiz_models.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/flashcard_repository.dart';
import 'ai_quiz_service.dart';
import 'ai_flashcard_service.dart';

enum AITaskType { quiz, flashcard }
enum AITaskStatus { idle, generating, completed, failed }

class AIGenerationTask {
  final String id;
  final AITaskType taskType;
  final String prompt;
  final String? fileName;
  final int count; // questionCount or cardCount
  final String difficulty;
  final int durationSeconds; // for quiz
  final String cardStyle; // for flashcard
  final bool generateCover;
  final String modelName;
  AITaskStatus status;
  String statusMessage;
  String? error;
  String? generatedId; // quizId or deckId
  String? generatedTitle;
  String? generatedCoverUrl;
  DateTime createdAt;

  AIGenerationTask({
    required this.id,
    this.taskType = AITaskType.quiz,
    required this.prompt,
    this.fileName,
    required this.count,
    required this.difficulty,
    this.durationSeconds = 0,
    this.cardStyle = 'Mixed',
    this.generateCover = true,
    required this.modelName,
    this.status = AITaskStatus.generating,
    this.statusMessage = 'Preparing study materials...',
    this.error,
    this.generatedId,
    this.generatedTitle,
    this.generatedCoverUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Backward compatibility getters
  int get questionCount => count;
  String? get generatedQuizId => generatedId;
  String? get generatedQuizTitle => generatedTitle;
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
      taskType: AITaskType.quiz,
      prompt: prompt,
      fileName: fileName,
      count: questionCount,
      difficulty: difficulty,
      durationSeconds: durationSeconds,
      generateCover: generateCover,
      modelName: modelName,
    );

    _currentTask = task;
    notifyListeners();

    _runBackgroundQuizTask(
      task: task,
      fileBytes: fileBytes,
      fileName: fileName,
      fileMimeType: fileMimeType,
    );
  }

  /// Starts an asynchronous AI Flashcard generation task.
  Future<void> startFlashcardGeneration({
    required BuildContext context,
    required String prompt,
    Uint8List? fileBytes,
    String? fileName,
    String? fileMimeType,
    required int cardCount,
    required String cardStyle,
    required String difficulty,
    bool generateCover = true,
    required String modelName,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = AIGenerationTask(
      id: taskId,
      taskType: AITaskType.flashcard,
      prompt: prompt,
      fileName: fileName,
      count: cardCount,
      difficulty: difficulty,
      cardStyle: cardStyle,
      generateCover: generateCover,
      modelName: modelName,
    );

    _currentTask = task;
    notifyListeners();

    _runBackgroundFlashcardTask(
      task: task,
      fileBytes: fileBytes,
      fileName: fileName,
      fileMimeType: fileMimeType,
    );
  }

  Future<void> _runBackgroundQuizTask({
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
        questionCount: task.count,
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
      task.generatedId = quizId;
      task.generatedTitle = title;
      task.generatedCoverUrl = imageUrl;
      _completedTasks.insert(0, task);
      notifyListeners();
    } catch (e) {
      debugPrint('Background AI Quiz Generation failed: $e');
      task.status = AITaskStatus.failed;
      task.error = e.toString().replaceAll('Exception: ', '');
      task.statusMessage = 'Generation failed';
      notifyListeners();
    }
  }

  Future<void> _runBackgroundFlashcardTask({
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
          task.statusMessage = 'Gemini AI extracting high-yield flashcard concepts...';
          notifyListeners();
        }
      });

      Future.delayed(const Duration(milliseconds: 2200), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating) {
          task.statusMessage = 'Formulating study terms & breakdowns...';
          notifyListeners();
        }
      });

      Future.delayed(const Duration(milliseconds: 4000), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating && task.generateCover) {
          task.statusMessage = 'Generating AI 3D cover illustration...';
          notifyListeners();
        }
      });

      final result = await AIFlashcardService.generateFlashcardDeck(
        promptOrInstructions: task.prompt,
        fileBytes: fileBytes,
        fileName: fileName,
        fileMimeType: fileMimeType,
        cardCount: task.count,
        cardStyle: task.cardStyle,
        difficulty: task.difficulty,
        generateCover: task.generateCover,
        modelName: task.modelName,
      );

      final title = result['title'] as String? ?? 'AI Flashcard Deck';
      final desc = result['description'] as String? ?? 'Generated with AI in LearnByte';
      final imageUrl = result['imageUrl'] as String?;
      final cardsData = result['cards'] as List<Map<String, String>>? ?? [];

      task.statusMessage = 'Saving flashcard deck to your library...';
      notifyListeners();

      final repo = FlashcardRepository();
      final deck = await repo.createDeck(
        title: title,
        description: desc,
        isPublic: false,
        imageUrl: imageUrl,
      );

      for (int i = 0; i < cardsData.length; i++) {
        final card = cardsData[i];
        await repo.createFlashcard(
          deckId: deck.id,
          front: card['front'] ?? '',
          back: card['back'] ?? '',
          position: i + 1,
        );
      }

      task.status = AITaskStatus.completed;
      task.statusMessage = 'Flashcard deck generated and saved successfully!';
      task.generatedId = deck.id;
      task.generatedTitle = title;
      task.generatedCoverUrl = imageUrl;
      _completedTasks.insert(0, task);
      notifyListeners();
    } catch (e) {
      debugPrint('Background AI Flashcard Generation failed: $e');
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
