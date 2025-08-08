import 'dart:convert';
import 'package:http/http.dart' as http;

class AutoPlacerService {
  static const String _baseUrl = 'http://localhost:5000';

  /// Sends grid data to the Python server and returns the full response.
  static Future<Map<String, dynamic>> getPlacements(Map<String, dynamic> gridData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/random-auto-placer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(gridData),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception('Failed to get placements from Python server');
    }
  }
} 