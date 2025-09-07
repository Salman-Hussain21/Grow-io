// services/growbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GrowBotService {
  static const String _apiKey = 'sk-9pW268be050ef23ac12269';
  static const String _baseUrl = 'https://perenual.com/api';

  Future<String> getPlantResponse(String userMessage) async {
    try {
      final message = userMessage.toLowerCase();

      // Handle basic conversations
      if (_isGreeting(message)) return _handleGreeting();
      if (_isThanks(message)) return _handleThanks();
      if (_isHowAreYou(message)) return _handleHowAreYou();

      // Extract plant name and get specific info
      final plantName = _extractPlantName(message);
      if (plantName.isNotEmpty) {
        return await _getDetailedPlantInfo(plantName);
      }

      // Handle general plant questions
      return await _handleGeneralPlantQuery(message);

    } catch (e) {
      return "I'm having trouble accessing plant data right now. Please try again in a moment. In the meantime, most plants need good light, proper watering, and well-draining soil!";
    }
  }

  Future<String> _getDetailedPlantInfo(String plantName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/species-list?key=$_apiKey&q=$plantName'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final plant = data['data'][0];
          return _formatBetterPlantResponse(plant, plantName);
        }
      }

      return _getGeneralPlantInfo(plantName);
    } catch (e) {
      return _getGeneralPlantInfo(plantName);
    }
  }

  String _formatBetterPlantResponse(Map<String, dynamic> plant, String plantName) {
    final commonName = plant['common_name']?.toString() ?? plantName;
    final scientificName = plant['scientific_name'] != null &&
        (plant['scientific_name'] as List).isNotEmpty ?
    ' (${(plant['scientific_name'] as List).first})' : '';

    final watering = _parseWatering(plant['watering']);
    final sunlight = _parseSunlight(plant['sunlight']);
    final careLevel = plant['maintenance']?.toString().capitalize() ?? 'Moderate';
    final cycle = plant['cycle']?.toString().capitalize() ?? 'Perennial';

    return '''
🌿 **$commonName$scientificName**

**Basic Care:**
• 💧 **Watering:** $watering
• ☀️ **Light:** $sunlight
• 🌱 **Care Level:** $careLevel
• 📅 **Lifecycle:** $cycle

**Pro Tip:** ${_getSpecificProTip(plantName.toLowerCase())}

*This information comes from the Large plant database. Remember to observe your plant and adjust care based on its specific needs!*''';
  }

  String _parseWatering(dynamic watering) {
    if (watering == null) return 'When soil is dry to touch';
    if (watering is String) {
      return watering.replaceAll('_', ' ').capitalize();
    }
    return 'When soil is dry to touch';
  }

  String _parseSunlight(dynamic sunlight) {
    if (sunlight == null) return 'Bright indirect light';
    if (sunlight is String) {
      return sunlight.replaceAll('_', ' ').capitalize();
    }
    if (sunlight is List) {
      return sunlight.map((s) => s.toString().replaceAll('_', ' ').capitalize()).join(' or ');
    }
    return 'Bright indirect light';
  }

  String _getSpecificProTip(String plantName) {
    final proTips = {
      'aloe': 'Aloe vera gel has healing properties! Use fresh gel from leaves for minor burns.',
      'rose': 'Deadhead spent blooms to encourage more flowers throughout the season.',
      'orchid': 'Water with room temperature water and avoid getting water in the crown.',
      'cactus': 'Reduce watering significantly in winter months when dormant.',
      'succulent': 'Propagate easily from leaves or stem cuttings.',
      'pothos': 'One of the easiest plants to grow - great for beginners!',
      'monstera': 'Wipe leaves monthly to keep them dust-free and photosynthesizing efficiently.',
    };
    return proTips[plantName] ?? 'Rotate your plant regularly for even growth.';
  }

  String _getGeneralPlantInfo(String plantName) {
    return '''
🌱 **$plantName.capitalize()**

While I don't have specific data for $plantName right now, here's general care advice:

Basic Needs:
• 💧 Water when top inch of soil is dry
• ☀️ Provide bright, indirect light
• 🌱 Use well-draining soil
• 🍃 Fertilize during growing season

Tip: Most plants thrive with consistent care and observation. Watch how your $plantName responds to its environment!''';
  }

  Future<String> _handleGeneralPlantQuery(String message) async {
    // Simple pattern matching for common questions
    if (message.contains('water') || message.contains('watering')) {
      return '''💧 **Watering Guide**

Most plants need watering when the top 1-2 inches of soil feel dry. Here's a quick guide:

• Succulents/Cactus:** Every 2-4 weeks
• Tropical plants:** Every 1-2 weeks  
• Most houseplants:** Every 1-2 weeks
• Seedlings:** Keep consistently moist

Always check soil moisture before watering!''';
    }

    if (message.contains('light') || message.contains('sun')) {
      return '''☀️ Light Requirements

Plants have different light needs:

• Bright direct:** South-facing windows (cacti, succulents)
• Bright indirect:** East/west windows (most houseplants)
• Low light:** North windows or away from windows (snake plants, pothos)

Observe your plant - leggy growth means it needs more light!''';
    }

    if (message.contains('problem') || message.contains('yellow') || message.contains('brown')) {
      return '''🔍 Common Plant Problems

Yellow leaves: Often overwatering or nutrient deficiency
Brown tips: Usually low humidity or underwatering  
Drooping: Could be overwatering or underwatering
No growth: Might need more light or fertilizer

Describe specific symptoms for more help!''';
    }

    // Default response for general queries
    return ''' Growio 🌿

I can help you with specific plant care questions! Try asking about:

• A specific plant (e.g., "How to care for aloe vera?")
• Watering needs  
• Light requirements
• Common problems
• Propagation tips

What would you like to know? 😊''';
  }

  // Helper methods
  bool _isGreeting(String message) => message.contains('hello') || message.contains('hi') || message.contains('hey');
  bool _isThanks(String message) => message.contains('thank') || message.contains('thanks');
  bool _isHowAreYou(String message) => message.contains('how are you');

  String _handleGreeting() => '''Hi there! 👋 I'm GrowBot, your plant care assistant.

I can help you with:
• Specific plant care instructions
• Watering and light needs
• Problem diagnosis
• Growing tips

What plant would you like to learn about today?''';

  String _handleThanks() => '''You're welcome! 😊 I'm always here to help with your plant care journey.

Is there anything else you'd like to know about your plants?''';

  String _handleHowAreYou() => '''I'm doing great! Ready to help you with all your plant care questions. 🌸

What would you like to know about today?''';

  String _extractPlantName(String message) {
    final plantKeywords = [
      'aloe', 'vera', 'rose', 'orchid', 'cactus', 'succulent', 'pothos',
      'monstera', 'fern', 'palm', 'ivy', 'lavender', 'basil', 'mint',
      'tomato', 'snake', 'peace lily', 'ficus', 'rubber', 'spider',
      'zz plant', 'dracaena', 'calathea', 'philodendron', 'bonsai',
      'hibiscus', 'jade', 'carnation', 'daisy', 'tulip', 'sunflower'
    ];

    for (final plant in plantKeywords) {
      if (message.contains(plant)) return plant;
    }
    return '';
  }
}

extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}