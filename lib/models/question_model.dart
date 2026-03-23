import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_mode.dart';

class Question {
  final String id;
  final String creatorId;
  final String letter;
  final int letterOrder; // 1, 2, 3 for the three chosen letters, 4 for random
  final int questionNumberInLetter; // 1-15 for letter questions, 1-5 for random
  final String definition;
  final String answer;
  final bool isRandom;
  final DateTime createdAt;
  final int? difficulty; // Optional: 1-3

  Question({
    required this.id,
    required this.creatorId,
    required this.letter,
    required this.letterOrder,
    required this.questionNumberInLetter,
    required this.definition,
    required this.answer,
    this.isRandom = false,
    required this.createdAt,
    this.difficulty,
  });

  factory Question.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      letter: data['letter'] ?? '',
      letterOrder: data['letterOrder'] ?? 1,
      questionNumberInLetter: data['questionNumberInLetter'] ?? 1,
      definition: data['definition'] ?? '',
      answer: data['answer'] ?? '',
      isRandom: data['isRandom'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      difficulty: data['difficulty'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'letter': letter,
      'letterOrder': letterOrder,
      'questionNumberInLetter': questionNumberInLetter,
      'definition': definition,
      'answer': answer,
      'isRandom': isRandom,
      'createdAt': Timestamp.fromDate(createdAt),
      if (difficulty != null) 'difficulty': difficulty,
    };
  }

  Question copyWith({
    String? id,
    String? creatorId,
    String? letter,
    int? letterOrder,
    int? questionNumberInLetter,
    String? definition,
    String? answer,
    bool? isRandom,
    DateTime? createdAt,
    int? difficulty,
  }) {
    return Question(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      letter: letter ?? this.letter,
      letterOrder: letterOrder ?? this.letterOrder,
      questionNumberInLetter:
          questionNumberInLetter ?? this.questionNumberInLetter,
      definition: definition ?? this.definition,
      answer: answer ?? this.answer,
      isRandom: isRandom ?? this.isRandom,
      createdAt: createdAt ?? this.createdAt,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  /// Get the overall question number based on letter order and position
  /// For challenge mode (default): 1-30 for letters, 31-35 for random
  /// For normal mode: 1-18 for letters, 19-23 for random
  /// For quick mode: 1-12 for letters, 13-15 for random
  int getOverallQuestionNumber(GameMode mode) {
    if (isRandom) {
      return (3 * mode.questionsPerLetter) + questionNumberInLetter;
    }
    return ((letterOrder - 1) * mode.questionsPerLetter) + questionNumberInLetter;
  }

  /// Get the overall question number using challenge mode (for backward compatibility)
  @Deprecated('Use getOverallQuestionNumber(mode) instead')
  int get overallQuestionNumber => getOverallQuestionNumber(GameMode.challenge);

  /// Sort questions in the correct order for battle
  static List<Question> sortForBattle(List<Question> questions) {
    final sorted = List<Question>.from(questions);
    sorted.sort((a, b) {
      if (a.letterOrder != b.letterOrder) {
        return a.letterOrder.compareTo(b.letterOrder);
      }
      return a.questionNumberInLetter.compareTo(b.questionNumberInLetter);
    });
    return sorted;
  }

  /// Group questions by letter
  static Map<String, List<Question>> groupByLetter(List<Question> questions) {
    final Map<String, List<Question>> grouped = {};
    for (var question in questions) {
      if (!grouped.containsKey(question.letter)) {
        grouped[question.letter] = [];
      }
      grouped[question.letter]!.add(question);
    }
    return grouped;
  }
}

/// Model for player's answer to a question
class PlayerAnswer {
  final String id;
  final String playerId;
  final String questionId;
  final String questionCreatorId;
  final String playerAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final DateTime answeredAt;
  final int timeToAnswer; // in seconds

  PlayerAnswer({
    required this.id,
    required this.playerId,
    required this.questionId,
    required this.questionCreatorId,
    required this.playerAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.answeredAt,
    required this.timeToAnswer,
  });

  factory PlayerAnswer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerAnswer(
      id: doc.id,
      playerId: data['playerId'] ?? '',
      questionId: data['questionId'] ?? '',
      questionCreatorId: data['questionCreatorId'] ?? '',
      playerAnswer: data['playerAnswer'] ?? '',
      correctAnswer: data['correctAnswer'] ?? '',
      isCorrect: data['isCorrect'] ?? false,
      answeredAt:
          (data['answeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeToAnswer: data['timeToAnswer'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'questionId': questionId,
      'questionCreatorId': questionCreatorId,
      'playerAnswer': playerAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      'answeredAt': Timestamp.fromDate(answeredAt),
      'timeToAnswer': timeToAnswer,
    };
  }

  /// Check if answer is correct (case-insensitive, trimmed)
  static bool checkAnswer(String playerAnswer, String correctAnswer) {
    return playerAnswer.trim().toLowerCase() ==
        correctAnswer.trim().toLowerCase();
  }
}
