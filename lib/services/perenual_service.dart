// services/perenual_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class PerenualService {
  static const String apiKey = 'sk-4PMi68a09a575474611868'; // Replace with your key
  static const String baseUrl = 'https://perenual.com/api';

  // Get plant care information by name
  static Future<Map<String, dynamic>> getPlantCareInfo(String plantName) async {
    try {
      // First search for the plant
      final searchUrl = '$baseUrl/species-list?key=$apiKey&q=${Uri.encodeComponent(plantName)}';
      final searchResponse = await http.get(Uri.parse(searchUrl));

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);
        if (searchData['data'] != null && searchData['data'].length > 0) {
          final plantId = searchData['data'][0]['id'];

          // Get detailed plant information
          final detailUrl = '$baseUrl/species/details/$plantId?key=$apiKey';
          final detailResponse = await http.get(Uri.parse(detailUrl));

          if (detailResponse.statusCode == 200) {
            return json.decode(detailResponse.body);
          }
        }
      }
      return {};
    } catch (e) {
      print('Perenual API Error: $e');
      return {};
    }
  }

  // Extract care schedule from Perenual data
  static Map<String, dynamic> extractCareSchedule(Map<String, dynamic> plantData) {
    final data = plantData['data'] ?? {};

    return {
      'watering': _getWateringSchedule(data),
      'light': _getLightRequirements(data),
      'temperature': _getTemperatureRange(data),
      'fertilizing': _getFertilizingSchedule(data),
      'pruning': _getPruningInfo(data),
    };
  }

  static Map<String, dynamic> _getWateringSchedule(Map<String, dynamic> data) {
    final watering = data['watering']?.toString() ?? 'Average';
    final description = data['watering_general_benchmark']?.toString() ?? 'Water when soil is dry';

    return {
      'frequency_days': _getWateringFrequency(watering),
      'description': description,
      'amount': 'Until water drains from bottom',
    };
  }

  static int _getWateringFrequency(String wateringNeed) {
    switch (wateringNeed.toLowerCase()) {
      case 'frequent': return 3;
      case 'average': return 7;
      case 'minimum': return 14;
      case 'none': return 30;
      default: return 7;
    }
  }

  static Map<String, dynamic> _getLightRequirements(Map<String, dynamic> data) {
    final sunlight = data['sunlight'] ?? ['Partial sun'];
    String lightDescription;

    if (sunlight is List) {
      lightDescription = sunlight.join(', ');
    } else {
      lightDescription = sunlight?.toString() ?? 'Partial sun';
    }

    return {
      'requirement': lightDescription,
      'hours': '6-8 hours daily',
      'best_location': _getBestLocation(lightDescription),
    };
  }

  static String _getBestLocation(String lightDescription) {
    if (lightDescription.toLowerCase().contains('full sun')) {
      return 'South-facing window';
    } else if (lightDescription.toLowerCase().contains('partial sun')) {
      return 'East or West-facing window';
    } else {
      return 'North-facing window or bright indoor spot';
    }
  }

  static Map<String, dynamic> _getTemperatureRange(Map<String, dynamic> data) {
    final growth = data['growth'] ?? {};
    final tempMin = growth['temperature_minimum']?['deg_c']?.toString() ?? '15';
    final tempMax = growth['temperature_maximum']?['deg_c']?.toString() ?? '27';

    return {
      'ideal_range': '$tempMin°C - $tempMax°C',
      'min_temp': '$tempMin°C',
      'max_temp': '$tempMax°C',
      'protection_required': (double.tryParse(tempMin) ?? 15) < 10 ? 'Protect from frost' : 'Generally hardy',
    };
  }

  static Map<String, dynamic> _getFertilizingSchedule(Map<String, dynamic> data) {
    return {
      'frequency': 'Every 4-6 weeks during growing season',
      'type': 'Balanced liquid fertilizer (10-10-10)',
      'dormant_period': 'Reduce or stop fertilizing in winter',
    };
  }

  static Map<String, dynamic> _getPruningInfo(Map<String, dynamic> data) {
    final pruning = data['pruning']?.toString() ?? 'As needed';
    final pruningMonth = data['pruning_month']?.toString() ?? 'Spring';

    return {
      'frequency': pruning,
      'best_time': pruningMonth,
      'description': 'Remove dead or damaged leaves regularly',
    };
  }

  // Fallback method if API fails
  static Map<String, dynamic> getBasicCareTemplate(String plantName) {
    final plantType = _detectPlantType(plantName);

    final templates = {
      'succulent': {
        'watering': {'frequency_days': 14, 'description': 'Allow soil to dry completely'},
        'light': {'requirement': 'Direct sunlight', 'hours': '6+ hours'},
        'temperature': {'ideal_range': '18-27°C', 'min_temp': '10°C'},
        'fertilizing': {'frequency': 'Quarterly', 'type': 'Cactus fertilizer'},
      },
      'tropical': {
        'watering': {'frequency_days': 7, 'description': 'Keep soil moist but not soggy'},
        'light': {'requirement': 'Bright indirect light', 'hours': '6-8 hours'},
        'temperature': {'ideal_range': '18-29°C', 'min_temp': '15°C'},
        'fertilizing': {'frequency': 'Monthly', 'type': 'Balanced fertilizer'},
      },
      'flowering': {
        'watering': {'frequency_days': 5, 'description': 'Keep soil consistently moist'},
        'light': {'requirement': 'Direct to bright indirect', 'hours': '6-8 hours'},
        'temperature': {'ideal_range': '15-24°C', 'min_temp': '10°C'},
        'fertilizing': {'frequency': 'Bi-weekly', 'type': 'Bloom booster fertilizer'},
      }
    };

    return templates[plantType] ?? templates['tropical']!;
  }

  static String _detectPlantType(String plantName) {
    final lowerName = plantName.toLowerCase();

    if (lowerName.contains('cactus') || lowerName.contains('succulent') ||
        lowerName.contains('aloe') || lowerName.contains('snake')) {
      return 'succulent';
    } else if (lowerName.contains('orchid') || lowerName.contains('lily') ||
        lowerName.contains('rose') || lowerName.contains('flower')) {
      return 'flowering';
    } else if (lowerName.contains('monstera') || lowerName.contains('pothos') ||
        lowerName.contains('philodendron') || lowerName.contains('palm')) {
      return 'tropical';
    }

    return 'tropical';
  }
}