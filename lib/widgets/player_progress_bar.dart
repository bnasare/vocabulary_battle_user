import 'package:flutter/material.dart';

class PlayerProgressBar extends StatelessWidget {
  final String playerName;
  final int answered;
  final int total;
  final Color color;
  final bool isCurrentUser;

  const PlayerProgressBar({
    super.key,
    required this.playerName,
    required this.answered,
    required this.total,
    required this.color,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? answered / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isCurrentUser ? 'You' : playerName,
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            Text(
              '$answered/$total',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
