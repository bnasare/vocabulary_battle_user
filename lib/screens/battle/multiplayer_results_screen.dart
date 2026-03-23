import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';

import '../../core/constants.dart';
import '../../models/game_session_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../results/results_screen.dart';

class MultiplayerResultsScreen extends ConsumerWidget {
  final GameSession session;
  final List<Question> questions;
  final Map<String, PlayerAnswer> answers;
  final int score;

  const MultiplayerResultsScreen({
    super.key,
    required this.session,
    required this.questions,
    required this.answers,
    required this.score,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(currentUserIdProvider);
    final sessionStream = ref.watch(firestoreServiceProvider).watchGameSession(session.id);

    return StreamBuilder<GameSession>(
      stream: sessionStream,
      initialData: session,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentSession = snapshot.data!;
        final isCompleted = currentSession.status == GameStatus.completed;
        final isPlayer1 = currentSession.player1Id == currentUserId;

        if (isCompleted) {
          // Show skeleton while result data is loading
          if (currentSession.result == null) {
            return _buildCompletedSkeleton(context);
          }
          return _buildCompletedState(context, ref, currentSession, isPlayer1);
        } else {
          return _buildWaitingState(context, isPlayer1);
        }
      },
    );
  }

  Widget _buildWaitingState(BuildContext context, bool isPlayer1) {
    final accuracy = (score / questions.length) * 100;

    // Group questions by letter for performance stats
    final questionsByLetter = <int, List<Question>>{};
    for (final question in questions) {
      questionsByLetter.putIfAbsent(question.letterOrder, () => []).add(question);
    }

    // Calculate stats per letter
    final letterStats = <int, Map<String, int>>{};
    for (final entry in questionsByLetter.entries) {
      final letterOrder = entry.key;
      final letterQuestions = entry.value;
      final correct = letterQuestions.where((q) => answers[q.id]?.isCorrect ?? false).length;
      letterStats[letterOrder] = {
        'correct': correct,
        'total': letterQuestions.length,
      };
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Results'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(IconlyLight.home, color: Colors.white),
            label: const Text(
              'Go Home',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Waiting Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.8), AppColors.accent.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Waiting for opponent to finish...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Score: $score/${questions.length}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${accuracy.toStringAsFixed(0)}% Accuracy',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Your Performance by Letter
            const Text(
              'Your Performance by Letter',
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
            }).toList(),
            const SizedBox(height: 24),

            // Question Review
            const Text(
              'Your Question Review',
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
            }).toList(),
            const SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(IconlyLight.info_circle, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The results will automatically update when your opponent finishes the battle.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSkeleton(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Results'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skeleton result header
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 24),
            // Skeleton title
            Container(
              width: 200,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            // Skeleton letter cards
            for (int i = 0; i < 3; i++) ...[
              Container(
                width: double.infinity,
                height: 80,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ],
        ),
      ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms, color: Colors.grey.shade100),
    );
  }

  Widget _buildCompletedState(
    BuildContext context,
    WidgetRef ref,
    GameSession currentSession,
    bool isPlayer1,
  ) {
    final currentUserId = ref.read(currentUserIdProvider);
    final winnerId = currentSession.result?.winnerId;
    final iWon = winnerId == currentUserId;
    final isTie = winnerId == null;

    final myScore = isPlayer1
        ? currentSession.result?.player1FinalScore ?? score
        : currentSession.result?.player2FinalScore ?? score;
    final opponentScore = isPlayer1
        ? currentSession.result?.player2FinalScore ?? 0
        : currentSession.result?.player1FinalScore ?? 0;

    final accuracy = (myScore / questions.length) * 100;
    final opponentId = isPlayer1
        ? currentSession.player2Id
        : currentSession.player1Id;

    // Group questions by letter
    final questionsByLetter = <int, List<Question>>{};
    for (final question in questions) {
      questionsByLetter.putIfAbsent(question.letterOrder, () => []).add(question);
    }

    // Calculate stats per letter
    final letterStats = <int, Map<String, int>>{};
    for (final entry in questionsByLetter.entries) {
      final letterOrder = entry.key;
      final letterQuestions = entry.value;
      final correct = letterQuestions.where((q) => answers[q.id]?.isCorrect ?? false).length;
      letterStats[letterOrder] = {
        'correct': correct,
        'total': letterQuestions.length,
      };
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Results'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(IconlyLight.home, color: Colors.white),
            label: const Text(
              'Go Home',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isTie
                      ? [AppColors.warning.withOpacity(0.8), AppColors.warning]
                      : iWon
                          ? [AppColors.success.withOpacity(0.8), AppColors.success]
                          : [AppColors.error.withOpacity(0.8), AppColors.error],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    isTie
                        ? CupertinoIcons.equal_circle_fill
                        : iWon
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.xmark_seal_fill,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTie ? 'It\'s a Tie!' : iWon ? 'You Won!' : 'You Lost',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$myScore',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      const Text(
                        'vs',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 40),
                      Column(
                        children: [
                          FutureBuilder<UserModel?>(
                            future: ref.read(authServiceProvider).getUserModel(opponentId),
                            builder: (context, snapshot) {
                              final opponentName = snapshot.data?.displayName ?? 'Opponent';
                              return Text(
                                opponentName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$opponentScore',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Accuracy: ${accuracy.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Your Performance by Letter
            const Text(
              'Your Performance by Letter',
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
            }).toList(),
            const SizedBox(height: 24),

            // Question Review
            const Text(
              'Your Question Review',
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
            }).toList(),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => ResultsScreen(session: currentSession),
                        ),
                      );
                    },
                    icon: const Icon(IconlyLight.chart),
                    label: const Text('Full Battle Results'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Close this screen and battle screen, return to home
                      Navigator.of(context).popUntil((route) => route.isFirst);
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
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
                            Expanded(
                              child: Text(
                                userAnswer,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
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
