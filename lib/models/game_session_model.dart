import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_mode.dart';

class GameSession {
  final String id;
  final String player1Id;
  final String player2Id;
  final DateTime createdAt;
  final DateTime submissionDeadline;
  final DateTime battleDate;
  final String status; // preparation, ready, active, completed
  final GameMode gameMode; // Game mode configuration
  final PlayerProgress player1Progress;
  final PlayerProgress player2Progress;
  final GameResult? result;

  GameSession({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    required this.createdAt,
    required this.submissionDeadline,
    required this.battleDate,
    required this.status,
    GameMode? gameMode,
    required this.player1Progress,
    required this.player2Progress,
    this.result,
  }) : gameMode = gameMode ?? GameMode.challenge;

  factory GameSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameSession(
      id: doc.id,
      player1Id: data['player1Id'] ?? '',
      player2Id: data['player2Id'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submissionDeadline:
          (data['submissionDeadline'] as Timestamp?)?.toDate() ??
              DateTime.now(),
      battleDate:
          (data['battleDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'preparation',
      gameMode: GameMode.fromString(data['gameMode']),
      player1Progress: PlayerProgress.fromMap(data['player1Progress'] ?? {}),
      player2Progress: PlayerProgress.fromMap(data['player2Progress'] ?? {}),
      result:
          data['result'] != null ? GameResult.fromMap(data['result']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'player1Id': player1Id,
      'player2Id': player2Id,
      'createdAt': Timestamp.fromDate(createdAt),
      'submissionDeadline': Timestamp.fromDate(submissionDeadline),
      'battleDate': Timestamp.fromDate(battleDate),
      'status': status,
      'gameMode': gameMode.value,
      'player1Progress': player1Progress.toMap(),
      'player2Progress': player2Progress.toMap(),
      if (result != null) 'result': result!.toMap(),
    };
  }

  GameSession copyWith({
    String? id,
    String? player1Id,
    String? player2Id,
    DateTime? createdAt,
    DateTime? submissionDeadline,
    DateTime? battleDate,
    String? status,
    GameMode? gameMode,
    PlayerProgress? player1Progress,
    PlayerProgress? player2Progress,
    GameResult? result,
  }) {
    return GameSession(
      id: id ?? this.id,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      createdAt: createdAt ?? this.createdAt,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      battleDate: battleDate ?? this.battleDate,
      status: status ?? this.status,
      gameMode: gameMode ?? this.gameMode,
      player1Progress: player1Progress ?? this.player1Progress,
      player2Progress: player2Progress ?? this.player2Progress,
      result: result ?? this.result,
    );
  }

  /// Check if both players have submitted their questions
  bool get bothPlayersSubmitted =>
      player1Progress.hasSubmitted && player2Progress.hasSubmitted;

  /// Check if game is ready to start
  bool get canStartBattle =>
      bothPlayersSubmitted && DateTime.now().isAfter(battleDate);

  /// Get total questions required for this game mode
  int get totalQuestionsRequired => gameMode.totalQuestions;

  /// Get questions per letter for this game mode
  int get questionsPerLetter => gameMode.questionsPerLetter;

  /// Get random questions count for this game mode
  int get randomQuestionsCount => gameMode.randomQuestions;

  /// Check if player 1 has completed the battle
  bool get player1HasCompletedBattle =>
      player1Progress.questionsAnswered >= totalQuestionsRequired;

  /// Check if player 2 has completed the battle
  bool get player2HasCompletedBattle =>
      player2Progress.questionsAnswered >= totalQuestionsRequired;

  /// Check if both players have completed the battle
  bool get bothPlayersCompletedBattle =>
      player1HasCompletedBattle && player2HasCompletedBattle;
}

class PlayerProgress {
  final bool hasSubmitted;
  final DateTime? submittedAt;
  final List<String> selectedLetters;
  final int questionsCreated;
  final int questionsAnswered;
  final int correctAnswers;
  final int score;

  PlayerProgress({
    this.hasSubmitted = false,
    this.submittedAt,
    this.selectedLetters = const [],
    this.questionsCreated = 0,
    this.questionsAnswered = 0,
    this.correctAnswers = 0,
    this.score = 0,
  });

  factory PlayerProgress.fromMap(Map<String, dynamic> map) {
    return PlayerProgress(
      hasSubmitted: map['hasSubmitted'] ?? false,
      submittedAt: map['submittedAt'] != null
          ? (map['submittedAt'] as Timestamp).toDate()
          : null,
      selectedLetters: List<String>.from(map['selectedLetters'] ?? []),
      questionsCreated: map['questionsCreated'] ?? 0,
      questionsAnswered: map['questionsAnswered'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      score: map['score'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasSubmitted': hasSubmitted,
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      'selectedLetters': selectedLetters,
      'questionsCreated': questionsCreated,
      'questionsAnswered': questionsAnswered,
      'correctAnswers': correctAnswers,
      'score': score,
    };
  }

  PlayerProgress copyWith({
    bool? hasSubmitted,
    DateTime? submittedAt,
    List<String>? selectedLetters,
    int? questionsCreated,
    int? questionsAnswered,
    int? correctAnswers,
    int? score,
  }) {
    return PlayerProgress(
      hasSubmitted: hasSubmitted ?? this.hasSubmitted,
      submittedAt: submittedAt ?? this.submittedAt,
      selectedLetters: selectedLetters ?? this.selectedLetters,
      questionsCreated: questionsCreated ?? this.questionsCreated,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      score: score ?? this.score,
    );
  }

  double get accuracy =>
      questionsAnswered > 0 ? (correctAnswers / questionsAnswered) * 100 : 0.0;
}

class GameResult {
  final String? winnerId;
  final int player1FinalScore;
  final int player2FinalScore;
  final DateTime completedAt;

  GameResult({
    this.winnerId,
    required this.player1FinalScore,
    required this.player2FinalScore,
    required this.completedAt,
  });

  factory GameResult.fromMap(Map<String, dynamic> map) {
    return GameResult(
      winnerId: map['winnerId'],
      player1FinalScore: map['player1FinalScore'] ?? 0,
      player2FinalScore: map['player2FinalScore'] ?? 0,
      completedAt:
          (map['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'winnerId': winnerId,
      'player1FinalScore': player1FinalScore,
      'player2FinalScore': player2FinalScore,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }

  bool get isTie => player1FinalScore == player2FinalScore;
}
