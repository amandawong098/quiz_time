import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_quiz_service.dart';

class AIFlashcardService {
  static const String _prefFlashcardTopicsKey = 'gemini_flashcard_topics';

  static const List<String> defaultFlashcardTopics = [
    'Medical Pharmacology & Drug Classes',
    'Spanish Irregular Verb Conjugations',
    'Python Data Structures & Complexity',
    'Organic Chemistry Functional Groups',
    'World History Major Revolutions',
  ];

  /// Fetches dynamic AI-generated flashcard topic suggestions.
  static Future<List<String>> fetchDynamicFlashcardTopics({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getStringList(_prefFlashcardTopicsKey);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    final apiKey = await AIQuizService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return defaultFlashcardTopics;
    }

    try {
      final modelName = await AIQuizService.getSelectedModel();
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
          'Generate a JSON array of 5 diverse, high-yield, engaging educational flashcard deck topic titles spanning languages, medicine, coding, sciences, and history. Return strictly a JSON array of strings, e.g. ["Topic 1", "Topic 2", "Topic 3", "Topic 4", "Topic 5"]',
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
            await prefs.setStringList(_prefFlashcardTopicsKey, list);
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching dynamic flashcard topics: $e');
    }

    return defaultFlashcardTopics;
  }

  /// Generates a complete flashcard deck (Title, Description, Cards, Cover Image)
  /// using Google Gemini AI from a text prompt or uploaded study document.
  static Future<Map<String, dynamic>> generateFlashcardDeck({
    required String promptOrInstructions,
    Uint8List? fileBytes,
    String? fileMimeType,
    String? fileName,
    int cardCount = 10,
    String cardStyle = 'Mixed',
    String difficulty = 'Intermediate',
    bool generateCover = true,
    String? modelName,
    String? overrideApiKey,
  }) async {
    final apiKey = overrideApiKey ?? await AIQuizService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Gemini API Key is missing. Please configure your API key from Google AI Studio (https://aistudio.google.com/app/apikey).',
      );
    }

    // Discover supported models from the user's API key
    List<String> candidateModels = [];
    try {
      final liveModels =
          await AIQuizService.listAvailableModelsForApiKey(apiKey);
      if (liveModels.isNotEmpty) {
        if (modelName != null && liveModels.contains(modelName)) {
          candidateModels.add(modelName);
        }
        final flashModels =
            liveModels.where((m) => m.contains('flash')).toList();
        final otherModels =
            liveModels.where((m) => !m.contains('flash')).toList();
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
      final preferred = modelName ?? await AIQuizService.getSelectedModel();
      candidateModels = [
        preferred,
        ...AIQuizService.availableModels.where((m) => m != preferred),
      ];
    }

    dynamic lastError;

    for (final currentModel in candidateModels) {
      try {
        debugPrint('Attempting AI flashcard generation with model: $currentModel');
        final result = await _executeFlashcardGeneration(
          modelName: currentModel,
          apiKey: apiKey,
          promptOrInstructions: promptOrInstructions,
          fileBytes: fileBytes,
          fileMimeType: fileMimeType,
          fileName: fileName,
          cardCount: cardCount,
          cardStyle: cardStyle,
          difficulty: difficulty,
        );

        if (generateCover) {
          final imagePrompt = result['imagePrompt'] as String? ??
              result['title'] as String? ??
              promptOrInstructions;
          final imageUrl =
              await AIQuizService.generateAndUploadCoverImage(imagePrompt);
          if (imageUrl != null) {
            result['imageUrl'] = imageUrl;
          }
        }

        await AIQuizService.saveSelectedModel(currentModel);
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
          'Failed to generate flashcards. Please ensure your Google Gemini API key is active.',
        );
  }

  static Future<Map<String, dynamic>> _executeFlashcardGeneration({
    required String modelName,
    required String apiKey,
    required String promptOrInstructions,
    Uint8List? fileBytes,
    String? fileMimeType,
    String? fileName,
    required int cardCount,
    required String cardStyle,
    required String difficulty,
  }) async {
    final systemPrompt = '''
You are an expert educational flashcard creator and cognitive memory specialist for LearnByte.
Your task is to generate high-yield, structured flashcard study decks based strictly on user prompts or uploaded study materials.

Guidelines for Flashcard Generation:
1. Generate an accurate, engaging deck title and a concise description.
2. Generate an "imagePrompt": a vivid description for creating a modern 3D illustration cover art for this deck.
3. Generate EXACTLY $cardCount flashcards.
4. Card Style: $cardStyle
   - "Definitions & Terms": Front is Term/Concept; Back is concise, precise definition and key usage.
   - "Question & Answer": Front is a targeted conceptual question; Back is the direct answer with rationale.
   - "Concept & Breakdown": Front is a major principle/theory; Back is key components/bulleted breakdown.
   - "Formulas & Examples": Front is Formula/Rule/Function; Back is explanation and practical example.
   - "Mixed": Diverse blend of definitions, questions, and concept breakdowns.
5. Difficulty Level: $difficulty (Tailor the depth and technical specificity accordingly).
6. Card Formatting:
   - "front": Clear, concise, easily readable at a glance (1-2 lines max).
   - "back": Educational, direct, well-structured explanation or answer (2-4 lines max).

Return STRICT JSON matching this schema:
{
  "title": "Clear & Engaging Deck Title",
  "description": "Short description of what this flashcard deck covers",
  "imagePrompt": "Vivid artistic prompt for generating 3D cover art",
  "cards": [
    {
      "front": "Front of card (Term / Concept / Question)",
      "back": "Back of card (Definition / Explanation / Answer / Key points)"
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
            'Generate a $cardCount-card flashcard deck based on the attached document.\n'
            'Card Style: $cardStyle\n'
            'Difficulty: $difficulty\n'
            'Additional user focus/instructions: ${promptOrInstructions.isEmpty ? "Extract key concepts thoroughly" : promptOrInstructions}',
          ),
        ]),
      );
    } else {
      contentParts.add(
        Content.text(
          'Topic / Study Prompt: $promptOrInstructions\n'
          'Target Card Count: $cardCount\n'
          'Card Style: $cardStyle\n'
          'Difficulty Level: $difficulty\n'
          'Please generate the flashcard deck now in JSON format.',
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

    final rawCards = decoded['cards'] as List? ?? [];
    final List<Map<String, String>> sanitizedCards = [];

    for (var c in rawCards) {
      if (c is! Map) continue;
      final front = (c['front'] ?? '').toString().trim();
      final back = (c['back'] ?? '').toString().trim();
      if (front.isNotEmpty && back.isNotEmpty) {
        sanitizedCards.add({
          'front': front,
          'back': back,
        });
      }
    }

    if (sanitizedCards.isEmpty) {
      throw Exception(
        'Failed to generate valid flashcards from the provided input. Please refine your prompt or upload a clearer document.',
      );
    }

    return {
      'title': (decoded['title'] ?? 'AI Flashcard Deck').toString().trim(),
      'description': (decoded['description'] ?? 'Generated by AI in LearnByte')
          .toString()
          .trim(),
      'imagePrompt': (decoded['imagePrompt'] ?? '').toString().trim(),
      'cards': sanitizedCards,
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
