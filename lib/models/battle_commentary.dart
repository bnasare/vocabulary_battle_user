import 'question_model.dart';

class BattleCommentary {
  final List<String> bothMissedWords;
  final String? myStrongestLetter;
  final String? opponentStrongestLetter;
  final double myStrongestAccuracy;
  final double opponentStrongestAccuracy;
  final Map<String, LetterComparison> letterComparisons;
  final List<String> perfectLetters;

  BattleCommentary({
    required this.bothMissedWords,
    this.myStrongestLetter,
    this.opponentStrongestLetter,
    required this.myStrongestAccuracy,
    required this.opponentStrongestAccuracy,
    required this.letterComparisons,
    required this.perfectLetters,
  });

  /// Analyze answers to generate commentary
  static Future<BattleCommentary> analyze({
    required List<PlayerAnswer> myAnswers,
    required List<PlayerAnswer> opponentAnswers,
  }) async {
    // Find words both players missed
    final bothMissed = <String>[];
    for (final myAnswer in myAnswers) {
      if (!myAnswer.isCorrect) {
        final opponentAnswer = opponentAnswers.firstWhere(
          (a) => a.questionId == myAnswer.questionId,
          orElse: () => myAnswer,
        );
        if (!opponentAnswer.isCorrect) {
          bothMissed.add(myAnswer.correctAnswer);
        }
      }
    }

    // Calculate per-letter accuracy
    final Map<String, int> myCorrectByLetter = {};
    final Map<String, int> myTotalByLetter = {};
    final Map<String, int> oppCorrectByLetter = {};
    final Map<String, int> oppTotalByLetter = {};

    for (final answer in myAnswers) {
      final letter = answer.correctAnswer[0].toUpperCase();
      myTotalByLetter[letter] = (myTotalByLetter[letter] ?? 0) + 1;
      if (answer.isCorrect) {
        myCorrectByLetter[letter] = (myCorrectByLetter[letter] ?? 0) + 1;
      }
    }

    for (final answer in opponentAnswers) {
      final letter = answer.correctAnswer[0].toUpperCase();
      oppTotalByLetter[letter] = (oppTotalByLetter[letter] ?? 0) + 1;
      if (answer.isCorrect) {
        oppCorrectByLetter[letter] = (oppCorrectByLetter[letter] ?? 0) + 1;
      }
    }

    // Find strongest letters
    String? myStrongestLetter;
    double myStrongestAccuracy = 0.0;

    myTotalByLetter.forEach((letter, total) {
      final correct = myCorrectByLetter[letter] ?? 0;
      final accuracy = (correct / total) * 100;
      if (accuracy > myStrongestAccuracy) {
        myStrongestAccuracy = accuracy;
        myStrongestLetter = letter;
      }
    });

    String? opponentStrongestLetter;
    double opponentStrongestAccuracy = 0.0;

    oppTotalByLetter.forEach((letter, total) {
      final correct = oppCorrectByLetter[letter] ?? 0;
      final accuracy = (correct / total) * 100;
      if (accuracy > opponentStrongestAccuracy) {
        opponentStrongestAccuracy = accuracy;
        opponentStrongestLetter = letter;
      }
    });

    // Letter-by-letter comparisons
    final Map<String, LetterComparison> letterComparisons = {};
    final allLetters = {...myTotalByLetter.keys, ...oppTotalByLetter.keys};

    for (final letter in allLetters) {
      final myTotal = myTotalByLetter[letter] ?? 0;
      final myCorrect = myCorrectByLetter[letter] ?? 0;
      final oppTotal = oppTotalByLetter[letter] ?? 0;
      final oppCorrect = oppCorrectByLetter[letter] ?? 0;

      final myAccuracy = myTotal > 0 ? (myCorrect / myTotal) * 100 : 0.0;
      final oppAccuracy = oppTotal > 0 ? (oppCorrect / oppTotal) * 100 : 0.0;

      letterComparisons[letter] = LetterComparison(
        letter: letter,
        myAccuracy: myAccuracy,
        opponentAccuracy: oppAccuracy,
        myCorrect: myCorrect,
        myTotal: myTotal,
        opponentCorrect: oppCorrect,
        opponentTotal: oppTotal,
      );
    }

    // Find perfect letters (100% accuracy)
    final perfectLetters = <String>[];
    myTotalByLetter.forEach((letter, total) {
      final correct = myCorrectByLetter[letter] ?? 0;
      if (correct == total && total > 0) {
        perfectLetters.add(letter);
      }
    });

    return BattleCommentary(
      bothMissedWords: bothMissed,
      myStrongestLetter: myStrongestLetter,
      opponentStrongestLetter: opponentStrongestLetter,
      myStrongestAccuracy: myStrongestAccuracy,
      opponentStrongestAccuracy: opponentStrongestAccuracy,
      letterComparisons: letterComparisons,
      perfectLetters: perfectLetters,
    );
  }
}

class LetterComparison {
  final String letter;
  final double myAccuracy;
  final double opponentAccuracy;
  final int myCorrect;
  final int myTotal;
  final int opponentCorrect;
  final int opponentTotal;

  LetterComparison({
    required this.letter,
    required this.myAccuracy,
    required this.opponentAccuracy,
    required this.myCorrect,
    required this.myTotal,
    required this.opponentCorrect,
    required this.opponentTotal,
  });

  String get winner {
    if (myAccuracy > opponentAccuracy) return 'you';
    if (opponentAccuracy > myAccuracy) return 'opponent';
    return 'tie';
  }
}
