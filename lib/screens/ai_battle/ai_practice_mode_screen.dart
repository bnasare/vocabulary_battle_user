import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';

import '../../core/constants.dart';
import '../../models/game_mode.dart';
import '../../models/question_model.dart';
import '../../providers/providers.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/loading/async_loader.dart';
import '../battle/battle_screen.dart';

class AIPracticeModeScreen extends ConsumerStatefulWidget {
  const AIPracticeModeScreen({super.key});

  @override
  ConsumerState<AIPracticeModeScreen> createState() =>
      _AIPracticeModeScreenState();
}

class _AIPracticeModeScreenState extends ConsumerState<AIPracticeModeScreen> {
  GameMode _selectedMode = GameMode.normal;

  Future<void> _startPractice() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      SnackBarHelper.showErrorSnackBar(context, 'Please sign in to continue');
      return;
    }

    // Randomly select 3 letters for practice mode
    final random = Random();
    final availableLetters = List<String>.from(AppConstants.alphabet);
    final selectedLetters = <String>[];
    for (int i = 0; i < 3; i++) {
      final index = random.nextInt(availableLetters.length);
      selectedLetters.add(availableLetters.removeAt(index));
    }

    final result = await AsyncLoader.execute<List<Question>>(
      context: context,
      message: 'AI is preparing your challenge with letters ${selectedLetters.join(', ')}...',
      asyncTask: () async {
        final aiService = ref.read(aiQuestionServiceProvider);
        final response = await aiService.generateQuestions(
          selectedLetters: selectedLetters,
          gameMode: _selectedMode,
          creatorId: 'AI', // Mark as AI-generated
        );
        return response['questions'] as List<Question>;
      },
      timeout: const Duration(seconds: 30),
    );

    result.fold(
      (error) {
        if (mounted) {
          SnackBarHelper.showErrorSnackBar(
            context,
            'Failed to generate practice questions: $error',
          );
        }
      },
      (questions) {
        if (mounted) {
          // Navigate to battle screen with practice mode
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BattleScreen(
                practiceMode: true,
                practiceQuestions: questions,
                practiceGameMode: _selectedMode,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice vs AI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      IconlyBold.star,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Practice Mode',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Challenge yourself with AI-generated vocabulary questions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Mode selection
            const Text(
              'Select Challenge Level',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            _buildModeCard(GameMode.quick),
            const SizedBox(height: 12),
            _buildModeCard(GameMode.normal),
            const SizedBox(height: 12),
            _buildModeCard(GameMode.challenge),
            const SizedBox(height: 32),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startPractice,
                icon: const Icon(IconlyBold.star),
                label: Text('Start ${_selectedMode.displayName} Practice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(IconlyLight.info_circle, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Practice Mode Features:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Solo practice - no opponent needed\n'
                          '• AI generates unique questions each time\n'
                          '• Your stats are saved for tracking progress\n'
                          '• Perfect for improving your vocabulary',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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

  Widget _buildModeCard(GameMode mode) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<GameMode>(
              value: mode,
              groupValue: _selectedMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMode = value);
                }
              },
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mode.totalQuestions} questions • ~${mode.estimatedMinutes} min',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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
}
