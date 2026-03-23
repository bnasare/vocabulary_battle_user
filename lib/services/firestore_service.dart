import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';
import '../models/game_mode.dart';
import '../models/question_model.dart';
import '../models/admin_action_model.dart';
import '../core/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== GAME SESSIONS ====================

  /// Create a new game session
  Future<String> createGameSession({
    required String player1Id,
    required String player2Id,
    required DateTime submissionDeadline,
    required DateTime battleDate,
    GameMode? gameMode,
  }) async {
    final session = GameSession(
      id: '',
      player1Id: player1Id,
      player2Id: player2Id,
      createdAt: DateTime.now(),
      submissionDeadline: submissionDeadline,
      battleDate: battleDate,
      status: GameStatus.preparation,
      gameMode: gameMode,
      player1Progress: PlayerProgress(),
      player2Progress: PlayerProgress(),
    );

    final docRef = await _firestore
        .collection(FirestoreCollections.gameSessions)
        .add(session.toMap());

    return docRef.id;
  }

  /// Get current active game session
  Future<GameSession?> getActiveGameSession(String userId) async {
    final querySnapshot = await _firestore
        .collection(FirestoreCollections.gameSessions)
        .where('status', whereIn: [
          GameStatus.preparation,
          GameStatus.ready,
          GameStatus.active
        ])
        .where(Filter.or(
          Filter('player1Id', isEqualTo: userId),
          Filter('player2Id', isEqualTo: userId),
        ))
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return GameSession.fromFirestore(querySnapshot.docs.first);
  }

  /// Stream active game session
  Stream<GameSession?> streamActiveGameSession(String userId) {
    return _firestore
        .collection(FirestoreCollections.gameSessions)
        .where(Filter.or(
          Filter('player1Id', isEqualTo: userId),
          Filter('player2Id', isEqualTo: userId),
        ))
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final session = GameSession.fromFirestore(snapshot.docs.first);
      if (session.status == GameStatus.completed) return null;
      return session;
    });
  }

  /// Stream a specific game session by ID
  Stream<GameSession> watchGameSession(String sessionId) {
    return _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .snapshots()
        .map((doc) => GameSession.fromFirestore(doc));
  }

  /// Update game session
  Future<void> updateGameSession(
      String sessionId, Map<String, dynamic> data) async {
    await _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .update(data);
  }

  /// Update player progress
  Future<void> updatePlayerProgress({
    required String sessionId,
    required String playerId,
    required Map<String, dynamic> progressData,
  }) async {
    final session = await _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .get();

    if (!session.exists) return;

    final sessionData = GameSession.fromFirestore(session);
    final field = sessionData.player1Id == playerId
        ? 'player1Progress'
        : 'player2Progress';

    // Use dot notation to update specific fields without replacing the entire object
    final updateData = <String, dynamic>{};
    progressData.forEach((key, value) {
      updateData['$field.$key'] = value;
    });

    await _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .update(updateData);
  }

  /// Check if both players have completed battle and mark game as completed
  Future<void> checkAndCompleteGame(String sessionId) async {
    final sessionDoc = await _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) return;

    final session = GameSession.fromFirestore(sessionDoc);

    // Check if both players have completed the battle (answered all questions for this game mode)
    final player1Complete = session.player1Progress.questionsAnswered >= session.totalQuestionsRequired;
    final player2Complete = session.player2Progress.questionsAnswered >= session.totalQuestionsRequired;

    if (player1Complete && player2Complete) {
      // Both players done - mark game as completed
      // This triggers the calculateResults Cloud Function
      await _firestore
          .collection(FirestoreCollections.gameSessions)
          .doc(sessionId)
          .update({
        'status': GameStatus.completed,
        'player1Progress.score': session.player1Progress.correctAnswers,
        'player2Progress.score': session.player2Progress.correctAnswers,
      });
    }
  }

  // ==================== QUESTIONS ====================

  /// Submit questions for a player
  Future<void> submitQuestions({
    required String sessionId,
    required String playerId,
    required List<Question> questions,
    required List<String> selectedLetters,
  }) async {
    final batch = _firestore.batch();

    // Get session to determine player1 or player2
    final sessionDoc = await _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) throw Exception('Session not found');

    final session = GameSession.fromFirestore(sessionDoc);
    final isPlayer1 = session.player1Id == playerId;
    final subcollection = isPlayer1 ? 'player1Questions' : 'player2Questions';

    // Add questions to subcollection
    for (final question in questions) {
      final docRef = _firestore
          .collection(FirestoreCollections.questions)
          .doc(sessionId)
          .collection(subcollection)
          .doc();

      batch.set(docRef, question.copyWith(id: docRef.id).toMap());
    }

    // Update player progress
    final progressField = isPlayer1 ? 'player1Progress' : 'player2Progress';
    final currentProgress =
        isPlayer1 ? session.player1Progress : session.player2Progress;

    batch.update(sessionDoc.reference, {
      progressField: currentProgress
          .copyWith(
            hasSubmitted: true,
            submittedAt: DateTime.now(),
            selectedLetters: selectedLetters,
            questionsCreated: questions.length,
          )
          .toMap(),
    });

    // Check if both submitted and update status
    final otherProgress =
        isPlayer1 ? session.player2Progress : session.player1Progress;
    if (otherProgress.hasSubmitted) {
      batch.update(sessionDoc.reference, {'status': GameStatus.ready});
    }

    await batch.commit();
  }

  /// Get questions for a player (their opponent's questions)
  Future<List<Question>> getQuestionsForPlayer({
    required String sessionId,
    required String playerId,
  }) async {
    final sessionDoc = await _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) return [];

    final session = GameSession.fromFirestore(sessionDoc);
    final isPlayer1 = session.player1Id == playerId;

    // Player1 answers player2's questions and vice versa
    final subcollection = isPlayer1 ? 'player2Questions' : 'player1Questions';

    final questionsSnapshot = await _firestore
        .collection(FirestoreCollections.questions)
        .doc(sessionId)
        .collection(subcollection)
        .get();

    final questions = questionsSnapshot.docs
        .map((doc) => Question.fromFirestore(doc))
        .toList();

    return Question.sortForBattle(questions);
  }

  /// Submit answer
  Future<void> submitAnswer({
    required String sessionId,
    required PlayerAnswer answer,
  }) async {
    await _firestore
        .collection(FirestoreCollections.playerAnswers)
        .doc(sessionId)
        .collection('answers')
        .add(answer.toMap());
  }

  /// Get all answers for a session
  Future<List<PlayerAnswer>> getPlayerAnswers(String sessionId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.playerAnswers)
        .doc(sessionId)
        .collection('answers')
        .get();

    return snapshot.docs.map((doc) => PlayerAnswer.fromFirestore(doc)).toList();
  }

  // ==================== ADMIN ACTIONS ====================

  /// Log admin action
  Future<void> logAdminAction(AdminAction action) async {
    await _firestore
        .collection(FirestoreCollections.adminActions)
        .add(action.toMap());
  }

  /// Get admin actions stream
  Stream<List<AdminAction>> streamAdminActions({int limit = 50}) {
    return _firestore
        .collection(FirestoreCollections.adminActions)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminAction.fromFirestore(doc))
            .toList());
  }

  // ==================== GAME HISTORY ====================

  /// Archive game to history
  Future<void> archiveGame(String sessionId) async {
    final sessionDoc = await _firestore
        .collection(FirestoreCollections.gameSessions)
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) return;

    // Copy to history
    await _firestore
        .collection(FirestoreCollections.gameHistory)
        .doc(sessionId)
        .set(sessionDoc.data()!);
  }

  /// Get game history
  Future<List<GameSession>> getGameHistory(String userId, {int? limit}) async {
    var query = _firestore
        .collection(FirestoreCollections.gameHistory)
        .where(Filter.or(
          Filter('player1Id', isEqualTo: userId),
          Filter('player2Id', isEqualTo: userId),
        ))
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) => GameSession.fromFirestore(doc)).toList();
  }

  // ==================== USERS ====================

  /// Get all users (for finding opponent)
  Future<List<UserModel>> getAllUsers() async {
    final snapshot =
        await _firestore.collection(FirestoreCollections.users).get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  /// Update user stats
  Future<void> updateUserStats(String userId, UserStats stats) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .update({'stats': stats.toMap()});
  }
}
