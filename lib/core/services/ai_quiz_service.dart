import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AIQuizService {
  static const String _prefKey = 'gemini_api_key';
  static const String _prefModelKey = 'gemini_selected_model';
  static const String _prefTopicSuggestionsKey = 'gemini_topic_suggestions';

  static const List<String> availableModels = [
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
    'gemini-2.0-flash',
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro',
    'gemini-1.5-pro-latest',
  ];

  static const List<String> defaultTopicSuggestions = [
    'Photosynthesis & Calvin Cycle',
    'World War II: Major Battles',
    'Python OOP & Design Patterns',
    'Human Cardiovascular System',
    'Macroeconomics & Market Supply',
  ];

  /// Retrieves the Gemini API Key from environment or local storage.
  static Future<String?> getApiKey() async {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    final prefs = await SharedPreferences.getInstance();
    final localKey = prefs.getString(_prefKey);
    if (localKey != null && localKey.trim().isNotEmpty) {
      return localKey.trim();
    }
    return null;
  }

  /// Saves the user-provided Gemini API Key locally.
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key.trim());
  }

  /// Clears the locally stored API key.
  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// Gets the selected model name or default.
  static Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefModelKey) ?? 'gemini-1.5-flash';
  }

  /// Saves the selected model preference.
  static Future<void> saveSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefModelKey, model);
  }

  /// Dynamically queries Google Generative Language API to list all models available for the provided API key.
  static Future<List<String>> listAvailableModelsForApiKey(
    String apiKey,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final modelsList = data['models'] as List? ?? [];
      final List<String> supported = [];

      for (var m in modelsList) {
        if (m is! Map) continue;
        final methods = (m['supportedGenerationMethods'] as List? ?? [])
            .cast<String>();
        if (methods.contains('generateContent')) {
          String name = (m['name'] ?? '').toString();
          if (name.startsWith('models/')) {
            name = name.substring(7);
          }
          if (name.isNotEmpty) {
            supported.add(name);
          }
        }
      }
      return supported;
    } else {
      try {
        final errBody = jsonDecode(response.body);
        final errMsg = errBody['error']?['message'] ?? response.body;
        throw Exception(errMsg);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception(
          'Failed to validate API key: HTTP ${response.statusCode}',
        );
      }
    }
  }

  /// Fetches dynamic AI-generated quick topic suggestions.
  static Future<List<String>> fetchDynamicTopicSuggestions({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getStringList(_prefTopicSuggestionsKey);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return defaultTopicSuggestions;
    }

    try {
      final modelName = await getSelectedModel();
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.9,
        ),
      );

      final response = await model.generateContent([
        Content.text(
          'Generate a JSON array of 5 diverse, engaging, creative educational quiz topic titles spanning science, tech, history, astronomy, and arts. Return strictly a JSON array of strings, e.g. ["Topic 1", "Topic 2", "Topic 3", "Topic 4", "Topic 5"]',
        ),
      ]);

      final rawText = response.text;
      if (rawText != null && rawText.trim().isNotEmpty) {
        String cleanJson = rawText.trim();
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.substring(7);
        } else if (cleanJson.startsWith('```')) {
          cleanJson = cleanJson.substring(3);
        }
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
        cleanJson = cleanJson.trim();

        final dynamic decoded = jsonDecode(cleanJson);
        if (decoded is List) {
          final List<String> list = decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (list.length >= 3) {
            await prefs.setStringList(_prefTopicSuggestionsKey, list);
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching dynamic topics: $e');
    }

    return defaultTopicSuggestions;
  }

  /// Generates a photorealistic / 3D illustration AI cover image matching the quiz topic
  /// and saves it permanently into the Supabase storage bucket `quiz_images`.
  static Future<String?> generateAndUploadCoverImage(
    String titleOrPrompt,
  ) async {
    try {
      final prompt =
          '$titleOrPrompt, modern 3D digital illustration, clean educational cover art, vibrant gradient colors, vector graphic, high resolution, no text';
      final encoded = Uri.encodeComponent(prompt);
      final seed = DateTime.now().millisecondsSinceEpoch % 100000;
      final url =
          'https://image.pollinations.ai/prompt/$encoded?width=512&height=512&nologo=true&seed=$seed';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        try {
          final fileName = 'ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final client = Supabase.instance.client;
          await client.storage
              .from('quiz_images')
              .uploadBinary(
                fileName,
                response.bodyBytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );
          return client.storage.from('quiz_images').getPublicUrl(fileName);
        } catch (storageErr) {
          debugPrint(
            'Supabase image upload fallback to direct URL: $storageErr',
          );
          return url;
        }
      }
      return url;
    } catch (e) {
      debugPrint('Error generating cover image: $e');
      return null;
    }
  }

  /// Generates a complete quiz (Title, Description, Questions, Options, Explanations, Cover Image)
  /// using Google Gemini AI from a text prompt or uploaded document file.
  static Future<Map<String, dynamic>> generateQuiz({
    required String promptOrInstructions,
    Uint8List? fileBytes,
    String? fileMimeType,
    String? fileName,
    int questionCount = 5,
    String difficulty = 'Medium',
    int durationSeconds = 0, // 0 = Auto (AI calculates per question)
    bool generateCover = true,
    String? modelName,
    String? overrideApiKey,
  }) async {
    final apiKey = overrideApiKey ?? await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Gemini API Key is missing. Please configure your API key from Google AI Studio (https://aistudio.google.com/app/apikey).',
      );
    }

    // Discover supported models from the user's API key
    List<String> candidateModels = [];
    try {
      final liveModels = await listAvailableModelsForApiKey(apiKey);
      if (liveModels.isNotEmpty) {
        if (modelName != null && liveModels.contains(modelName)) {
          candidateModels.add(modelName);
        }
        final flashModels = liveModels
            .where((m) => m.contains('flash'))
            .toList();
        final otherModels = liveModels
            .where((m) => !m.contains('flash'))
            .toList();
        for (var m in [...flashModels, ...otherModels]) {
          if (!candidateModels.contains(m)) {
            candidateModels.add(m);
          }
        }
      }
    } catch (e) {
      debugPrint('Could not list models via API: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('api key not valid') ||
          errStr.contains('invalid api key') ||
          errStr.contains('permission_denied') ||
          errStr.contains('has not been used in project')) {
        rethrow;
      }
    }

    if (candidateModels.isEmpty) {
      final preferred = modelName ?? await getSelectedModel();
      candidateModels = [
        preferred,
        ...availableModels.where((m) => m != preferred),
      ];
    }

    dynamic lastError;

    for (final currentModel in candidateModels) {
      try {
        debugPrint('Attempting AI generation with model: $currentModel');
        final result = await _executeGeneration(
          modelName: currentModel,
          apiKey: apiKey,
          promptOrInstructions: promptOrInstructions,
          fileBytes: fileBytes,
          fileMimeType: fileMimeType,
          fileName: fileName,
          questionCount: questionCount,
          difficulty: difficulty,
          durationSeconds: durationSeconds,
        );

        // Generate AI cover image if enabled
        if (generateCover) {
          final imagePrompt =
              result['imagePrompt'] as String? ??
              result['title'] as String? ??
              promptOrInstructions;
          final imageUrl = await generateAndUploadCoverImage(imagePrompt);
          if (imageUrl != null) {
            result['imageUrl'] = imageUrl;
          }
        }

        await saveSelectedModel(currentModel);
        return result;
      } catch (e) {
        lastError = e;
        final errStr = e.toString().toLowerCase();
        debugPrint('Model $currentModel failed: $e');

        if (errStr.contains('not found') ||
            errStr.contains('not supported') ||
            errStr.contains('404') ||
            errStr.contains('unsupported')) {
          continue;
        }

        if (errStr.contains('api_key_invalid') ||
            errStr.contains('api key not valid') ||
            errStr.contains('quota') ||
            errStr.contains('permission_denied')) {
          rethrow;
        }
      }
    }

    throw lastError ??
        Exception(
          'Failed to generate quiz. Please ensure your Google Gemini API key is active from https://aistudio.google.com/app/apikey',
        );
  }

  static Future<Map<String, dynamic>> _executeGeneration({
    required String modelName,
    required String apiKey,
    required String promptOrInstructions,
    Uint8List? fileBytes,
    String? fileMimeType,
    String? fileName,
    required int questionCount,
    required String difficulty,
    required int durationSeconds,
  }) async {
    final isAutoDuration = durationSeconds <= 0;

    final durationInstruction = isAutoDuration
        ? 'Auto-calculate the duration for each individual question (between 15 and 90 seconds, in whole seconds) based on difficulty, text length, and option complexity. For short direct recall questions set 15-20s; for medium questions set 30-45s; for complex multi-choice or scenario questions set 60-90s.'
        : 'Set the "durationSeconds" for every question to $durationSeconds seconds.';

    final systemPrompt =
        '''
You are an expert curriculum designer and educational assessment specialist for LearnByte.
Your task is to generate high quality, engaging educational quizzes based strictly on user prompts or uploaded study materials.

Guidelines for Quiz Generation:
1. Generate an accurate, engaging quiz title and a concise description.
2. Generate an "imagePrompt": a vivid description for creating a modern 3D illustration cover image for this topic.
3. Generate EXACTLY the requested number of questions ($questionCount questions).
4. Question styles:
   - Mix single-choice questions (1 correct option) and multiple-choice questions (2 or more correct options, e.g. "Which of the following are...").
   - Give each question 2 to 5 options as appropriate.
   - For single-choice questions, exactly 1 option must have "isCorrect": true.
   - For multiple-choice questions, 2 or more options must have "isCorrect": true.
   - Ensure false options (distractors) are plausible and educational.
5. Explanations:
   - Provide a clear, educational explanation for every question explaining why the correct answer(s) are right.
6. Difficulty: Tailor the depth and cognitive level to the requested difficulty: $difficulty.
7. Duration setting: $durationInstruction

Return STRICT JSON matching this schema:
{
  "title": "Clear & Engaging Title",
  "description": "Short description of what this quiz covers",
  "imagePrompt": "Vivid artistic prompt for generating cover art",
  "questions": [
    {
      "text": "Question statement?",
      "durationSeconds": 30,
      "explanation": "Detailed rationale explaining why the answer(s) are correct.",
      "options": [
        {"text": "Option 1 text", "isCorrect": true},
        {"text": "Option 2 text", "isCorrect": false},
        {"text": "Option 3 text", "isCorrect": false},
        {"text": "Option 4 text", "isCorrect": false}
      ]
    }
  ]
}
''';

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.7,
      ),
      systemInstruction: Content.system(systemPrompt),
    );

    final List<Content> contentParts = [];

    // Add multimodal document/file if present
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final mimeType =
          fileMimeType ?? _resolveMimeType(fileName ?? 'document.pdf');
      contentParts.add(
        Content.multi([
          DataPart(mimeType, fileBytes),
          TextPart(
            'Generate a $questionCount-question quiz based on the attached document.\n'
            'Difficulty: $difficulty\n'
            'Duration setting: ${isAutoDuration ? "Auto (AI-set per question based on complexity)" : "$durationSeconds seconds per question"}\n'
            'Additional user focus/instructions: ${promptOrInstructions.isEmpty ? "Cover key concepts thoroughly" : promptOrInstructions}',
          ),
        ]),
      );
    } else {
      contentParts.add(
        Content.text(
          'Topic / Study Prompt: $promptOrInstructions\n'
          'Target Question Count: $questionCount\n'
          'Difficulty Level: $difficulty\n'
          'Duration setting: ${isAutoDuration ? "Auto (AI-set per question based on complexity)" : "$durationSeconds seconds per question"}\n'
          'Please generate the quiz now in JSON format.',
        ),
      );
    }

    final response = await model.generateContent(contentParts);
    final rawText = response.text;

    if (rawText == null || rawText.trim().isEmpty) {
      throw Exception('AI returned an empty response. Please try again.');
    }

    // Parse structured JSON
    String cleanJson = rawText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    } else if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final dynamic decoded = jsonDecode(cleanJson);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format received from AI.');
    }

    // Validate and sanitize questions
    final rawQuestions = decoded['questions'] as List? ?? [];
    final List<Map<String, dynamic>> sanitizedQuestions = [];

    for (var q in rawQuestions) {
      if (q is! Map) continue;
      final qText = (q['text'] ?? '').toString().trim();
      if (qText.isEmpty) continue;

      final rawOptions = q['options'] as List? ?? [];
      final List<Map<String, dynamic>> sanitizedOptions = [];

      for (var opt in rawOptions) {
        if (opt is! Map) continue;
        final optText = (opt['text'] ?? '').toString().trim();
        if (optText.isEmpty) continue;
        sanitizedOptions.add({
          'text': optText,
          'isCorrect': opt['isCorrect'] == true,
        });
      }

      if (sanitizedOptions.isNotEmpty &&
          !sanitizedOptions.any((o) => o['isCorrect'] == true)) {
        sanitizedOptions[0]['isCorrect'] = true;
      }

      int parsedDuration = (q['durationSeconds'] as num?)?.toInt() ?? 30;
      if (parsedDuration <= 0) {
        parsedDuration = isAutoDuration ? 30 : durationSeconds;
      }

      if (sanitizedOptions.length >= 2) {
        sanitizedQuestions.add({
          'text': qText,
          'durationSeconds': parsedDuration,
          'explanation': (q['explanation'] ?? '').toString().trim(),
          'options': sanitizedOptions,
        });
      }
    }

    if (sanitizedQuestions.isEmpty) {
      throw Exception(
        'Failed to generate valid quiz questions from the provided input. Please refine your prompt or upload a clearer document.',
      );
    }

    return {
      'title': (decoded['title'] ?? 'AI Generated Quiz').toString().trim(),
      'description': (decoded['description'] ?? 'Generated by AI in LearnByte')
          .toString()
          .trim(),
      'imagePrompt': (decoded['imagePrompt'] ?? '').toString().trim(),
      'questions': sanitizedQuestions,
    };
  }

  static String _resolveMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
