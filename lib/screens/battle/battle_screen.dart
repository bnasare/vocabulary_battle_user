import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';

import '../../core/constants.dart';
import '../../models/game_mode.dart';
import '../../models/game_session_model.dart';
import '../../models/question_model.dart';
import '../../providers/providers.dart';
import '../../services/sound_service.dart';
import '../../utils/snackbar_helper.dart';
import 'multiplayer_results_screen.dart';
import 'practice_results_screen.dart';

class BattleScreen extends ConsumerStatefulWidget {
  final GameSession? session;
  final bool practiceMode;
  final List<Question>? practiceQuestions;
  final GameMode? practiceGameMode;

  const BattleScreen({
    super.key,
    this.session,
    this.practiceMode = false,
    this.practiceQuestions,
    this.practiceGameMode,
  }) : assert(
          (practiceMode && practiceQuestions != null && practiceGameMode != null) ||
              (!practiceMode && session != null),
          'Either provide session for normal mode or practiceQuestions+practiceGameMode for practice mode',
        );

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  final Map<String, PlayerAnswer> _answers = {};
  int _score = 0;
  bool _isLoading = true;
  bool _showingSectionTransition = false;
  Timer? _questionTimer;
  int _timeRemaining = GameConfig.questionTimeLimit;
  final _answerController = TextEditingController();
  DateTime? _questionStartTime;
  final _soundService = SoundService();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId == null) throw Exception('Not logged in');

      // Practice mode: use provided questions
      if (widget.practiceMode) {
        setState(() {
          _questions = widget.practiceQuestions!;
          _isLoading = false;
          _questionStartTime = DateTime.now();
        });
        _startQuestionTimer();
        return;
      }

      // Normal mode: load from Firestore
      // Check if player has already completed the battle
      final isPlayer1 = widget.session!.player1Id == currentUserId;
      final myProgress = isPlayer1
          ? widget.session!.player1Progress
          : widget.session!.player2Progress;

      if (myProgress.questionsAnswered >= widget.session!.totalQuestionsRequired) {
        if (mounted) {
          SnackBarHelper.showWarningSnackBar(
            context,
            'You have already completed this battle!',
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final firestoreService = ref.read(firestoreServiceProvider);

      // Load opponent's questions (already sorted)
      final questions = await firestoreService.getQuestionsForPlayer(
        sessionId: widget.session!.id,
        playerId: currentUserId,
      );

      setState(() {
        _questions = questions;
        _isLoading = false;
        _questionStartTime = DateTime.now();
      });

      _startQuestionTimer();
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(
          context,
          'Error loading questions: $e',
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _timeRemaining = GameConfig.questionTimeLimit;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          // Play warning sound when 10 seconds remaining
          if (_timeRemaining == 10) {
            _soundService.playTimerWarning();
          }
        } else {
          // Time's up, submit empty answer
          _soundService.playWrong();
          _submitAnswer('');
        }
      });
    });
  }

  Future<void> _submitAnswer(String playerAnswer) async {
    FocusScope.of(context).unfocus();
    _questionTimer?.cancel();

    final currentQuestion = _questions[_currentQuestionIndex];
    final isCorrect =
        PlayerAnswer.checkAnswer(playerAnswer, currentQuestion.answer);

    if (isCorrect) {
      setState(() => _score++);
      _soundService.playCorrect();
    } else {
      _soundService.playWrong();
    }

    final timeToAnswer =
        DateTime.now().difference(_questionStartTime!).inSeconds;

    final answer = PlayerAnswer(
      id: '',
      playerId: ref.read(currentUserIdProvider)!,
      questionId: currentQuestion.id,
      questionCreatorId: currentQuestion.creatorId,
      playerAnswer: playerAnswer,
      correctAnswer: currentQuestion.answer,
      isCorrect: isCorrect,
      answeredAt: DateTime.now(),
      timeToAnswer: timeToAnswer,
    );

    _answers[currentQuestion.id] = answer;

    // Save to Firestore (skip in practice mode)
    if (!widget.practiceMode) {
      ref.read(firestoreServiceProvider).submitAnswer(
            sessionId: widget.session!.id,
            answer: answer,
          );
    }

    // Show answer feedback in practice mode
    if (widget.practiceMode) {
      await _showAnswerFeedback(currentQuestion, playerAnswer, isCorrect);
    }

    // Check if moving to new letter section
    if (_currentQuestionIndex + 1 < _questions.length) {
      final nextQuestion = _questions[_currentQuestionIndex + 1];
      if (nextQuestion.letterOrder != currentQuestion.letterOrder) {
        _showSectionTransition(currentQuestion.letterOrder);
        return;
      }
    }

    _moveToNextQuestion();
  }

  void _showSectionTransition(int completedLetterOrder) {
    setState(() => _showingSectionTransition = true);

    final completedQuestions =
        _questions.where((q) => q.letterOrder == completedLetterOrder).toList();
    final correct = completedQuestions
        .where((q) => _answers[q.id]?.isCorrect ?? false)
        .length;

    // Show transition for 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showingSectionTransition = false);
        _moveToNextQuestion();
      }
    });
  }

  void _moveToNextQuestion() {
    _answerController.clear();

    if (_currentQuestionIndex + 1 >= _questions.length) {
      _finishBattle();
      return;
    }

    setState(() {
      _currentQuestionIndex++;
      _questionStartTime = DateTime.now();
    });

    _startQuestionTimer();
  }

  Future<void> _showAnswerFeedback(
    Question question,
    String playerAnswer,
    bool isCorrect,
  ) async {
    await showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCorrect ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.xmark_circle_fill,
              color: isCorrect ? AppColors.success : AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(isCorrect ? 'Correct!' : 'Incorrect'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              question.definition,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (!isCorrect) ...[
              const Text(
                'Your answer:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                playerAnswer,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Correct answer:',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              question.answer,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishBattle() async {
    _questionTimer?.cancel();
    _soundService.playBattleComplete();

    // Practice mode: just show results, no Firestore updates
    if (widget.practiceMode) {
      _showPracticeResults();
      return;
    }

    // Normal mode: Update questionsAnswered count in Firestore
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId != null) {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.updatePlayerProgress(
          sessionId: widget.session!.id,
          playerId: currentUserId,
          progressData: {
            'questionsAnswered': _questions.length,
            'correctAnswers': _score,
          },
        );

        // Check if both players are done and trigger calculateResults
        await firestoreService.checkAndCompleteGame(widget.session!.id);
      }
    } catch (e) {
      // Error updating progress
    }

    // Navigate to multiplayer results screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MultiplayerResultsScreen(
            session: widget.session!,
            questions: _questions,
            answers: _answers,
            score: _score,
          ),
        ),
      );
    }
  }

  void _showPracticeResults() {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PracticeResultsScreen(
          questions: _questions,
          answers: _answers,
          score: _score,
          gameMode: widget.practiceGameMode!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Battle...'),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_showingSectionTransition) {
      return _buildSectionTransition();
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await _showQuitConfirmation();
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  LetterColors.getColorForLetterOrder(
                      currentQuestion.letterOrder),
                  LetterColors.getColorForLetterOrder(
                          currentQuestion.letterOrder)
                      .withOpacity(0.6),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header
                    _buildHeader(currentQuestion),
                    const SizedBox(height: 24),

                    // Question Card
                    Expanded(
                      child: _buildQuestionCard(currentQuestion),
                    ),
                    const SizedBox(height: 24),

                    // Answer Input
                    _buildAnswerInput(currentQuestion),
                    const SizedBox(height: 16),

                    // Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showQuitConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Battle?'),
        content: const Text(
          'Are you sure you want to quit? Your progress will be lost and you may forfeit this battle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              _questionTimer?.cancel();
              Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Question question) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${question.questionNumberInLetter} of ${question.isRandom ? 5 : 15}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Overall: ${_currentQuestionIndex + 1}/${_questions.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[200],
              color: LetterColors.getColorForLetterOrder(question.letterOrder),
            ),
            const SizedBox(height: 12),

            // Score and Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(IconlyLight.star,
                        color: AppColors.accent, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'Score: $_score/$_currentQuestionIndex',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Circular progress indicator
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: _timeRemaining / GameConfig.questionTimeLimit,
                          strokeWidth: 5,
                          backgroundColor: Colors.grey[300],
                          color: _timeRemaining <= 10
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                      // Timer text in center
                      Text(
                        '$_timeRemaining',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _timeRemaining <= 10
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(
                      target: _timeRemaining <= 10 ? 1 : 0,
                    )
                    .shake(
                      duration: 100.ms,
                      hz: 4,
                      curve: Curves.easeInOut,
                    )
                    .then(delay: 900.ms)
                    .callback(callback: (_) {
                      // This creates a repeating shake effect every second when <= 10
                      if (_timeRemaining <= 10 && mounted) {
                        setState(() {});
                      }
                    })
                    .animate(
                      target: _timeRemaining <= 10 ? 1 : 0,
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.08, 1.08),
                      duration: 500.ms,
                      curve: Curves.easeInOut,
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    final letterLabel = question.isRandom ? 'RANDOM' : question.letter;

    return Card(
      color: Colors.white,
      elevation: 8,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.lightbulb,
                      size: 48,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      question.definition,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Letter badge in top right corner
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    LetterColors.getColorForLetterOrder(question.letterOrder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                letterLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(Question question) {
    final labelText = question.isRandom
        ? 'Answer starts with any letter'
        : 'Answer starts with letter ${question.letter}';

    return TextField(
      controller: _answerController,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: labelText,
        hintText: 'Type your answer here...',
        prefixIcon: const Icon(CupertinoIcons.keyboard),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 18),
      onSubmitted: (_) => _submitAnswer(_answerController.text.trim()),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _submitAnswer(_answerController.text.trim()),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: LetterColors.getColorForLetterOrder(
            _questions[_currentQuestionIndex].letterOrder,
          ),
        ),
        child: const Text(
          'Submit Answer',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTransition() {
    final completedLetterOrder = _questions[_currentQuestionIndex].letterOrder;
    final completedLetter = _questions[_currentQuestionIndex].letter;
    final completedQuestions =
        _questions.where((q) => q.letterOrder == completedLetterOrder).toList();
    final correct = completedQuestions
        .where((q) => _answers[q.id]?.isCorrect ?? false)
        .length;

    final nextQuestion = _currentQuestionIndex + 1 < _questions.length
        ? _questions[_currentQuestionIndex + 1]
        : null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LetterColors.getColorForLetterOrder(completedLetterOrder),
              LetterColors.getColorForLetterOrder(completedLetterOrder)
                  .withOpacity(0.6),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.checkmark_circle,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  completedLetter == 'RANDOM'
                      ? 'Random Section Complete!'
                      : 'Letter $completedLetter Complete!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'You got $correct out of ${completedQuestions.length} correct!',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),
                if (nextQuestion != null) ...[
                  const Text(
                    'Get ready for...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      nextQuestion.isRandom
                          ? 'Random Letters'
                          : 'Letter ${nextQuestion.letter}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: LetterColors.getColorForLetterOrder(
                            nextQuestion.letterOrder),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
