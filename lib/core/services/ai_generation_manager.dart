import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/quiz_models.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/repositories/flashcard_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import 'ai_quiz_service.dart';
import 'ai_flashcard_service.dart';
import 'ai_lesson_service.dart';

enum AITaskType { quiz, flashcard, lesson }
enum AITaskStatus { idle, generating, completed, failed }

class AIGenerationTask {
  final String id;
  final AITaskType taskType;
  final String prompt;
  final String? fileName;
  final int count; // questionCount or cardCount or subChapterCount
  final String difficulty;
  final int durationSeconds; // for quiz
  final String cardStyle; // for flashcard
  final String lessonScope; // for lesson
  final bool generateCover;
  final bool generateInSlideImages;
  final String modelName;
  AITaskStatus status;
  String statusMessage;
  String? error;
  String? generatedId; // quizId, deckId, or courseId
  String? generatedTitle;
  String? generatedCoverUrl;
  DateTime createdAt;

  AIGenerationTask({
    required this.id,
    this.taskType = AITaskType.quiz,
    required this.prompt,
    this.fileName,
    this.count = 5,
    required this.difficulty,
    this.durationSeconds = 0,
    this.cardStyle = 'Mixed',
    this.lessonScope = 'Auto',
    this.generateCover = true,
    this.generateInSlideImages = true,
    required this.modelName,
    this.status = AITaskStatus.generating,
    this.statusMessage = 'Preparing study materials...',
    this.error,
    this.generatedId,
    this.generatedTitle,
    this.generatedCoverUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

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

  /// Starts an asynchronous AI Lesson generation task.
  Future<void> startLessonGeneration({
    required BuildContext context,
    required String prompt,
    List<Uint8List>? filesBytes,
    List<String>? filesNames,
    Uint8List? fileBytes,
    String? fileName,
    String? fileMimeType,
    String lessonScope = 'Auto',
    required String audience,
    bool generateCover = true,
    bool generateInSlideImages = true,
    required String modelName,
  }) async {
    final effectiveNames = filesNames ?? (fileName != null ? [fileName] : <String>[]);
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = AIGenerationTask(
      id: taskId,
      taskType: AITaskType.lesson,
      prompt: prompt,
      fileName: effectiveNames.isNotEmpty ? effectiveNames.join(', ') : fileName,
      lessonScope: lessonScope,
      difficulty: audience,
      generateCover: generateCover,
      generateInSlideImages: generateInSlideImages,
      modelName: modelName,
    );

    _currentTask = task;
    notifyListeners();

    _runBackgroundLessonTask(
      task: task,
      filesBytes: filesBytes,
      filesNames: filesNames,
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

  Future<void> _runBackgroundLessonTask({
    required AIGenerationTask task,
    List<Uint8List>? filesBytes,
    List<String>? filesNames,
    Uint8List? fileBytes,
    String? fileName,
    String? fileMimeType,
  }) async {
    try {
      task.statusMessage = 'Reading study materials & syllabus...';
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 900), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating) {
          task.statusMessage = 'Gemini AI designing curriculum & slide structure...';
          notifyListeners();
        }
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating) {
          task.statusMessage = 'Drafting slide pages & interactive checkpoints...';
          notifyListeners();
        }
      });

      Future.delayed(const Duration(milliseconds: 4500), () {
        if (_currentTask?.id == task.id && task.status == AITaskStatus.generating && task.generateInSlideImages) {
          task.statusMessage = 'Rendering AI visual diagrams & cover art...';
          notifyListeners();
        }
      });

      final result = await AILessonService.generateLesson(
        promptOrInstructions: task.prompt,
        filesBytes: filesBytes,
        filesNames: filesNames,
        fileBytes: fileBytes,
        fileName: fileName,
        fileMimeType: fileMimeType,
        lessonScope: task.lessonScope,
        audience: task.difficulty,
        generateCover: task.generateCover,
        generateInSlideImages: task.generateInSlideImages,
        modelName: task.modelName,
      );

      final title = result['title'] as String? ?? 'AI Generated Course';
      final desc = result['description'] as String? ?? 'Interactive AI Course in LearnByte';
      final imageUrl = result['imageUrl'] as String?;
      final chaptersData = result['chapters'] as List? ?? [];

      task.statusMessage = 'Saving course, subchapters, and slides to database...';
      notifyListeners();

      final repo = LessonRepository();

      // 1. Create Course
      final course = await repo.createCourse(
        title: title,
        description: desc,
        isPublic: false,
        imageUrl: imageUrl,
      );

      final List<Map<String, dynamic>> allBlockPayloads = [];

      // 2. Iterate Chapters
      for (int cIdx = 0; cIdx < chaptersData.length; cIdx++) {
        final cData = chaptersData[cIdx];
        if (cData is! Map) continue;
        final cTitle = (cData['title'] ?? 'Chapter ${cIdx + 1}').toString();
        final chapter = await repo.createChapter(
          title: cTitle,
          position: cIdx + 1,
          courseId: course.id,
        );

        // 3. Iterate SubChapters
        final subChaptersData = cData['subChapters'] as List? ?? [];
        for (int sIdx = 0; sIdx < subChaptersData.length; sIdx++) {
          final sData = subChaptersData[sIdx];
          if (sData is! Map) continue;
          final sTitle = (sData['title'] ?? 'Module ${sIdx + 1}').toString();
          final xp = (sData['xpReward'] as num?)?.toInt() ?? 10;

          final subChapter = await repo.createSubChapter(
            chapterId: chapter.id,
            title: sTitle,
            position: sIdx + 1,
            xpReward: xp,
          );

          // 4. Iterate Pages
          final pagesData = sData['pages'] as List? ?? [];
          for (int pIdx = 0; pIdx < pagesData.length; pIdx++) {
            final pData = pagesData[pIdx];
            if (pData is! Map) continue;

            final page = await repo.createPage(
              subChapterId: subChapter.id,
              position: pIdx + 1,
            );

            // 5. Collect Block Payloads
            final blocksData = pData['blocks'] as List? ?? [];
            for (int bIdx = 0; bIdx < blocksData.length; bIdx++) {
              final bData = blocksData[bIdx];
              if (bData is! Map) continue;
              final bType = (bData['blockType'] ?? 'text').toString();
              final bContent = bData['content'] as Map<String, dynamic>? ?? {};

              allBlockPayloads.add({
                'page_id': page.id,
                'block_type': bType,
                'content': bContent,
                'position': bIdx + 1,
              });
            }
          }
        }
      }

      // 6. Bulk Insert All Blocks in a single lightning-fast query
      if (allBlockPayloads.isNotEmpty) {
        await repo.insertBlocks(allBlockPayloads);
      }

      task.status = AITaskStatus.completed;
      task.statusMessage = 'Course and interactive slides created successfully!';
      task.generatedId = course.id;
      task.generatedTitle = title;
      task.generatedCoverUrl = imageUrl;
      _completedTasks.insert(0, task);
      notifyListeners();
    } catch (e) {
      debugPrint('Background AI Lesson Generation failed: $e');
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
