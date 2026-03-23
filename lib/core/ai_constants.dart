import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/game_mode.dart';

/// AI service configuration constants
class AIConstants {
  /// alle-ai.com API key loaded from .env
  static String get apiKey {
    final key = dotenv.env['ALLE_AI_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw StateError('Missing ALLE_AI_API_KEY in .env');
    }
    return key;
  }

  /// Optional OpenAI key loaded from .env for future integrations
  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  /// alle-ai.com API base URL
  static const String apiBaseUrl = 'https://api.alle-ai.com/api/v1';

  /// API endpoint for chat completions
  static const String chatCompletionsEndpoint = '/chat/completions';

  /// Model to use for question generation
  static const String model = 'gpt-4o';

  /// Maximum tokens for API response
  static const int maxTokens = 2000;

  /// Temperature for creativity (0.0 - 1.0)
  static const double temperature = 0.8;

  /// Frequency penalty to avoid repetition
  static const double frequencyPenalty = 0.2;

  /// Presence penalty for diverse topics
  static const double presencePenalty = 0.3;

  /// Top P sampling parameter
  static const double topP = 1.0;

  /// Maximum regeneration attempts per game session
  static const int maxRegenerations = 1;

  /// Build system prompt based on game mode
  static String buildSystemPrompt(GameMode mode) {
    final questionsPerLetter = mode.questionsPerLetter;
    final randomQuestions = mode.randomQuestions;
    final totalQuestions = mode.totalQuestions;

    return '''You are a vocabulary question generator. Generate exactly $totalQuestions questions for a vocabulary learning game.

REQUIREMENTS:
1. Select 3 random capital letters (A-Z)
2. For each letter, create $questionsPerLetter questions where the answer MUST start with that letter
3. Create $randomQuestions additional "random" questions where answers can start with any letter
4. Questions should be educational, appropriate, and fun
5. Definitions should be clear clues without giving away the answer
6. Answers MUST be single words only (no phrases, no hyphens, no spaces)
7. Mix difficulty levels: some easy, some medium, some challenging

EXACT JSON FORMAT REQUIRED (no markdown, no extra text):
{
  "selectedLetters": ["X", "Y", "Z"],
  "questions": [
    {
      "letter": "X",
      "letterOrder": 1,
      "questionNumberInLetter": 1,
      "definition": "A musical instrument with wooden bars struck by mallets",
      "answer": "Xylophone",
      "isRandom": false
    },
    {
      "letter": "Y",
      "letterOrder": 2,
      "questionNumberInLetter": 1,
      "definition": "A color between green and orange",
      "answer": "Yellow",
      "isRandom": false
    },
    {
      "letter": "Z",
      "letterOrder": 3,
      "questionNumberInLetter": 1,
      "definition": "A place where wild animals are kept for exhibition",
      "answer": "Zoo",
      "isRandom": false
    },
    {
      "letter": null,
      "letterOrder": null,
      "questionNumberInLetter": 1,
      "definition": "The natural satellite of Earth",
      "answer": "Moon",
      "isRandom": true
    }
  ]
}

IMPORTANT:
- VERIFY: Each non-random answer MUST start with its assigned letter (e.g., letter "B" = answer starts with "B")
- First ${questionsPerLetter * 3} questions MUST be organized by letter (letterOrder 1, 2, 3)
- Last $randomQuestions questions MUST have isRandom: true, letter: null, letterOrder: null
- questionNumberInLetter starts at 1 for each letter and for random questions
- Return ONLY the JSON object, no markdown code blocks, no extra text''';
  }

  /// Build user prompt for question generation
  /// selectedLetters MUST contain exactly 3 letters
  static String buildUserPrompt(List<String> selectedLetters, GameMode mode) {
    assert(
      selectedLetters.length == 3,
      'Must provide exactly 3 selected letters. Got: ${selectedLetters.length}',
    );

    return '''Generate ${mode.totalQuestions} vocabulary questions using these letters: ${selectedLetters.join(', ')}.

CRITICAL: Each answer MUST start with its assigned letter. Double-check every answer before including it.

For letter "${selectedLetters[0]}" (letterOrder: 1): create ${mode.questionsPerLetter} questions - ALL answers MUST start with "${selectedLetters[0]}"
For letter "${selectedLetters[1]}" (letterOrder: 2): create ${mode.questionsPerLetter} questions - ALL answers MUST start with "${selectedLetters[1]}"
For letter "${selectedLetters[2]}" (letterOrder: 3): create ${mode.questionsPerLetter} questions - ALL answers MUST start with "${selectedLetters[2]}"
Random questions (any letter, isRandom: true): create ${mode.randomQuestions} questions

Return ONLY the JSON object with the exact format from the system prompt.''';
  }
}
