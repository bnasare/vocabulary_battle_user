import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

class StatsCharts extends StatelessWidget {
  final UserStats stats;
  final int? calculatedWins;
  final int? calculatedLosses;
  final int? calculatedTies;

  const StatsCharts({
    super.key,
    required this.stats,
    this.calculatedWins,
    this.calculatedLosses,
    this.calculatedTies,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Win/Loss Pie Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Win/Tie/Loss Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: _buildWinLossPieChart(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Letter Accuracy Bar Chart
        if (stats.letterAccuracy.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Letter Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: _buildLetterAccuracyBarChart(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWinLossPieChart() {
    // Use calculated values if provided, otherwise fall back to stats
    final wins = calculatedWins ?? stats.wins;
    final losses = calculatedLosses ?? stats.losses;
    final ties = calculatedTies ?? stats.ties;
    final totalGames = wins + losses + ties;

    if (totalGames == 0) {
      return const Center(
        child: Text(
          'No games played yet',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final sections = <PieChartSectionData>[];

    // Add wins section
    if (wins > 0) {
      sections.add(
        PieChartSectionData(
          value: wins.toDouble(),
          title: '$wins\nWins',
          color: AppColors.success,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Add ties section
    if (ties > 0) {
      sections.add(
        PieChartSectionData(
          value: ties.toDouble(),
          title: '$ties\nTies',
          color: Colors.orange,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Add losses section
    if (losses > 0) {
      sections.add(
        PieChartSectionData(
          value: losses.toDouble(),
          title: '$losses\nLosses',
          color: AppColors.error,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        sections: sections,
      ),
    );
  }

  Widget _buildLetterAccuracyBarChart() {
    if (stats.letterAccuracy.isEmpty) {
      return const Center(
        child: Text(
          'No letter data available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final entries = stats.letterAccuracy.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= entries.length) {
                  return const Text('');
                }
                return Text(
                  entries[value.toInt()].key,
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) {
          final index = entry.key;
          final accuracy = entry.value.value;

          Color barColor = AppColors.primary;
          if (accuracy >= 90) {
            barColor = AppColors.success;
          } else if (accuracy >= 70) {
            barColor = AppColors.accent;
          } else if (accuracy < 50) {
            barColor = AppColors.error;
          }

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: accuracy,
                color: barColor,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccuracyGauge() {
    final accuracy = stats.averageAccuracy;

    Color gaugeColor = AppColors.primary;
    if (accuracy >= 90) {
      gaugeColor = AppColors.success;
    } else if (accuracy >= 70) {
      gaugeColor = AppColors.accent;
    } else if (accuracy < 50) {
      gaugeColor = AppColors.error;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CircularProgressIndicator(
            value: accuracy / 100,
            strokeWidth: 15,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${accuracy.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: gaugeColor,
              ),
            ),
            Text(
              '${stats.correctAnswers}/${stats.totalQuestionsAnswered}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
