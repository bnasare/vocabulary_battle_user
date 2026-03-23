import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../models/battle_commentary.dart';
import '../../models/game_session_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../services/sound_service.dart';
import '../../widgets/battle_commentary_card.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final GameSession session;

  const ResultsScreen({super.key, required this.session});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  final _soundService = SoundService();
  final _firestore = FirebaseFirestore.instance;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Play sound on screen load and trigger confetti for win
    Future.delayed(Duration(milliseconds: 300), () {
      final currentUserId = ref.read(currentUserIdProvider);
      final isPlayer1 = widget.session.player1Id == currentUserId;
      final myScore = isPlayer1
          ? widget.session.result?.player1FinalScore ?? 0
          : widget.session.result?.player2FinalScore ?? 0;
      final opponentScore = isPlayer1
          ? widget.session.result?.player2FinalScore ?? 0
          : widget.session.result?.player1FinalScore ?? 0;

      if (myScore > opponentScore) {
        _soundService.playWin();
        // Trigger confetti on win
        Future.delayed(Duration(milliseconds: 500), () {
          _confettiController.play();
        });
      } else if (myScore < opponentScore) {
        _soundService.playLose();
      } else {
        // Play tie sound effect
        _soundService.playTie();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  /// Fetch player answers from Firestore
  Future<List<PlayerAnswer>> _fetchPlayerAnswers(String playerId) async {
    final snapshot = await _firestore
        .collection('gameSessions')
        .doc(widget.session.id)
        .collection('playerAnswers')
        .where('playerId', isEqualTo: playerId)
        .get();

    return snapshot.docs.map((doc) => PlayerAnswer.fromFirestore(doc)).toList();
  }

  /// Generate battle commentary by fetching both players' answers
  Future<BattleCommentary?> _generateCommentary() async {
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId == null) return null;

      final isPlayer1 = widget.session.player1Id == currentUserId;

      final myId = currentUserId;
      final opponentId =
          isPlayer1 ? widget.session.player2Id : widget.session.player1Id;

      final myAnswers = await _fetchPlayerAnswers(myId);
      final opponentAnswers = await _fetchPlayerAnswers(opponentId);

      if (myAnswers.isEmpty || opponentAnswers.isEmpty) {
        return null;
      }

      return await BattleCommentary.analyze(
        myAnswers: myAnswers,
        opponentAnswers: opponentAnswers,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isPlayer1 = widget.session.player1Id == currentUserId;

    final myScore = isPlayer1
        ? widget.session.result?.player1FinalScore ?? 0
        : widget.session.result?.player2FinalScore ?? 0;
    final opponentScore = isPlayer1
        ? widget.session.result?.player2FinalScore ?? 0
        : widget.session.result?.player1FinalScore ?? 0;

    final won = myScore > opponentScore;
    final tied = myScore == opponentScore;
    final opponentId = isPlayer1
        ? widget.session.player2Id
        : widget.session.player1Id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Results'),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(
                'I scored $myScore/${GameConfig.totalQuestions} in Vocabulary Battle! 🎯',
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Winner announcement with animations
                Card(
                  color: won
                      ? AppColors.success
                      : tied
                          ? AppColors.warning
                          : AppColors.error,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          won
                              ? IconlyLight.star
                              : tied
                                  ? CupertinoIcons.hand_raised
                                  : IconlyLight.arrow_down,
                          size: 60,
                          color: Colors.white,
                        )
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.elasticOut)
                            .then()
                            .shake(duration: 400.ms)
                            .then()
                            .shimmer(
                              duration: 1200.ms,
                              color: Colors.white.withOpacity(0.5),
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .shimmer(
                              delay: 2000.ms,
                              duration: 1500.ms,
                              color: Colors.white.withOpacity(0.3),
                            ),
                        const SizedBox(height: 16),
                        Text(
                          won
                              ? 'You Won!'
                              : tied
                                  ? 'It\'s a Tie!'
                                  : 'You Lost',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(
                              begin: -0.3,
                              end: 0,
                              duration: 500.ms,
                              curve: Curves.easeOut,
                            ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 24),

                // Score comparison
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Final Scores',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildScoreCard(
                                'You',
                                myScore,
                                GameConfig.totalQuestions,
                                true,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FutureBuilder<UserModel?>(
                                future: ref.read(authServiceProvider).getUserModel(opponentId),
                                builder: (context, snapshot) {
                                  final opponentName = snapshot.data?.displayName ?? 'Opponent';
                                  return _buildScoreCard(
                                    opponentName,
                                    opponentScore,
                                    GameConfig.totalQuestions,
                                    false,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Battle Commentary
                FutureBuilder<BattleCommentary?>(
                  future: _generateCommentary(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data == null) {
                      return const SizedBox.shrink();
                    }

                    return BattleCommentaryCard(commentary: snapshot.data!);
                  },
                ),
                const SizedBox(height: 24),

                // Performance by letter
                const Text(
                  'Performance by Letter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Placeholder letter cards - real data would come from detailed answers
                _buildLetterPerformanceCard('A', 13, 15, 1),
                _buildLetterPerformanceCard('B', 11, 15, 2),
                _buildLetterPerformanceCard('C', 14, 15, 3),
                _buildLetterPerformanceCard('Random', 4, 5, 4),
              ],
            ),
          ),
          // Confetti widget overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.success,
                AppColors.accent,
                AppColors.primary,
                AppColors.warning,
                Colors.purple,
                Colors.pink,
              ],
              numberOfParticles: 30,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, int total, bool isMe) {
    final percentage = (score / total * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? AppColors.primary : Colors.grey,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isMe ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                '$value',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: isMe ? AppColors.primary : AppColors.textPrimary,
                ),
              );
            },
          ),
          Text(
            'out of $total',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isMe ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterPerformanceCard(
    String letter,
    int correct,
    int total,
    int letterOrder,
  ) {
    final percentage = (correct / total * 100).round();
    final stars = (percentage / 20).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: LetterColors.getColorForLetterOrder(letterOrder),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letter.length == 1 ? letter : letter[0],
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
                    letter,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: correct / total,
                          backgroundColor: Colors.grey[200],
                          color:
                              LetterColors.getColorForLetterOrder(letterOrder),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$correct/$total',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LetterColors.getColorForLetterOrder(letterOrder),
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      IconlyLight.star,
                      size: 16,
                      color: index < stars ? AppColors.accent : Colors.grey,
                    ),
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
