import 'package:flutter/material.dart';

class FengShuiScoreBar extends StatelessWidget {
  final double? score;
  final double maxScore;

  const FengShuiScoreBar({
    super.key,
    required this.score,
    this.maxScore = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return const SizedBox.shrink();
    }

    final normalizedScore = (score! / maxScore).clamp(0.0, 1.0);
    final percentage = (normalizedScore * 100).round();

    // Determine rating and color
    String rating;
    Color color;
    Color backgroundColor;
    
    if (normalizedScore < 0.4) {
      rating = 'Poor';
      color = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.2);
    } else if (normalizedScore < 0.7) {
      rating = 'Fair';
      color = Colors.orange;
      backgroundColor = Colors.orange.withOpacity(0.2);
    } else {
      rating = 'Good';
      color = Colors.green;
      backgroundColor = Colors.green.withOpacity(0.2);
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Feng Shui Score',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              Text(
                '$rating ($percentage%)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: normalizedScore,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Text(
            '${score!.toStringAsFixed(1)} / $maxScore',
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
} 