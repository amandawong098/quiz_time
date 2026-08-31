import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_quiz_service.dart';
import 'ai_attachment_helper.dart';

class AILessonService {
  /// Generates a complete hierarchical course lesson structure (Course ➔ Chapters ➔ SubChapters ➔ Slide Pages ➔ Blocks)
  /// using Google Gemini AI from a text prompt or any uploaded study document (PPTX, PDF, Images, Audio, Code, etc.).
  static Future<Map<String, dynamic>> generateLesson({
    required String promptOrInstructions,
    Uint8List? fileBytes,
    String? fileMimeType,
    String? fileName,
    String lessonScope = 'Standard', // Quick (1 subchap), Standard (2 subchap), Deep (3 subchap)
    String audience = 'Intermediate',
    bool generateCover = true,
    bool generateInSlideImages = true,
    String? modelName,
    String? overrideApiKey,
  }) async {
    final apiKey = overrideApiKey ?? await AIQuizService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Gemini API Key is missing. Please configure your API key from Google AI Studio (https://aistudio.google.com/app/apikey).',
      );
    }

    // Process uploaded attachment if any (PPTX, DOCX, Images, PDF, Audio, etc.)
    ProcessedAttachment? attachment;
    if (fileBytes != null && fileName != null) {
      attachment = await AIAttachmentHelper.processAttachment(
        fileBytes: fileBytes,
        fileName: fileName,
      );
    }

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
        debugPrint('Attempting AI lesson generation with model: $currentModel');
        final result = await _executeLessonGeneration(
          modelName: currentModel,
          apiKey: apiKey,
          promptOrInstructions: promptOrInstructions,
          attachment: attachment,
          fileName: fileName,
          lessonScope: lessonScope,
          audience: audience,
          hasAuthenticImages:
              attachment != null && attachment.extractedImageUrls.isNotEmpty,
        );

        // 1. Generate Course Cover Image
        if (generateCover) {
          final imagePrompt = result['imagePrompt'] as String? ??
              result['title'] as String? ??
              promptOrInstructions;
          try {
            final imageUrl =
                await AIQuizService.generateAndUploadCoverImage(imagePrompt);
            if (imageUrl != null) {
              result['imageUrl'] = imageUrl;
            }
          } catch (e) {
            debugPrint('Cover image generation error: $e');
          }
        }

        // 2. Embed Authentic Images Extracted From Attached File (PPTX / Images / DOCX)
        if (attachment != null && attachment.extractedImageUrls.isNotEmpty) {
          final authenticUrls = attachment.extractedImageUrls;
          int imgIdx = 0;

          final chapters = result['chapters'] as List? ?? [];
          for (var chap in chapters) {
            if (chap is! Map) continue;
            final subChapters = chap['subChapters'] as List? ?? [];
            for (var sub in subChapters) {
              if (sub is! Map) continue;
              final pages = sub['pages'] as List? ?? [];
              for (var page in pages) {
                if (page is! Map) continue;
                final blocks = page['blocks'] as List? ?? [];
                for (var block in blocks) {
                  if (block is! Map) continue;
                  if (block['blockType'] == 'media' &&
                      imgIdx < authenticUrls.length) {
                    block['content'] = {
                      'url': authenticUrls[imgIdx],
                      'type': 'image',
                      'caption': block['caption'] ??
                          'Figure from attached presentation',
                    };
                    imgIdx++;
                  }
                }
              }
            }
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
          'Failed to generate lesson. Please ensure your Google Gemini API key is active.',
        );
  }

  static Future<Map<String, dynamic>> _executeLessonGeneration({
    required String modelName,
    required String apiKey,
    required String promptOrInstructions,
    ProcessedAttachment? attachment,
    String? fileName,
    required String lessonScope,
    required String audience,
    required bool hasAuthenticImages,
  }) async {
    int subChapterCount = 2;
    int pagesPerSubChapter = 3;

    if (lessonScope.toLowerCase().contains('quick')) {
      subChapterCount = 1;
      pagesPerSubChapter = 3;
    } else if (lessonScope.toLowerCase().contains('deep') ||
        lessonScope.toLowerCase().contains('comprehensive')) {
      subChapterCount = 3;
      pagesPerSubChapter = 4;
    }

    final mediaGuideline = hasAuthenticImages
        ? '- Page 2: In-depth visual explanation:\n     - 1 \'media\' block with a helpful educational "caption" describing the figure from the presentation.\n     - 1 \'text\' block explaining the core mechanism or breakdown.'
        : '- Page 2: Deep-dive concept breakdown:\n     - 1 \'text\' block with detailed step-by-step principles, formulas, bullet points, and core mechanisms.';

    final systemPrompt = '''
You are an expert instructional designer and interactive e-learning curriculum architect for LearnByte.
Your task is to generate structured, bite-sized, interactive multi-page course lessons based on user prompts or uploaded study materials.

Curriculum Structure Rules:
1. Generate 1 Course with a catchy title, description, and vivid 3D cover "imagePrompt".
2. Generate 1 Chapter with title and position: 1.
3. Generate EXACTLY $subChapterCount SubChapters within the chapter (each with xpReward: 15).
4. Within each SubChapter, generate EXACTLY $pagesPerSubChapter slide pages.
5. Slide Page Guidelines (Bite-sized mobile formatting):
   - Page 1: Concept Introduction & Key Definitions (text block with '# Heading', formatted bold keywords and bullets).
   $mediaGuideline
   - Final Page of each SubChapter MUST end with an interactive checkpoint:
     - 1 'text' summary block.
     - 1 'test' block with a targeted conceptual question, 3-4 options (1 or multiple is_correct), and a clear educational explanation.
6. Target Audience Depth: $audience.

Return STRICT JSON matching this schema:
{
  "title": "Course Title",
  "description": "Short overview of course",
  "imagePrompt": "Vivid artistic prompt for generating 3D course cover art",
  "chapters": [
    {
      "title": "Chapter 1: Core Fundamentals",
      "position": 1,
      "subChapters": [
        {
          "title": "SubChapter Title",
          "xpReward": 15,
          "position": 1,
          "pages": [
            {
              "position": 1,
              "blocks": [
                {
                  "blockType": "text",
                  "position": 1,
                  "content": {
                    "text": "# Concept Heading\\n\\nClear explanation with **bold keywords** and bullet points:\\n- Key point 1\\n- Key point 2"
                  }
                }
              ]
            },
            {
              "position": 2,
              "blocks": [
                ${hasAuthenticImages ? '''{
                  "blockType": "media",
                  "position": 1,
                  "caption": "Diagram: Structural overview and mechanism",
                  "content": {
                    "url": "",
                    "type": "image",
                    "caption": "Diagram: Structural overview and mechanism"
                  }
                },''' : ''}
                {
                  "blockType": "text",
                  "position": ${hasAuthenticImages ? 2 : 1},
                  "content": {
                    "text": "Detailed analysis of how this process functions step-by-step with **key formulas** and mechanisms."
                  }
                }
              ]
            },
            {
              "position": 3,
              "blocks": [
                {
                  "blockType": "text",
                  "position": 1,
                  "content": {
                    "text": "### Knowledge Checkpoint\\nTest your understanding before completing this module."
                  }
                },
                {
                  "blockType": "test",
                  "position": 2,
                  "content": {
                    "question": "Conceptual checkpoint question?",
                    "explanation": "Detailed explanation of why the correct option is right.",
                    "is_multiple_choice": false,
                    "options": [
                      {"text": "Option A text", "is_correct": true},
                      {"text": "Option B text", "is_correct": false},
                      {"text": "Option C text", "is_correct": false},
                      {"text": "Option D text", "is_correct": false}
                    ]
                  }
                }
              ]
            }
          ]
        }
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

    if (attachment != null) {
      if (attachment.extractedText != null &&
          attachment.extractedText!.isNotEmpty) {
        contentParts.add(
          Content.text(
            'Extracted Study Content from attached presentation/document ($fileName):\n\n'
            '${attachment.extractedText}\n\n'
            'Additional user focus/instructions: ${promptOrInstructions.isEmpty ? "Cover key principles thoroughly" : promptOrInstructions}\n'
            'Scope: $lessonScope ($subChapterCount subchapters, $pagesPerSubChapter pages each)\n'
            'Audience Level: $audience',
          ),
        );
      } else if (attachment.rawBytesForGemini != null) {
        contentParts.add(
          Content.multi([
            DataPart(attachment.mimeType, attachment.rawBytesForGemini!),
            TextPart(
              'Generate a structured interactive course lesson based on the attached file ($fileName).\n'
              'Scope: $lessonScope ($subChapterCount subchapters, $pagesPerSubChapter pages each)\n'
              'Audience Level: $audience\n'
              'Additional user focus/instructions: ${promptOrInstructions.isEmpty ? "Cover key principles thoroughly" : promptOrInstructions}',
            ),
          ]),
        );
      }
    } else {
      contentParts.add(
        Content.text(
          'Topic / Lesson Prompt: $promptOrInstructions\n'
          'Scope: $lessonScope ($subChapterCount subchapters, $pagesPerSubChapter pages each)\n'
          'Audience Level: $audience\n'
          'Please generate the complete course lesson structure now in JSON format.',
        ),
      );
    }

    final response = await model.generateContent(contentParts);
    final rawText = response.text;

    if (rawText == null || rawText.trim().isEmpty) {
      throw Exception('AI returned an empty response. Please try again.');
    }

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
      throw Exception('Invalid lesson structure received from AI.');
    }

    return decoded;
  }
}
