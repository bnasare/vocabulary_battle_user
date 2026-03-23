import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../models/battle_commentary.dart';
import '../core/constants.dart';

class BattleCommentaryCard extends StatelessWidget {
  final BattleCommentary commentary;

  const BattleCommentaryCard({
    super.key,
    required this.commentary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(IconlyLight.chart, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Battle Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Both missed
            if (commentary.bothMissedWords.isNotEmpty) ...[
              _buildSection(
                title: '📝 Challenging Words',
                subtitle: 'Both players struggled with these:',
                content: commentary.bothMissedWords.take(5).join(', '),
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
            ],

            // Perfect letters
            if (commentary.perfectLetters.isNotEmpty) ...[
              _buildSection(
                title: '⭐ Perfect Score',
                subtitle: 'You mastered these letters:',
                content: commentary.perfectLetters.join(', '),
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
            ],

            // Strongest letters comparison
            if (commentary.myStrongestLetter != null ||
                commentary.opponentStrongestLetter != null) ...[
              _buildSection(
                title: '💪 Strongest Letters',
                subtitle: '',
                content: '',
                color: AppColors.primary,
                customContent: Column(
                  children: [
                    if (commentary.myStrongestLetter != null)
                      _buildStrengthRow(
                        'You',
                        commentary.myStrongestLetter!,
                        commentary.myStrongestAccuracy,
                        AppColors.success,
                      ),
                    const SizedBox(height: 8),
                    if (commentary.opponentStrongestLetter != null)
                      _buildStrengthRow(
                        'Opponent',
                        commentary.opponentStrongestLetter!,
                        commentary.opponentStrongestAccuracy,
                        AppColors.accent,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Letter-by-letter breakdown
            if (commentary.letterComparisons.isNotEmpty) ...[
              const Text(
                'Letter Performance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ...commentary.letterComparisons.entries.map((entry) {
                final comparison = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildLetterComparison(comparison),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required String content,
    required Color color,
    Widget? customContent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (customContent != null) ...[
            const SizedBox(height: 8),
            customContent,
          ],
        ],
      ),
    );
  }

  Widget _buildStrengthRow(
      String label, String letter, double accuracy, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${accuracy.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLetterComparison(LetterComparison comparison) {
    final Color winnerColor = comparison.winner == 'you'
        ? AppColors.success
        : comparison.winner == 'opponent'
            ? AppColors.error
            : AppColors.warning;

    return Row(
      children: [
        // Letter badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: winnerColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              comparison.letter,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: winnerColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Progress bars
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text('You:', style: TextStyle(fontSize: 11)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: comparison.myAccuracy / 100,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.success),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${comparison.myCorrect}/${comparison.myTotal}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text('Opp:', style: TextStyle(fontSize: 11)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: comparison.opponentAccuracy / 100,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${comparison.opponentCorrect}/${comparison.opponentTotal}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
