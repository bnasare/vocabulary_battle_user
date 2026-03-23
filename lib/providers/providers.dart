import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/ai_question_service.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';

// ==================== SERVICE PROVIDERS ====================

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final aiQuestionServiceProvider = Provider<AIQuestionService>((ref) {
  return AIQuestionService();
});

// ==================== AUTH PROVIDERS ====================

/// Firebase auth state changes stream
/// Persists throughout app lifecycle to ensure reliable auth state during initialization
final authStateProvider = StreamProvider.autoDispose<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current user model
/// Using autoDispose to ensure clean state when switching users
final currentUserProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;

  if (userId == null) {
    return Stream.value(null);
  }

  return authService.getCurrentUserModelStream();
});

/// Current user ID
/// Using autoDispose to prevent caching old user ID
final currentUserIdProvider = Provider.autoDispose<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUserId;
});

// ==================== GAME SESSION PROVIDERS ====================

/// Active game session stream
/// Using autoDispose to clean up stream when user logs out
final activeGameSessionProvider =
    StreamProvider.autoDispose<GameSession?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  return firestoreService.streamActiveGameSession(userId);
});

/// Game history provider
/// Using autoDispose to prevent showing old user's game history
final gameHistoryProvider =
    FutureProvider.autoDispose.family<List<GameSession>, String>((ref, userId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getGameHistory(userId);
});

// ==================== STATE NOTIFIERS ====================

/// Loading state provider
/// Using autoDispose to reset loading state between sessions
final loadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Error message provider
/// Using autoDispose to clear error messages between sessions
final errorMessageProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Success message provider
/// Using autoDispose to clear success messages between sessions
final successMessageProvider =
    StateProvider.autoDispose<String?>((ref) => null);
