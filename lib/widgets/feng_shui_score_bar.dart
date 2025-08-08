import 'package:flutter/material.dart';
import '../services/feng_shui_scoring_service.dart';

class FengShuiScoreBar extends StatelessWidget {
  final double? score;
  final double maxScore;
  final String? message;
  final double? gridHeight; // New parameter to match grid height

  const FengShuiScoreBar({
    super.key,
    required this.score,
    this.maxScore = 400.0,
    this.message,
    this.gridHeight, // Add grid height parameter
  });

  @override
  Widget build(BuildContext context) {
    // Use grid height if provided, otherwise default to 180
    final barHeight = gridHeight ?? 180.0;
    
    if (score == null) {
      // Show default state when no score is available
      return Container(
        width: 52, // Reduced from 60 to 52 (8 pixels narrower)
        height: barHeight,
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Empty progress bar (bottom up)
            Expanded(
              child: Column(
                children: [
                  // Empty space at top
                  Expanded(
                    child: Container(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  // Empty progress at bottom
                  Container(
                    height: 0,
                    color: Colors.grey,
                  ),
                ],
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
            
            // Default percentage
            Text(
              '0%',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.withOpacity(0.8),
              ),
            ),
            
            // "out of 400" text
            Text(
              'out of 400',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.withOpacity(0.6),
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
      width: 52, // Reduced from 60 to 52 (8 pixels narrower)
      height: barHeight,
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Vertical progress bar (bottom up)
          Expanded(
            child: Column(
              children: [
                // Empty space at top
                Expanded(
                  flex: ((1.0 - normalizedScore) * 100).round(),
                  child: Container(
                    color: color.withOpacity(0.2),
                  ),
                ),
                // Filled progress at bottom
                Expanded(
                  flex: (normalizedScore * 100).round(),
                  child: Container(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          
          // Score text (handles four digits)
          Text(
            '${score!.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14, // Slightly smaller to fit four digits
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
          ),
          
          // Percentage
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
          
          // "out of 400" text
          Text(
            'out of 400',
            style: TextStyle(
              fontSize: 8,
              color: color.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
} 