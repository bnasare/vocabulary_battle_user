import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/game_session_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../widgets/player_progress_bar.dart';
import '../ai_battle/ai_practice_mode_screen.dart';
import '../battle/battle_screen.dart';
import '../profile/profile_screen.dart';
import '../questions/question_creation_screen.dart';
import '../results/results_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final activeGameSession = ref.watch(activeGameSessionProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vocabulary Battle'),
          actions: [
            IconButton(
              icon: const Icon(IconlyLight.profile),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activeGameSessionProvider);
            ref.invalidate(currentUserProvider);
            // Wait for the stream to reconnect and emit new data
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                currentUser.when(
                  data: (user) {
                    if (user == null) return const SizedBox.shrink();
                    return _buildWelcomeCard(user);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // Active Game or No Game
                activeGameSession.when(
                  data: (session) {
                    if (session == null) {
                      return _buildNoActiveGameCard();
                    }
                    return _buildActiveGameCard(context, ref, session);
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) {
                    // Handle permission errors gracefully
                    final errorMessage = error.toString();
                    final isPermissionError =
                        errorMessage.contains('permission-denied');

                    if (isPermissionError) {
                      // Permission error likely means no active game for this user
                      return _buildNoActiveGameCard();
                    }

                    // For other errors, show a retry button
                    return _buildErrorCard(
                      context,
                      ref,
                      errorMessage,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Practice vs AI Card
                _buildPracticeAICard(context),
                const SizedBox(height: 24),

                // Stats Summary
                currentUser.when(
                  data: (user) {
                    if (user == null) return const SizedBox.shrink();
                    return _buildStatsSummary(user.stats);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user.photoURL != null
                  ? CachedNetworkImageProvider(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? const Icon(IconlyLight.profile, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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

  Widget _buildNoActiveGameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                IconlyLight.time_circle,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Game',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wait for an admin to create a new game session',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGameCard(
      BuildContext context, WidgetRef ref, GameSession session) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isPlayer1 = session.player1Id == currentUserId;
    final myProgress =
        isPlayer1 ? session.player1Progress : session.player2Progress;
    final opponentProgress =
        isPlayer1 ? session.player2Progress : session.player1Progress;

    final now = DateTime.now();
    final isBeforeDeadline = now.isBefore(session.submissionDeadline);
    final canStartBattle = session.status == GameStatus.active;
    final isCompleted = session.status == GameStatus.completed;
    final hasCompletedBattle = myProgress.questionsAnswered >= session.totalQuestionsRequired;

    String actionButtonText;
    VoidCallback? actionButtonOnPressed;
    IconData actionButtonIcon;
    Color actionButtonColor = AppColors.primary;

    if (isCompleted) {
      actionButtonText = 'View Results';
      actionButtonIcon = IconlyLight.star;
      actionButtonColor = AppColors.success;
      actionButtonOnPressed = () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultsScreen(session: session),
          ),
        );
      };
    } else if (hasCompletedBattle) {
      // Player has already completed the battle
      actionButtonText = 'Battle Complete!';
      actionButtonIcon = CupertinoIcons.checkmark_circle;
      actionButtonColor = AppColors.success;
      actionButtonOnPressed = null; // Can't start again
    } else if (canStartBattle) {
      actionButtonText = 'Start Battle!';
      actionButtonIcon = CupertinoIcons.bolt;
      actionButtonColor = AppColors.accent;
      actionButtonOnPressed = () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BattleScreen(session: session),
          ),
        );
      };
    } else if (!myProgress.hasSubmitted && isBeforeDeadline) {
      actionButtonText = 'Create Your Questions';
      actionButtonIcon = IconlyLight.edit;
      actionButtonOnPressed = () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuestionCreationScreen(session: session),
          ),
        );
      };
    } else {
      actionButtonText = 'Waiting for Battle...';
      actionButtonIcon = IconlyLight.time_circle;
      actionButtonOnPressed = null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Battle',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                _buildStatusChip(session.status),
              ],
            ),
            const Divider(height: 32),

            // Countdown or info
            if (!isCompleted && session.status != GameStatus.active) ...[
              if (isBeforeDeadline)
                _buildCountdownCard(
                  'Submit Questions By',
                  session.submissionDeadline,
                  IconlyLight.time_circle,
                  AppColors.warning,
                )
              else
                _buildCountdownCard(
                  'Battle Starts',
                  session.battleDate,
                  IconlyLight.calendar,
                  AppColors.primary,
                ),
              const SizedBox(height: 16),
            ],

            // Progress indicators
            Row(
              children: [
                Expanded(
                  child: _buildProgressIndicator(
                    'You',
                    myProgress.hasSubmitted,
                    myProgress.questionsCreated,
                    session.totalQuestionsRequired,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProgressIndicator(
                    'Opponent',
                    opponentProgress.hasSubmitted,
                    opponentProgress.questionsCreated,
                    session.totalQuestionsRequired,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Progress Bars (during active battle)
            if (canStartBattle || session.status == GameStatus.active) ...[
              _buildLiveProgressBars(ref, session),
              const SizedBox(height: 16),
            ],

            // Online Presence Indicator
            _buildOnlinePresence(ref, session, isPlayer1),
            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: actionButtonOnPressed,
                icon: Icon(actionButtonIcon),
                label: Text(actionButtonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionButtonColor,
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case GameStatus.preparation:
        color = AppColors.warning;
        label = 'Preparation';
        break;
      case GameStatus.ready:
        color = AppColors.success;
        label = 'Ready';
        break;
      case GameStatus.active:
        color = AppColors.accent;
        label = 'Battle Live!';
        break;
      case GameStatus.completed:
        color = AppColors.textSecondary;
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == GameStatus.active)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                CupertinoIcons.flame,
                color: color,
                size: 14,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(
      String label, DateTime targetDate, IconData icon, Color color) {
    final difference = targetDate.difference(DateTime.now());
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(targetDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${days}d ${hours}h ${minutes}m',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'remaining',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
      String label, bool hasSubmitted, int questionsCount, int totalQuestions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasSubmitted
            ? AppColors.success.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasSubmitted
              ? AppColors.success.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            hasSubmitted
                ? CupertinoIcons.checkmark_circle
                : IconlyLight.edit_square,
            color: hasSubmitted ? AppColors.success : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            hasSubmitted ? '$questionsCount/$totalQuestions ✓' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasSubmitted ? AppColors.success : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    IconlyLight.game,
                    'Games',
                    '${stats.gamesPlayed}',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    IconlyLight.star,
                    'Wins',
                    '${stats.wins}',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    IconlyLight.chart,
                    'Accuracy',
                    '${stats.averageAccuracy.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveProgressBars(WidgetRef ref, GameSession session) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isPlayer1 = session.player1Id == currentUserId;
    final myProgress =
        isPlayer1 ? session.player1Progress : session.player2Progress;
    final opponentProgress =
        isPlayer1 ? session.player2Progress : session.player1Progress;
    final opponentId = isPlayer1 ? session.player2Id : session.player1Id;

    // Determine colors based on who's ahead
    Color myColor = AppColors.primary;
    Color opponentColor = AppColors.accent;

    if (myProgress.questionsAnswered > opponentProgress.questionsAnswered) {
      myColor = AppColors.success;
      opponentColor = AppColors.error;
    } else if (myProgress.questionsAnswered <
        opponentProgress.questionsAnswered) {
      myColor = AppColors.error;
      opponentColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Battle Progress',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          PlayerProgressBar(
            playerName: 'You',
            answered: myProgress.questionsAnswered,
            total: session.totalQuestionsRequired,
            color: myColor,
            isCurrentUser: true,
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(opponentId)
                .snapshots(),
            builder: (context, snapshot) {
              String opponentName = 'Opponent';
              if (snapshot.hasData && snapshot.data != null) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                opponentName = data?['displayName'] ?? 'Opponent';
              }
              return PlayerProgressBar(
                playerName: opponentName,
                answered: opponentProgress.questionsAnswered,
                total: session.totalQuestionsRequired,
                color: opponentColor,
                isCurrentUser: false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOnlinePresence(
      WidgetRef ref, GameSession session, bool isPlayer1) {
    final opponentId = isPlayer1 ? session.player2Id : session.player1Id;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(opponentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final isOnline = userData['isOnline'] ?? false;
        final lastSeenTimestamp = userData['lastSeen'] as Timestamp?;
        final displayName = userData['displayName'] ?? 'Opponent';

        String statusText;
        Color statusColor;

        if (isOnline) {
          statusText = 'Online';
          statusColor = AppColors.success;
        } else if (lastSeenTimestamp != null) {
          final lastSeen = lastSeenTimestamp.toDate();
          final difference = DateTime.now().difference(lastSeen);

          if (difference.inMinutes < 60) {
            statusText = 'Last seen ${difference.inMinutes}m ago';
          } else if (difference.inHours < 24) {
            statusText = 'Last seen ${difference.inHours}h ago';
          } else {
            statusText = 'Last seen ${difference.inDays}d ago';
          }
          statusColor = AppColors.textSecondary;
        } else {
          return const SizedBox.shrink();
        }

        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? statusColor : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$displayName - $statusText',
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorCard(BuildContext context, WidgetRef ref, String error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                IconlyLight.danger,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Game',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Something went wrong. Please try again.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(activeGameSessionProvider);
              },
              icon: const Icon(CupertinoIcons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeAICard(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AIPracticeModeScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accent.withOpacity(0.1), AppColors.primary.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  IconlyBold.star,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Practice vs AI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Challenge yourself with AI-generated questions',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                IconlyLight.arrow_right_3,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
