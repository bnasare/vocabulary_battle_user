import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';

import '../../core/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/achievement_grid.dart';
import '../../widgets/stats_charts.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).appBarTheme.iconTheme?.color),
        ),
        title: const Text('Profile'),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Profile header - full width
                  Card(
                    margin: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
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
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Statistics
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                          children: [
                            _buildStatCard(
                              'Games Played',
                              '${user.stats.gamesPlayed}',
                              IconlyLight.game,
                              AppColors.primary,
                            ),
                            _buildStatCard(
                              'Wins',
                              '${user.stats.wins}',
                              IconlyLight.star,
                              AppColors.success,
                            ),
                            _buildStatCard(
                              'Win Rate',
                              user.stats.gamesPlayed > 0
                                  ? '${((user.stats.wins / user.stats.gamesPlayed) * 100).toStringAsFixed(0)}%'
                                  : '0%',
                              IconlyLight.arrow_up,
                              AppColors.accent,
                            ),
                            _buildStatCard(
                              'Accuracy',
                              '${user.stats.averageAccuracy.toStringAsFixed(0)}%',
                              CupertinoIcons.checkmark_circle,
                              AppColors.primary,
                            ),
                            _buildStatCard(
                              'Questions Answered',
                              '${user.stats.totalQuestionsAnswered}',
                              IconlyLight.document,
                              AppColors.textPrimary,
                            ),
                            _buildStatCard(
                              'Win Streak',
                              '${user.stats.winStreak}',
                              IconlyLight.activity,
                              AppColors.error,
                            ),
                          ],
                        ),

                        // Achievements
                        const Text(
                          'Achievements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AchievementGrid(
                          unlockedAchievements: user.achievements,
                          showAnimations: false,
                        ),

                        // Stats Charts
                        const Text(
                          'Performance Charts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StatsCharts(stats: user.stats),
                        const SizedBox(height: 32),

                        // Settings
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(IconlyLight.notification),
                                title: const Text('Notifications'),
                                trailing: Switch(
                                  value: true,
                                  onChanged: (value) {
                                    // TODO: Implement notification settings
                                  },
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(IconlyLight.logout,
                                    color: AppColors.error),
                                title: const Text(
                                  'Logout',
                                  style: TextStyle(color: AppColors.error),
                                ),
                                onTap: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Logout'),
                                      content: const Text(
                                          'Are you sure you want to logout?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Logout'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    try {
                                      // Clear cached images to prevent showing old user's photo
                                      PaintingBinding.instance.imageCache
                                          .clear();
                                      PaintingBinding.instance.imageCache
                                          .clearLiveImages();

                                      // Invalidate all providers to clear cached user data
                                      // This must happen BEFORE signOut to ensure clean state
                                      ref.invalidate(currentUserProvider);
                                      ref.invalidate(activeGameSessionProvider);
                                      ref.invalidate(gameHistoryProvider);
                                      ref.invalidate(authStateProvider);

                                      // Sign out from Firebase and Google
                                      // This will handle Firestore cache clearing
                                      final authService =
                                          ref.read(authServiceProvider);
                                      await authService.signOut();

                                      if (context.mounted) {
                                        Navigator.of(context)
                                            .popUntil((route) => route.isFirst);
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error logging out: $e'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
