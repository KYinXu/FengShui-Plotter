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
      // Show default state when no score is available
      return Container(
        width: 50, // Reduced from 60
        height: 180, // Reduced from 200
        padding: const EdgeInsets.all(6.0), // Reduced from 8.0
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title
            RotatedBox(
              quarterTurns: 3, // Rotate text 270 degrees
              child: Text(
                'Feng Shui',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            
            // Empty progress bar
            Expanded(
              child: RotatedBox(
                quarterTurns: 1, // Rotate 90 degrees to make it vertical
                child: LinearProgressIndicator(
                  value: 0.0,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  minHeight: 8,
                ),
              ),
            ),
            
            // Default text
            Text(
              '--',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            
            // Default rating
            Text(
              'No Layout',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.withOpacity(0.8),
              ),
            ),
            
            // Default percentage
            Text(
              '0%',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );
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
      width: 50, // Reduced from 60
      height: 180, // Reduced from 200
      padding: const EdgeInsets.all(6.0), // Reduced from 8.0
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title
          RotatedBox(
            quarterTurns: 3, // Rotate text 270 degrees
            child: Text(
              'Feng Shui',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
          
          // Vertical progress bar
          Expanded(
            child: RotatedBox(
              quarterTurns: 1, // Rotate 90 degrees to make it vertical
              child: LinearProgressIndicator(
                value: normalizedScore,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          
          // Score text
          Text(
            '${score!.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          
          // Rating
          Text(
            rating,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
          
          // Percentage
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
} 