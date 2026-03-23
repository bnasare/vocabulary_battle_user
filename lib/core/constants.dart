import 'package:flutter/material.dart';

/// Collection names for Firestore
class FirestoreCollections {
  static const String users = 'users';
  static const String gameSessions = 'gameSessions';
  static const String questions = 'questions';
  static const String playerAnswers = 'playerAnswers';
  static const String gameHistory = 'gameHistory';
  static const String notifications = 'notifications';
  static const String adminActions = 'adminActions';
}

/// Game configuration constants
/// Note: These values represent the Challenge mode (previously the only mode).
/// The actual values used in a game are determined by the GameMode enum.
class GameConfig {
  static const int questionsPerLetter = 15;
  static const int numberOfLetters = 3;
  static const int randomQuestions = 5;
  static const int totalQuestions =
      (questionsPerLetter * numberOfLetters) + randomQuestions; // Challenge mode: 50 questions
  static const int questionTimeLimit = 45; // seconds
}

/// Game status values
class GameStatus {
  static const String preparation = 'preparation';
  static const String ready = 'ready';
  static const String active = 'active';
  static const String completed = 'completed';
}

/// Letter category colors
class LetterColors {
  static const Color firstLetter = Color(0xFF3B82F6); // Blue
  static const Color secondLetter = Color(0xFF10B981); // Green
  static const Color thirdLetter = Color(0xFF8B5CF6); // Purple
  static const Color random = Color(0xFFF59E0B); // Orange

  static Color getColorForLetterOrder(int letterOrder) {
    switch (letterOrder) {
      case 1:
        return firstLetter;
      case 2:
        return secondLetter;
      case 3:
        return thirdLetter;
      case 4:
        return random;
      default:
        return Colors.grey;
    }
  }

  static String getLabelForLetterOrder(int letterOrder) {
    switch (letterOrder) {
      case 1:
        return 'First Letter';
      case 2:
        return 'Second Letter';
      case 3:
        return 'Third Letter';
      case 4:
        return 'Random';
      default:
        return 'Unknown';
    }
  }
}

/// App color scheme
class AppColors {
  static const Color primary = Color(0xFF1E3A8A); // Deep Blue
  static const Color accent = Color(0xFFF97316); // Bright Orange
  static const Color success = Color(0xFF22C55E); // Green
  static const Color error = Color(0xFFEF4444); // Red
  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
}

/// Notification types
class NotificationTypes {
  static const String reminder = 'reminder';
  static const String gameStart = 'gameStart';
  static const String results = 'results';
  static const String opponentSubmitted = 'opponentSubmitted';
  static const String battleDay = 'battleDay';
}

/// Admin action types
class AdminActionTypes {
  static const String createGame = 'createGame';
  static const String deleteGame = 'deleteGame';
  static const String resetDatabase = 'resetDatabase';
  static const String modifyDeadline = 'modifyDeadline';
  static const String startBattle = 'startBattle';
  static const String endGame = 'endGame';
  static const String sendReminder = 'sendReminder';
}

/// Alphabet for letter selection
class AppConstants {
  static const List<String> alphabet = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z'
  ];

  static const String appVersion = '1.0.0';
  static const String adminAppName = 'Vocabulary Battle Boss';
  static const String userAppName = 'Vocabulary Battle';
}
