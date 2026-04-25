import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  Future<String> _getApiKey() async {
    // First try to get from .env (for the repository owner / deployed app)
    String key = dotenv.env['GEMINI_API_KEY'] ?? '';
    
    // If not in .env, try to get from SharedPreferences (for other users cloning the repo)
    if (key.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      key = prefs.getString('user_gemini_api_key') ?? '';
    }
    
    return key;
  }

  Future<Map<String, dynamic>> generateQuiz({
    required String title,
    String? description,
    String? subject,
    String? grade,
    int? numQuestions,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      throw Exception('MISSING_API_KEY');
    }

    final model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
    );

    final prompt =
        '''
Generate an educational quiz in JSON format based on the following parameters:
- Title: $title
- Input Description: ${description ?? 'No description provided'}
- Default Subject: ${subject ?? 'General'}
- Default Grade: ${grade ?? 'General'}
- Default Number of Questions: ${numQuestions ?? 10}

TASK:
1. Analyze the "Input Description" provided by the user. 
2. Extract the following if mentioned: 
   - Number of questions (if different from default)
   - Time limit (duration) for each question
   - Difficulty level
3. Rephrase the "Input Description" into a more engaging and professional summary for the quiz.
4. Generate the questions and options based on the Title, Subject, Grade, and the context from the Input Description.

The JSON response MUST follow this exact structure:
{
  "description": "The REPHRASED summary of the quiz",
  "questions": [
    {
      "text": "The question text",
      "durationSeconds": 30, 
      "options": [
        {"text": "Option A", "isCorrect": true},
        {"text": "Option B", "isCorrect": false},
        {"text": "Option C", "isCorrect": false},
        {"text": "Option D", "isCorrect": false}
      ]
    }
  ]
}

- Use the extracted duration if found, otherwise default to 30.
- Ensure there is exactly one correct answer per question.
- Return ONLY the JSON object, no other text or markdown formatting.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;

    if (text == null) {
      throw Exception('Gemini returned an empty response');
    }

    try {
      // Sometimes Gemini wraps the JSON in markdown code blocks
      String cleanJson = text;
      if (cleanJson.contains('```json')) {
        cleanJson = cleanJson.split('```json')[1].split('```')[0];
      } else if (cleanJson.contains('```')) {
        cleanJson = cleanJson.split('```')[1].split('```')[0];
      }

      return jsonDecode(cleanJson.trim()) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse Gemini response: $e\nResponse: $text');
    }
  }
}
