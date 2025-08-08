import 'dart:convert';
import 'package:http/http.dart' as http;

class AutoPlacerService {
  static const String baseUrl = 'http://localhost:5000';

  static Future<Map<String, dynamic>> getPlacements(Map<String, dynamic> gridData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/random-auto-placer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(gridData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get placements: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to auto placer service: $e');
    }
  }

  static Future<Map<String, dynamic>> getFengShuiOptimizedPlacements(
    Map<String, dynamic> gridData, {
    List<String>? objects,
    Map<String, dynamic>? config,
  }) async {
    try {
      final requestData = {
        ...gridData,
        if (objects != null) 'objects': objects,
        if (config != null) 'config': config,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/feng-shui-optimizer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get Feng Shui optimized placements: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to Feng Shui optimizer service: $e');
    }
  }
} 