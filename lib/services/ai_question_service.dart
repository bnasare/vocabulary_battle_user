import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../core/ai_constants.dart';
import '../models/game_mode.dart';
import '../models/question_model.dart';

/// Exception thrown when AI service encounters an error
class AIServiceException implements Exception {
  final String message;
  final String? details;

  AIServiceException(this.message, [this.details]);

  @override
  String toString() => details != null ? '$message: $details' : message;
}

/// Service for generating vocabulary questions using AI
class AIQuestionService {
  late final Dio _dio;

  AIQuestionService() {
    _dio = Dio(BaseOptions(
      baseUrl: AIConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': AIConstants.apiKey,
      },
    ));

    // Add logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
    ));
  }

  /// Generate questions for a specific game mode
  ///
  /// [selectedLetters] - Pre-selected letters by user (empty for AI to choose)
  /// [gameMode] - The game mode to determine question count
  /// [creatorId] - User ID creating the questions
  ///
  /// Returns a map containing selectedLetters and list of Question objects
  Future<Map<String, dynamic>> generateQuestions({
    required List<String> selectedLetters,
    required GameMode gameMode,
    required String creatorId,
  }) async {
    try {
      final systemPrompt = AIConstants.buildSystemPrompt(gameMode);
      final userPrompt = AIConstants.buildUserPrompt(selectedLetters, gameMode);

      final response = await _dio.post(
        AIConstants.chatCompletionsEndpoint,
        data: {
          'models': [AIConstants.model],
          'messages': [
            {
              'system': [
                {'type': 'text', 'text': systemPrompt}
              ]
            },
            {
              'user': [
                {'type': 'text', 'text': userPrompt}
              ]
            }
          ],
          'temperature': AIConstants.temperature,
          'max_tokens': AIConstants.maxTokens,
          'frequency_penalty': AIConstants.frequencyPenalty,
          'presence_penalty': AIConstants.presencePenalty,
          'top_p': AIConstants.topP,
          'stream': false,
          'web_search': false,
          'combination': false,
          'comparison': false,
        },
      );

      return _parseResponse(response.data, gameMode, creatorId, selectedLetters);
    } on DioException catch (e) {
      throw AIServiceException(_handleDioError(e));
    } catch (e) {
      throw AIServiceException('Unexpected error', e.toString());
    }
  }

  /// Parse the API response and convert to Question objects
  Map<String, dynamic> _parseResponse(
    Map<String, dynamic> data,
    GameMode gameMode,
    String creatorId,
    List<String> preSelectedLetters,
  ) {
    try {
      // Navigate the nested response structure
      if (!data.containsKey('success') || data['success'] != true) {
        throw AIServiceException('API returned unsuccessful response');
      }

      final responses = data['responses'];
      if (responses == null) {
        throw AIServiceException('No responses in API response');
      }

      final responseData = responses['responses'];
      if (responseData == null) {
        throw AIServiceException('No response data in API response');
      }

      final modelResponse = responseData[AIConstants.model];
      if (modelResponse == null) {
        throw AIServiceException('No model response for ${AIConstants.model}');
      }

      final message = modelResponse['message'];
      if (message == null) {
        throw AIServiceException('No message in model response');
      }

      String content = message['content'];
      if (content.isEmpty) {
        throw AIServiceException('Empty content in response');
      }

      // Check if response was truncated
      final finishReason = modelResponse['finish_reason'];
      if (finishReason == 'length') {
        throw AIServiceException(
          'Response was truncated',
          'The AI response was cut off. Try again or reduce the number of questions.',
        );
      }

      // Remove markdown code blocks if present
      content = content.trim();
      if (content.startsWith('```json')) {
        content = content.replaceFirst('```json', '').trim();
      }
      if (content.startsWith('```')) {
        content = content.replaceFirst('```', '').trim();
      }
      if (content.endsWith('```')) {
        content = content.substring(0, content.length - 3).trim();
      }

      // Parse JSON
      final Map<String, dynamic> parsed = jsonDecode(content);

      // Extract selected letters
      final selectedLettersFromAI = List<String>.from(
        parsed['selectedLetters'] ?? preSelectedLetters,
      );

      if (selectedLettersFromAI.length != 3) {
        throw AIServiceException('Expected 3 letters, got ${selectedLettersFromAI.length}');
      }

      // Extract questions array
      final questionsJson = List<Map<String, dynamic>>.from(parsed['questions'] ?? []);

      if (questionsJson.isEmpty) {
        throw AIServiceException('No questions generated');
      }

      // Validate question count
      if (questionsJson.length != gameMode.totalQuestions) {
        throw AIServiceException(
          'Expected ${gameMode.totalQuestions} questions, got ${questionsJson.length}',
        );
      }

      // Convert to Question objects
      final questions = questionsJson.map((questionJson) {
        return _createQuestionFromJson(
          questionJson,
          creatorId,
          selectedLettersFromAI,
        );
      }).toList();

      // Validate questions
      _validateQuestions(questions, gameMode, selectedLettersFromAI);

      return {
        'selectedLetters': selectedLettersFromAI,
        'questions': questions,
      };
    } on FormatException catch (e) {
      throw AIServiceException('Invalid JSON format', e.toString());
    } catch (e) {
      if (e is AIServiceException) rethrow;
      throw AIServiceException('Failed to parse response', e.toString());
    }
  }

  /// Create a Question object from JSON data
  Question _createQuestionFromJson(
    Map<String, dynamic> json,
    String creatorId,
    List<String> selectedLetters,
  ) {
    final isRandom = json['isRandom'] == true;
    final letter = isRandom ? null : (json['letter'] as String?)?.toUpperCase();
    final letterOrder = json['letterOrder'] as int?;
    final questionNumberInLetter = json['questionNumberInLetter'] as int? ?? 1;
    final definition = json['definition'] as String? ?? '';
    final answer = json['answer'] as String? ?? '';

    if (definition.isEmpty) {
      throw AIServiceException('Question has empty definition');
    }

    if (answer.isEmpty) {
      throw AIServiceException('Question has empty answer');
    }

    // Validate answer starts with letter for non-random questions
    if (!isRandom && letter != null) {
      final answerFirstLetter = answer.trim()[0].toUpperCase();
      if (answerFirstLetter != letter) {
        throw AIServiceException(
          'Answer validation failed',
          'Answer "$answer" should start with "$letter" but starts with "$answerFirstLetter"',
        );
      }
    }

    return Question(
      id: const Uuid().v4(), // Generate unique ID for practice mode
      creatorId: creatorId,
      letter: letter ?? '',
      letterOrder: letterOrder ?? 4, // Random questions use letterOrder 4
      questionNumberInLetter: questionNumberInLetter,
      definition: definition.trim(),
      answer: answer.trim(),
      isRandom: isRandom,
      createdAt: DateTime.now(),
    );
  }

  /// Validate the generated questions
  void _validateQuestions(
    List<Question> questions,
    GameMode gameMode,
    List<String> selectedLetters,
  ) {
    // Count questions per letter
    final letterCounts = <String, int>{};
    int randomCount = 0;

    for (final question in questions) {
      if (question.isRandom) {
        randomCount++;
      } else {
        letterCounts[question.letter] = (letterCounts[question.letter] ?? 0) + 1;
      }
    }

    // Validate counts per letter
    for (final letter in selectedLetters) {
      final count = letterCounts[letter] ?? 0;
      if (count != gameMode.questionsPerLetter) {
        throw AIServiceException(
          'Invalid question count for letter $letter',
          'Expected ${gameMode.questionsPerLetter}, got $count',
        );
      }
    }

    // Validate random question count
    if (randomCount != gameMode.randomQuestions) {
      throw AIServiceException(
        'Invalid random question count',
        'Expected ${gameMode.randomQuestions}, got $randomCount',
      );
    }
  }

  /// Handle Dio errors and convert to user-friendly messages
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet and try again.';
      case DioExceptionType.sendTimeout:
        return 'Request timeout. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout. The AI is taking too long to respond.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return 'Authentication failed. Please contact support.';
        } else if (statusCode == 429) {
          return 'Too many requests. Please wait a moment and try again.';
        } else if (statusCode == 500) {
          return 'Server error. Please try again later.';
        }
        return 'Server returned error: $statusCode';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.connectionError:
        return 'Network error. Please check your internet connection.';
      case DioExceptionType.badCertificate:
        return 'Security error. Please try again.';
      case DioExceptionType.unknown:
      default:
        return 'Network error: ${e.message ?? "Unknown error"}';
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
