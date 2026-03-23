import 'package:flutter/material.dart';
import 'achievement_badge.dart';

class AchievementGrid extends StatelessWidget {
  final List<String> unlockedAchievements;
  final bool showAnimations;

  const AchievementGrid({
    super.key,
    required this.unlockedAchievements,
    this.showAnimations = false,
  });

  @override
  Widget build(BuildContext context) {
    final allAchievements = AchievementBadge.getAllAchievementIds();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: allAchievements.length,
      itemBuilder: (context, index) {
        final achievementId = allAchievements[index];
        final isUnlocked = unlockedAchievements.contains(achievementId);

        return AchievementBadge(
          achievementId: achievementId,
          isUnlocked: isUnlocked,
          showAnimation: showAnimations && isUnlocked,
        );
      },
    );
  }
}
