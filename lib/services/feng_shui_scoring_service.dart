import 'dart:convert';
import 'package:http/http.dart' as http;

class FengShuiScoringService {
  static const String baseUrl = 'http://localhost:5000';

  static Future<bool> testServerConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('Server test successful: ${result['message']}');
        return true;
      } else {
        print('Server test failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Server test error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> calculateLiveScore({
    required List<Map<String, dynamic>> placements,
    required int gridWidth,
    required int gridHeight,
  }) async {
    try {
      final requestData = {
        'placements': placements,
        'grid_width': gridWidth,
        'grid_height': gridHeight,
      };

      print('=== SENDING SCORE REQUEST ===');
      print('Placements: $placements');
      print('Grid size: ${gridWidth}x${gridHeight}');
      print('URL: $baseUrl/calculate-live-score');

      final response = await http.post(
        Uri.parse('$baseUrl/calculate-live-score'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('Parsed result: $result');
        return result;
      } else {
        print('HTTP Error: ${response.statusCode}');
        throw Exception('Failed to calculate score: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calculating Feng Shui score: $e');
      print('This might mean the Python server is not running.');
      print('Please start the server with: cd scripts && python run_server.py');
      
      // Return a default score structure if the service is unavailable
      return {
        'score': 0.0,
        'breakdown': {
          'bagua_scores': 0.0,
          'command_position': 0.0,
          'chi_flow': 0.0,
          'layout_bonus': 0.0,
          'wall_bonuses': 0.0,
          'feng_shui_penalties': 0.0,
          'door_blocked': 0.0,
          'furniture_overlap': 0.0,
        },
        'message': 'Score calculation unavailable - Server not running',
        'recommendations': ['Start the Python server: cd scripts && python run_server.py'],
      };
    }
  }

  static String getScoreMessage(double score) {
    if (score >= 80) {
      return 'Excellent Feng Shui! 🎉';
    } else if (score >= 60) {
      return 'Good Feng Shui! 👍';
    } else if (score >= 40) {
      return 'Fair Feng Shui ⚖️';
    } else if (score >= 20) {
      return 'Poor Feng Shui ⚠️';
    } else {
      return 'Very Poor Feng Shui ❌';
    }
  }

  static String getScoreColor(double score) {
    if (score >= 80) return '#4CAF50'; // Green
    if (score >= 60) return '#8BC34A'; // Light Green
    if (score >= 40) return '#FFC107'; // Yellow
    if (score >= 20) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }
} 