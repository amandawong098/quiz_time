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
    List<Uint8List>? filesBytes,
    List<String>? filesNames,
    Uint8List? fileBytes,
    String? fileMimeType,
    String? fileName,
    String lessonScope = 'Auto', // Auto-decided based on complexity & length
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

    // Process uploaded attachment(s) if any (PPTX, DOCX, Images, PDF, Audio, etc.)
    ProcessedAttachment? attachment;
    final List<Uint8List> allBytes = [
      if (filesBytes != null) ...filesBytes,
      if (fileBytes != null &&
          (filesBytes == null || !filesBytes.contains(fileBytes)))
        fileBytes,
    ];
    final List<String> allNames = [
      if (filesNames != null) ...filesNames,
      if (fileName != null &&
          (filesNames == null || !filesNames.contains(fileName)))
        fileName,
    ];

    if (allBytes.isNotEmpty && allNames.isNotEmpty) {
      attachment = await AIAttachmentHelper.processAttachments(
        filesBytes: allBytes,
        filesNames: allNames,
      );
    }

    List<String> candidateModels = [];
    try {
      final liveModels = await AIQuizService.listAvailableModelsForApiKey(
        apiKey,
      );
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
          final imagePrompt =
              result['imagePrompt'] as String? ??
              result['title'] as String? ??
              promptOrInstructions;
          try {
            final imageUrl = await AIQuizService.generateAndUploadCoverImage(
              imagePrompt,
            );
            if (imageUrl != null) {
              result['imageUrl'] = imageUrl;
            }
          } catch (e) {
            debugPrint('Cover image generation error: $e');
          }
        }

        // 2. Embed Authentic Images Extracted From Attached File (PPTX / Images / DOCX / PDF)
        if (attachment != null && attachment.extractedImageUrls.isNotEmpty) {
          final authenticUrls = attachment.extractedImageUrls;
          int fallbackIdx = 0;
          final Set<int> usedIndices = {};

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
                  if (block['blockType'] == 'media') {
                    // Check if Gemini specified a targeted figureIndex (1-based)
                    final int? figIdx = (block['figureIndex'] as num?)?.toInt() ??
                        (block['content'] is Map
                            ? (block['content']['figureIndex'] as num?)?.toInt()
                            : null);

                    String? targetUrl;
                    if (figIdx != null &&
                        figIdx >= 1 &&
                        figIdx <= authenticUrls.length) {
                      targetUrl = authenticUrls[figIdx - 1];
                      usedIndices.add(figIdx - 1);
                    } else {
                      // Fallback: Pick next unused authentic figure
                      while (fallbackIdx < authenticUrls.length &&
                          usedIndices.contains(fallbackIdx)) {
                        fallbackIdx++;
                      }
                      if (fallbackIdx < authenticUrls.length) {
                        targetUrl = authenticUrls[fallbackIdx];
                        usedIndices.add(fallbackIdx);
                        fallbackIdx++;
                      } else if (authenticUrls.isNotEmpty) {
                        targetUrl = authenticUrls[0];
                      }
                    }

                    if (targetUrl != null) {
                      block['content'] = {
                        'url': targetUrl,
                        'type': 'image',
                        'caption': block['caption'] ??
                            (block['content'] is Map
                                ? block['content']['caption']
                                : null) ??
                            'Figure from attached document',
                      };
                    }
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

  static String _detectImageMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static Future<Map<String, dynamic>> _executeLessonGeneration({
    required String modelName,
    required String apiKey,
    required String promptOrInstructions,
    ProcessedAttachment? attachment,
    String? fileName,
    String lessonScope = 'Auto',
    required String audience,
    required bool hasAuthenticImages,
  }) async {
    final mediaGuideline = hasAuthenticImages
        ? '- Page 2: In-depth visual explanation:\n     - 1 \'media\' block with a targeted "caption" and "figureIndex": [1, 2, 3...] pointing to the exact matching Figure provided in the prompt.\n     - 1 \'text\' block explaining the core mechanism or breakdown.'
        : '- Page 2: Deep-dive concept breakdown:\n     - 1 \'text\' block with detailed step-by-step principles, formulas, bullet points, and core mechanisms.';

    final systemPrompt =
        '''
You are an expert instructional designer and interactive e-learning curriculum architect for LearnByte.
Your task is to generate structured, bite-sized, interactive multi-page course lessons based on user prompts or uploaded study materials.

Curriculum Structure Rules:
1. Generate 1 Course with a catchy title, description, and vivid 3D cover "imagePrompt".
2. Generate 1 Chapter with title and position: 1.
3. Autonomous Curriculum Scope & Structure:
   - Carefully analyze the breadth, technical complexity, and depth of the provided learning topic (or attached study materials).
   - Automatically determine the optimal number of SubChapters (modules) needed to cover the subject thoroughly:
     * Simple, introductory, or focused topics: generate 1 to 2 SubChapters.
     * Moderate or standard conceptual topics: generate 2 to 3 SubChapters.
     * Broad, complex, or extensive academic/technical topics (or full multi-slide presentations / documents): generate 3 to 5 SubChapters.
   - For each SubChapter, automatically determine the optimal number of slide pages (typically 3 to 5 bite-sized mobile pages) needed to teach the subtopic with clarity.
   - Assign xpReward: 10 for each SubChapter.
4. Slide Page Guidelines (Bite-sized mobile formatting):
   - Page 1: Concept Introduction & Key Definitions (text block with '# Heading', formatted bold keywords and bullets).
   $mediaGuideline
   - Final Page of each SubChapter MUST end with an interactive checkpoint:
     - 1 'text' summary block.
     - 1 'test' block with a targeted conceptual question, 3-4 options (1 or multiple is_correct), and a clear educational explanation.
5. Figure Matching Rule (when authentic figures are attached):
   - Inspect the numbered figures (Figure #1, Figure #2...) provided in this prompt.
   - For every 'media' block, set "figureIndex" to the exact 1-based number of the figure that matches the concept taught on that page.
   - Write a specific, descriptive "caption" directly explaining what is illustrated in that specific figure.
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
          "xpReward": 10,
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
                  "figureIndex": 1,
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
      final hasText =
          attachment.extractedText != null &&
          attachment.extractedText!.isNotEmpty;
      final rawParts = attachment.rawMediaParts;

      if (rawParts.isNotEmpty) {
        final List<Part> parts = [];
        for (final p in rawParts) {
          parts.add(DataPart(p.mimeType, p.bytes));
        }

        // Pass extracted authentic figures as numbered visual parts so Gemini can visually inspect them
        final extractedBytes = attachment.extractedImageBytes;
        if (extractedBytes.isNotEmpty) {
          parts.add(
            TextPart(
              '\n=== NUMBERED EXTRACTED FIGURES (${extractedBytes.length} total) ===\n'
              'The following images were extracted from the attached document. '
              'Visually inspect each numbered figure. In your "media" slide blocks, specify "figureIndex": N (where N is the 1-based number below) '
              'so that the exact corresponding picture is placed on the slide teaching that concept.\n',
            ),
          );

          for (int i = 0; i < extractedBytes.length && i < 10; i++) {
            final img = extractedBytes[i];
            final mime = _detectImageMimeType(img);
            if (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp') {
              parts.add(TextPart('\n--- Figure #${i + 1} ---'));
              parts.add(DataPart(mime, img));
            }
          }
        }

        parts.add(
          TextPart(
            '\n=== CURRICULUM GENERATION INSTRUCTIONS ===\n'
            'Generate a structured interactive course lesson based on the attached file(s) (${fileName ?? "Uploaded study materials"}).\n'
            '${attachment.extractedImageUrls.isNotEmpty ? "Assign 'figureIndex' (1, 2, ...) in each 'media' block to match the relevant Figure with its slide.\n" : ""}'
            '${hasText ? "\nAdditional Extracted Study Content:\n${attachment.extractedText}\n" : ""}\n'
            'Structure Strategy: Auto-determine the optimal number of SubChapters and slides based on content complexity and length.\n'
            'Audience Level: $audience\n'
            'Additional user focus/instructions: ${promptOrInstructions.isEmpty ? "Cover key principles thoroughly" : promptOrInstructions}',
          ),
        );
        contentParts.add(Content.multi(parts));
      } else if (hasText || attachment.extractedImageBytes.isNotEmpty) {
        final List<Part> parts = [];
        final extractedBytes = attachment.extractedImageBytes;

        if (extractedBytes.isNotEmpty) {
          parts.add(
            TextPart(
              '\n=== NUMBERED EXTRACTED FIGURES (${extractedBytes.length} total) ===\n'
              'The following images were extracted from the attached document. '
              'Visually inspect each numbered figure. In your "media" slide blocks, specify "figureIndex": N (where N is the 1-based number below) '
              'so that the exact corresponding picture is placed on the slide teaching that concept.\n',
            ),
          );

          for (int i = 0; i < extractedBytes.length && i < 10; i++) {
            final img = extractedBytes[i];
            final mime = _detectImageMimeType(img);
            if (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp') {
              parts.add(TextPart('\n--- Figure #${i + 1} ---'));
              parts.add(DataPart(mime, img));
            }
          }
        }

        parts.add(
          TextPart(
            'Extracted Study Content from attached materials (${fileName ?? "Uploaded study materials"}):\n\n'
            '${attachment.extractedText ?? ""}\n\n'
            '${attachment.extractedImageUrls.isNotEmpty ? "Assign 'figureIndex' (1, 2, ...) in each 'media' block to match the relevant Figure with its slide.\n" : ""}'
            'Additional user focus/instructions: ${promptOrInstructions.isEmpty ? "Cover key principles thoroughly" : promptOrInstructions}\n'
            'Structure Strategy: Auto-determine the optimal number of SubChapters and slides based on content complexity and length.\n'
            'Audience Level: $audience',
          ),
        );
        contentParts.add(Content.multi(parts));
      }
    } else {
      contentParts.add(
        Content.text(
          'Topic / Lesson Prompt: $promptOrInstructions\n'
          'Structure Strategy: Auto-determine the optimal number of SubChapters and slides based on topic complexity and breadth.\n'
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
