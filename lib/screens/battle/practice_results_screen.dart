import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

import '../../core/constants.dart';
import '../../models/game_mode.dart';
import '../../models/question_model.dart';

class PracticeResultsScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<String, PlayerAnswer> answers;
  final int score;
  final GameMode gameMode;

  const PracticeResultsScreen({
    super.key,
    required this.questions,
    required this.answers,
    required this.score,
    required this.gameMode,
  });

  @override
  Widget build(BuildContext context) {
    final accuracy = (score / questions.length) * 100;

    // Group questions by letter
    final questionsByLetter = <int, List<Question>>{};
    for (final question in questions) {
      questionsByLetter
          .putIfAbsent(question.letterOrder, () => [])
          .add(question);
    }

    // Calculate stats per letter
    final letterStats = <int, Map<String, int>>{};
    for (final entry in questionsByLetter.entries) {
      final letterOrder = entry.key;
      final letterQuestions = entry.value;
      final correct = letterQuestions
          .where((q) => answers[q.id]?.isCorrect ?? false)
          .length;
      letterStats[letterOrder] = {
        'correct': correct,
        'total': letterQuestions.length,
      };
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Results'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Close results and battle screen, return to practice mode screen
            Navigator.of(context).pop(); // Close results
            Navigator.of(context).pop(); // Close battle
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Score Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    IconlyBold.star,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Practice Complete!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$score/${questions.length}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${accuracy.toStringAsFixed(0)}% Accuracy',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${gameMode.displayName} Mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Performance by Letter
            const Text(
              'Performance by Letter',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...questionsByLetter.entries.map((entry) {
              final letterOrder = entry.key;
              final letterQuestions = entry.value;
              final stats = letterStats[letterOrder]!;
              final letter = letterQuestions.first.letter;
              final isRandom = letterQuestions.first.isRandom;

              return _buildLetterStatCard(
                letter: isRandom ? 'Random' : letter,
                correct: stats['correct']!,
                total: stats['total']!,
              );
            }),
            const SizedBox(height: 24),

            // Question Review
            const Text(
              'Question Review',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              final answer = answers[question.id];

              return _buildQuestionReviewCard(
                index: index + 1,
                question: question,
                answer: answer,
              );
            }),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close results
                      Navigator.of(context).pop(); // Close battle
                      // Stay on practice mode screen
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close results
                      Navigator.of(context).pop(); // Close battle
                      Navigator.of(context).pop(); // Close practice selection
                      // Return to home
                    },
                    icon: const Icon(IconlyLight.home),
                    label: const Text('Home'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterStatCard({
    required String letter,
    required int correct,
    required int total,
  }) {
    final percentage = (correct / total) * 100;
    final color = percentage >= 70
        ? AppColors.success
        : percentage >= 50
            ? AppColors.warning
            : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$correct out of $total correct',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: correct / total,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionReviewCard({
    required int index,
    required Question question,
    PlayerAnswer? answer,
  }) {
    final isCorrect = answer?.isCorrect ?? false;
    final userAnswer = answer?.playerAnswer ?? 'No answer';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppColors.success.withOpacity(0.2)
                        : AppColors.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.definition,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isCorrect) ...[
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Your answer: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              userAnswer,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        children: [
                          Icon(
                            isCorrect
                                ? CupertinoIcons.check_mark_circled_solid
                                : IconlyBold.info_circle,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Correct answer: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            question.answer,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
