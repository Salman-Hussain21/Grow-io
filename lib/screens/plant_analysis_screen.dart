import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

// App colors to match the HomeScreen
class AppColors {
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color textBlack = Color(0xFF212121);
  static const Color textGrey = Color(0xFF757575);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF8F9FA);
  static const Color beige = Color(0xFFF9FBE7);
}

class PlantAnalysisScreen extends StatefulWidget {
  const PlantAnalysisScreen({
    super.key,
    this.onAnalysisComplete,
  });

  final Future<void> Function()? onAnalysisComplete;

  @override
  State<PlantAnalysisScreen> createState() => _PlantAnalysisScreenState();
}

class _PlantAnalysisScreenState extends State<PlantAnalysisScreen> {
  final List<String> apiKeys = [
    // "claCuW52gD5y7DMHDHsbsXjSzNzr71CferpKbNdh7JxMfF5wF9",
    "FWAknG43oYzjSN0MR71hMWGeAmXv5HF3i2QXOeuU3W5V49mouY",
  ];

  int _currentApiKeyIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  XFile? _selectedImage;
  bool _isLoading = false;
  bool _saveToGarden = false;
  PlantIdentificationResult? _identificationResult;
  PlantAnalysisResult? _analysisResult;
  String? _errorMessage;
  List<Map<String, dynamic>> _matchingGardenPlants = [];
  bool _isCheckingGarden = false;
  bool _showGardenUpdateNotification = false;
  String _plantNote = '';
  final TextEditingController _noteController = TextEditingController();
  double _improvementPercentage = 0.0;
  bool _isNewPlant = false;

  // Local plant names database
  Map<String, String> _plantCommonNames = {};

  @override
  void initState() {
    super.initState();
    _loadPlantNamesFromText();
  }

  // Load plant names from text file
  Future<void> _loadPlantNamesFromText() async {
    try {
      final String content = await rootBundle.loadString('assets/plant_names.txt');
      final lines = content.split('\n');
      final plantMap = <String, String>{};

      int loadedCount = 0;

      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('"Symbol"')) continue;

        // Parse CSV with quotes correctly - split by comma but respect quotes
        final parsedLine = _parseCsvLine(line);
        if (parsedLine.length >= 4) {
          final scientificName = parsedLine[2].trim();
          final commonName = parsedLine[3].trim();

          if (scientificName.isNotEmpty && commonName.isNotEmpty) {
            // Clean the scientific name
            final cleanScientificName = _cleanScientificName(scientificName);

            if (cleanScientificName.isNotEmpty) {
              // Store with cleaned scientific name as key
              final key = cleanScientificName.toLowerCase();
              plantMap[key] = commonName;

              loadedCount++;

              // For debugging, print Dracaena entries
              if (key.contains('dracaena') && loadedCount <= 20) {
                print('Dracaena entry: "$key" -> "$commonName"');
              }
            }
          }
        }
      }

      setState(() {
        _plantCommonNames = plantMap;
      });
      print('Successfully loaded $loadedCount plant names from text file');
    } catch (e) {
      print('Failed to load plant names: $e');
    }
  }

  // Parse a CSV line with quotes correctly
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        // Toggle quote state
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        // Comma outside quotes - end of field
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    // Add the last field
    result.add(current.toString());
    return result;
  }

  // Clean scientific name by removing author names and other extras
  String _cleanScientificName(String scientificName) {
    // Remove content in parentheses (author names)
    String cleaned = scientificName.replaceAll(RegExp(r'\([^)]*\)'), '');

    // Remove author abbreviations like "L." or "Mill."
    cleaned = cleaned.replaceAll(RegExp(r'\b[A-Z][a-z]*\.'), '');

    // Remove any single quotes or cultivar indicators
    cleaned = cleaned.replaceAll("'", '').replaceAll('"', '');

    // Trim and clean up extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  // Get common name from scientific name using local database
  String _getCommonName(String scientificName) {
    if (scientificName.isEmpty) return '';

    final lowerCaseName = scientificName.toLowerCase();
    print('Looking up common name for: "$lowerCaseName"');

    // Clean the input scientific name
    final cleanedInputName = _cleanScientificName(lowerCaseName);
    print('Cleaned input name: "$cleanedInputName"');

    // 1. First try EXACT match with the cleaned scientific name
    if (_plantCommonNames.containsKey(cleanedInputName)) {
      final commonName = _plantCommonNames[cleanedInputName]!;
      print('Found exact match: "$commonName"');
      return commonName;
    }

    // 2. Try to find the specific plant by checking if we have a key that matches
    // the full scientific name (not just a partial match)
    for (final key in _plantCommonNames.keys) {
      if (key == cleanedInputName) {
        final commonName = _plantCommonNames[key]!;
        print('Found exact key match: "$key" -> "$commonName"');
        return commonName;
      }
    }

    // 3. Try reverse lookup - check if any key contains the full scientific name
    String bestMatch = '';
    int bestMatchLength = 0;

    for (final key in _plantCommonNames.keys) {
      // Look for keys that are contained within the scientific name
      if (cleanedInputName.contains(key) && key.length > bestMatchLength) {
        bestMatch = _plantCommonNames[key]!;
        bestMatchLength = key.length;
        print('Found contained key match: "$key" -> "$bestMatch"');
      }
    }

    if (bestMatch.isNotEmpty) {
      return bestMatch;
    }

    // 4. Try word-by-word matching (look for individual words from scientific name)
    final words = cleanedInputName.split(' ');
    for (final word in words) {
      if (word.length > 4 && _plantCommonNames.containsKey(word)) {
        final commonName = _plantCommonNames[word]!;
        print('Found word match: "$word" -> "$commonName"');
        return commonName;
      }
    }

    // 5. If no match found, return empty string
    print('No common name found for: "$cleanedInputName"');
    print('Available keys: ${_plantCommonNames.keys.where((k) => k.contains("dracaena")).take(10).toList()}');
    return '';
  }

  // Get the current API key
  String get _currentApiKey {
    return apiKeys[_currentApiKeyIndex];
  }

  // Rotate to the next API key
  void _rotateApiKey() {
    setState(() {
      _currentApiKeyIndex = (_currentApiKeyIndex + 1) % apiKeys.length;
    });
  }

  // Check if the identified plant exists in the user's garden
  Future<void> _checkIfPlantExistsInGarden(String plantName) async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isCheckingGarden = true;
    });

    try {
      final gardenSnapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('garden')
          .get();

      // Simple name matching
      final matches = gardenSnapshot.docs.where((doc) {
        final data = doc.data();
        final gardenPlantName = data['plantName']?.toString().toLowerCase() ?? '';
        return gardenPlantName.contains(plantName.toLowerCase()) ||
            plantName.toLowerCase().contains(gardenPlantName);
      }).map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      setState(() {
        _matchingGardenPlants = matches;
        _isCheckingGarden = false;
      });
    } catch (e) {
      print('Error checking garden: $e');
      setState(() {
        _isCheckingGarden = false;
      });
    }
  }

  // Update existing plant in garden with new analysis results
  Future<void> _updateGardenPlant(String plantId, Map<String, dynamic> plantData) async {
    if (_auth.currentUser == null || _analysisResult == null) return;

    try {
      bool isPlantHealthy = _analysisResult!.isHealthy;

      // Prepare diseases if plant is NOT healthy
      List<Map<String, dynamic>> diseaseDetails = [];
      if (!isPlantHealthy && _analysisResult!.diseases.isNotEmpty) {
        for (var disease in _analysisResult!.diseases) {
          diseaseDetails.add({
            'name': disease.name,
            'probability': disease.probability,
            'description': disease.description ?? 'No description available',
            'treatment': disease.treatment ?? 'No treatment information available',
          });
        }
      }

      // Calculate improvement percentage if previous health status exists
      if (plantData['healthStatus'] != null) {
        bool wasHealthy = plantData['healthStatus'] == 'Healthy';
        _improvementPercentage = wasHealthy && isPlantHealthy ? 100.0 :
        wasHealthy && !isPlantHealthy ? -50.0 :
        !wasHealthy && isPlantHealthy ? 100.0 : 0.0;
      }

      final updateData = {
        'healthStatus': isPlantHealthy ? 'Healthy' : 'Needs Attention',
        'lastAnalysisDate': Timestamp.now(),
        'diseases': diseaseDetails,
        'isHealthy': isPlantHealthy,
        'note': _plantNote.isNotEmpty ? _plantNote : plantData['note'] ?? '',
        'lastAnalysisResult': _analysisResult!.isHealthy ? 'Healthy' : 'Diseases detected',
        'improvementPercentage': _improvementPercentage,
      };

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('garden')
          .doc(plantId)
          .update(updateData);

      // Show success message
      setState(() {
        _showGardenUpdateNotification = true;
      });

      // Hide notification after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showGardenUpdateNotification = false;
          });
        }
      });

      if (widget.onAnalysisComplete != null) {
        widget.onAnalysisComplete!();
      }
    } catch (e) {
      print('Error updating garden plant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update plant: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add new plant to garden
  Future<void> _addNewPlantToGarden() async {
    if (_auth.currentUser == null || _identificationResult == null || _analysisResult == null) return;

    try {
      bool isPlantHealthy = _analysisResult!.isHealthy;

      // Prepare diseases if plant is NOT healthy
      List<Map<String, dynamic>> diseaseDetails = [];
      if (!isPlantHealthy && _analysisResult!.diseases.isNotEmpty) {
        for (var disease in _analysisResult!.diseases) {
          diseaseDetails.add({
            'name': disease.name,
            'probability': disease.probability,
            'description': disease.description ?? 'No description available',
            'treatment': disease.treatment ?? 'No treatment information available',
          });
        }
      }

      final gardenData = {
        'plantName': _identificationResult!.plantName,
        'plantDetails': _identificationResult!.plantDetails,
        'imageUrl': _identificationResult!.plantImageUrl,
        'addedDate': Timestamp.now(),
        'healthStatus': isPlantHealthy ? 'Healthy' : 'Needs Attention',
        'lastAnalysisDate': Timestamp.now(),
        'diseases': diseaseDetails,
        'isHealthy': isPlantHealthy,
        'note': _plantNote,
        'improvementPercentage': 0.0,
      };

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('garden')
          .add(gardenData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plant added to your garden successfully'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.onAnalysisComplete != null) {
        widget.onAnalysisComplete!();
      }
    } catch (e) {
      print('Error adding plant to garden: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add plant: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
          _identificationResult = null;
          _analysisResult = null;
          _errorMessage = null;
          _matchingGardenPlants = [];
          _showGardenUpdateNotification = false;
          _plantNote = '';
          _noteController.clear();
          _isNewPlant = false;
        });
        await _identifyPlant();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick image: ${e.toString()}";
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
          _identificationResult = null;
          _analysisResult = null;
          _errorMessage = null;
          _matchingGardenPlants = [];
          _showGardenUpdateNotification = false;
          _plantNote = '';
          _noteController.clear();
          _isNewPlant = false;
        });
        await _identifyPlant();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to take photo: ${e.toString()}";
      });
    }
  }

  Future<void> _identifyPlant() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Read image bytes
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await _selectedImage!.readAsBytes();
      } else {
        final file = File(_selectedImage!.path);
        bytes = await file.readAsBytes();
      }

      // Check file size
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Image is too large. Please select a smaller image."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Convert to base64
      final base64Image = base64Encode(bytes);

      // Make the API call for plant identification
      final response = await http.post(
        Uri.parse("https://plant.id/api/v3/identification"),
        headers: {
          "Content-Type": "application/json",
          "Api-Key": _currentApiKey,
        },
        body: jsonEncode({
          "images": [base64Image],
          "latitude": 49.207,
          "longitude": 16.608,
          "similar_images": true
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result['id'] != null) {
          await _fetchIdentificationResult(result['id']);
        } else if (result['result'] != null) {
          _processIdentificationResult(result);
        } else {
          setState(() {
            _errorMessage = "Unexpected API response format";
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // API key might be invalid, rotate to next key and retry
        _rotateApiKey();
        setState(() {
          _errorMessage = "API authentication failed. Retrying with different key...";
        });
        await _identifyPlant(); // Retry with new key
      } else {
        setState(() {
          _errorMessage = "API Error: ${response.statusCode}";
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("API Error: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      setState(() {
        _errorMessage = "Error: ${error.toString()}";
        _isLoading = false;
      });
    }
  }

  // ALTERNATIVE: Try with query parameters
  Future<void> _detectDiseases() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Read image bytes
      Uint8List bytes;
      if (kIsWeb) {
        bytes = await _selectedImage!.readAsBytes();
      } else {
        final file = File(_selectedImage!.path);
        bytes = await file.readAsBytes();
      }

      // Convert to base64
      final base64Image = base64Encode(bytes);

      // Try with query parameters as mentioned in docs
      final response = await http.post(
        Uri.parse("https://plant.id/api/v3/identification?details=common_names,description,treatment,classification,local_name,cause,url"),
        headers: {
          "Content-Type": "application/json",
          "Api-Key": _currentApiKey,
        },
        body: jsonEncode({
          "images": [base64Image],
          "latitude": 49.207,
          "longitude": 16.608,
          'similar_images': true,
          'health': 'all', // Health assessment
        }),
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);

        if (result['id'] != null) {
          await _fetchHealthResult(result['id']);
        } else if (result['result'] != null) {
          _processHealthResult(result);
        } else {
          setState(() {
            _errorMessage = "Unexpected API response format";
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // API key might be invalid, rotate to next key and retry
        _rotateApiKey();
        setState(() {
          _errorMessage = "API authentication failed. Retrying with different key...";
        });
        await _detectDiseases(); // Retry with new key
      } else {
        setState(() {
          _errorMessage = "API Error: ${response.statusCode} - ${response.body}";
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = "Error: ${error.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchIdentificationResult(String identificationId) async {
    try {
      int attempts = 0;
      const maxAttempts = 10;
      const delay = Duration(seconds: 2);

      while (attempts < maxAttempts) {
        await Future.delayed(delay);
        attempts++;

        final detailsResponse = await http.get(
          Uri.parse("https://api.plant.id/v3/identification/$identificationId"),
          headers: {
            "Api-Key": _currentApiKey,
          },
        );

        if (detailsResponse.statusCode == 200) {
          final details = jsonDecode(detailsResponse.body);
          if (details['status'] == 'completed') {
            _processIdentificationResult(details);
            return;
          } else if (details['status'] == 'failed') {
            setState(() {
              _errorMessage = "Identification failed. Please try again.";
              _isLoading = false;
            });
            return;
          }
        } else if (detailsResponse.statusCode == 401 || detailsResponse.statusCode == 403) {
          // API key might be invalid, rotate to next key
          _rotateApiKey();
          continue; // Continue with next attempt using new key
        }
      }

      setState(() {
        _errorMessage = "Identification timed out. Please try again.";
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = "Error fetching results: ${error.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHealthResult(String identificationId) async {
    try {
      int attempts = 0;
      const maxAttempts = 10;
      const delay = Duration(seconds: 2);

      while (attempts < maxAttempts) {
        await Future.delayed(delay);
        attempts++;

        // Use the identification endpoint to fetch health results
        final detailsResponse = await http.get(
          Uri.parse("https://api.plant.id/v3/identification/$identificationId"),
          headers: {
            "Api-Key": _currentApiKey,
          },
        );

        print('Details Response Status: ${detailsResponse.statusCode}');

        if (detailsResponse.statusCode == 200) {
          final details = jsonDecode(detailsResponse.body);

          if (details['status'] == 'completed') {
            _processHealthResult(details);
            return;
          } else if (details['status'] == 'failed') {
            setState(() {
              _errorMessage = 'Health assessment failed. Please try again.';
              _isLoading = false;
            });
            return;
          } else if (details['status'] == 'processing') {
            // Still processing, continue waiting
            continue;
          }
        } else if (detailsResponse.statusCode == 401 || detailsResponse.statusCode == 403) {
          // API key might be invalid, rotate to next key
          _rotateApiKey();
          continue; // Continue with next attempt using new key
        } else {
          print('Details Response Error: ${detailsResponse.body}');
        }
      }

      setState(() {
        _errorMessage = "Health assessment timed out. Please try again.";
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = "Error fetching results: ${error.toString()}";
        _isLoading = false;
      });
    }
  }

  // Add this method to check if the identified result is actually a plant
  bool _isValidPlant(dynamic result) {
    if (result['result'] == null) return false;

    // Check if we have classification suggestions
    if (result['result']['classification'] != null &&
        result['result']['classification']['suggestions'] != null &&
        result['result']['classification']['suggestions'].isNotEmpty) {

      final suggestion = result['result']['classification']['suggestions'][0];
      final probability = suggestion['probability']?.toDouble() ?? 0.0;
      final name = suggestion['name']?.toString().toLowerCase() ?? '';

      // If probability is too low
      if (probability < 0.4) return false;

      // Check for common non-plant labels with more specific terms
      final List<String> nonPlantKeywords = [
        'animal', 'human', 'person', 'face', 'car', 'vehicle', 'building',
        'house', 'food', 'fruit', 'vegetable', 'object', 'machine', 'device',
        'electronic', 'furniture', 'cloth', 'fabric', 'sky', 'cloud', 'water',
        'ocean', 'sea', 'river', 'lake', 'mountain', 'rock', 'stone', 'road',
        'street', 'wall', 'floor', 'ceiling', 'window', 'door', 'book', 'paper',
        'screen', 'phone', 'computer', 'tool', 'instrument', 'metal', 'plastic',
        'glass', 'wood', 'concrete', 'brick', 'sign', 'logo', 'text', 'writing'
      ];

      for (var keyword in nonPlantKeywords) {
        if (name.contains(keyword)) {
          return false;
        }
      }

      return true;
    }

    return false;
  }

  void _processIdentificationResult(dynamic result) {
    // First check if this is actually a plant
    if (!_isValidPlant(result)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("This doesn't appear to be a plant. Please try a different image or angle."),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {
        _isLoading = false;
        _selectedImage = null;
      });
      return;
    }

    setState(() {
      _isLoading = false;

      if (result['result'] == null) {
        _errorMessage = "No plant identified. Please try with a clearer image.";
        return;
      }

      String scientificName = 'Unknown Plant';
      String plantDetails = 'No details available';
      String wikiUrl = '';
      String plantImageUrl = '';
      List<String> commonNames = [];

      if (result['result']['classification'] != null &&
          result['result']['classification']['suggestions'] != null &&
          result['result']['classification']['suggestions'].isNotEmpty) {
        final suggestion = result['result']['classification']['suggestions'][0];
        scientificName = suggestion['name'] ?? 'Unknown Plant';

        // Try to get common names directly from the API response first
        if (suggestion['details'] != null && suggestion['details']['common_names'] != null) {
          commonNames = List<String>.from(suggestion['details']['common_names']);
        }

        // Get common name from our local database
        String commonName = _getCommonName(scientificName);

        // If no common names from API or local DB, try to extract from details
        if (commonName.isEmpty && suggestion['details'] != null) {
          final details = suggestion['details'];
          if (details['common_names'] != null && (details['common_names'] as List).isNotEmpty) {
            commonName = (details['common_names'] as List)[0].toString();
          }
        }

        // Build plant details with both common and scientific names
        if (commonName.isNotEmpty) {
          plantDetails = "Common name: $commonName\nScientific name: $scientificName";
        } else {
          plantDetails = "Scientific name: $scientificName";
        }

        // Add additional common names if available
        if (commonNames.length > 1) {
          plantDetails += "\n\nAlso known as: ${commonNames.sublist(1).join(', ')}";
        }

        // Try multiple possible description fields
        if (suggestion['details'] != null) {
          final details = suggestion['details'];

          if (details['description'] != null && details['description']['value'] != null) {
            plantDetails += "\n\nDescription: ${details['description']['value']}";
          } else if (details['taxonomy'] != null) {
            plantDetails += "\n\nTaxonomy: ${details['taxonomy']['class'] ?? 'Unknown'}";
          }
        }

        if (suggestion['similar_images'] != null &&
            suggestion['similar_images'].isNotEmpty) {
          plantImageUrl = suggestion['similar_images'][0]['url'] ?? '';
        }

        // Use common name if available, otherwise use scientific name
        String displayName = commonName.isNotEmpty ? commonName : scientificName;

        _identificationResult = PlantIdentificationResult(
          plantName: displayName,
          plantDetails: plantDetails,
          wikiUrl: wikiUrl,
          plantImageUrl: plantImageUrl,
          scientificName: scientificName,
          commonName: commonName,
        );
      }
    });

    // Check if this plant exists in the user's garden
    _checkIfPlantExistsInGarden(_identificationResult!.plantName);
  }

  void _processHealthResult(dynamic result) {
    print('Full Health API Response: ${jsonEncode(result)}');

    setState(() {
      _isLoading = false;

      if (result['result'] == null) {
        _errorMessage = "No health results found. Please try with a clearer image.";
        return;
      }

      String plantName = _identificationResult?.plantName ?? 'Unknown Plant';
      bool isHealthy = result['result']['is_healthy'] != null ?
      result['result']['is_healthy']['binary'] ?? false : false;

      List<DiseaseInfo> diseases = [];

      // Extract disease information
      if (result['result']['disease'] != null &&
          result['result']['disease']['suggestions'] != null) {

        for (var diseaseData in result['result']['disease']['suggestions']) {
          String name = diseaseData['name'] ?? 'Unknown Disease';
          double probability = diseaseData['probability']?.toDouble() ?? 0.0;
          String description = 'No description available';
          String treatment = 'No treatment information available';

          print('Disease data: ${jsonEncode(diseaseData)}');

          // Extract details if available
          if (diseaseData['details'] != null) {
            var details = diseaseData['details'];
            print('Disease details: ${jsonEncode(details)}');

            description = _extractDescription(details);
            treatment = _extractTreatment(details);
          }

          diseases.add(DiseaseInfo(
            name: name,
            probability: probability,
            description: description,
            treatment: treatment,
          ));
        }
      }

      _analysisResult = PlantAnalysisResult(
        isHealthy: isHealthy,
        plantName: plantName,
        diseases: diseases,
      );

      // Save to Firebase
      _saveAnalysisToFirebase();

      // If plant exists in garden and user didn't choose to add as new plant, update it
      if (_matchingGardenPlants.isNotEmpty && !_isNewPlant) {
        for (var plant in _matchingGardenPlants) {
          _updateGardenPlant(plant['id'], plant);
        }
      } else if (_saveToGarden) {
        // If it's a new plant and user wants to save to garden, add it
        _addNewPlantToGarden();
      }
    });
  }

  // Helper method to extract description
  String _extractDescription(Map<String, dynamic> details) {
    // Try different description field patterns
    if (details['description'] != null) {
      if (details['description'] is Map) {
        return details['description']['value'] ??
            details['description']['description'] ??
            'No description available';
      } else if (details['description'] is String) {
        return details['description'];
      }
    }

    // Try common names
    if (details['common_names'] != null &&
        (details['common_names'] as List).isNotEmpty) {
      return "Also known as: ${(details['common_names'] as List).join(', ')}";
    }

    // Try classification
    if (details['classification'] != null && details['classification'] is Map) {
      final classification = details['classification'];
      if (classification['class'] != null) {
        return "Classification: ${classification['class']}";
      }
    }

    return 'No description available';
  }

  // Helper method to extract treatment
  String _extractTreatment(Map<String, dynamic> details) {
    // Try treatment information
    if (details['treatment'] != null) {
      if (details['treatment'] is Map) {
        final treatment = details['treatment'];

        // Try different treatment field patterns
        if (treatment['chemical'] != null &&
            (treatment['chemical'] as List).isNotEmpty) {
          return "Chemical treatment: ${(treatment['chemical'] as List).join(', ')}";
        }
        else if (treatment['biological'] != null &&
            (treatment['biological'] as List).isNotEmpty) {
          return "Biological treatment: ${(treatment['biological'] as List).join(', ')}";
        }
        else if (treatment['prevention'] != null &&
            (treatment['prevention'] as List).isNotEmpty) {
          return "Prevention tips:\n• ${(treatment['prevention'] as List).join('\n• ')}";
        }
        else if (treatment['description'] != null) {
          if (treatment['description'] is Map) {
            return treatment['description']['value'] ??
                'No treatment information available';
          } else if (treatment['description'] is String) {
            return treatment['description'];
          }
        }
      }
      else if (details['treatment'] is String) {
        return details['treatment'];
      }
    }

    // Try cause as alternative information
    if (details['cause'] != null) {
      return "Possible cause: ${details['cause']}";
    }

    return 'No treatment information available';
  }

  Future<void> _saveAnalysisToFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      bool isPlantHealthy = _analysisResult?.isHealthy == true;

      // ✅ ONLY prepare diseases if plant is NOT healthy
      List<Map<String, dynamic>> diseaseDetails = [];
      if (!isPlantHealthy && _analysisResult?.diseases != null) {
        for (var disease in _analysisResult!.diseases) {
          diseaseDetails.add({
            'name': disease.name,
            'probability': disease.probability,
            'description': disease.description ?? 'No description available',
            'treatment': disease.treatment ?? 'No treatment information available',
          });
        }
      }

      // ✅ Save to analysis history
      final analysisData = {
        'plantName': _analysisResult?.plantName ?? _identificationResult?.plantName ?? 'Unknown',
        'scientificName': _identificationResult?.scientificName ?? '',
        'commonName': _identificationResult?.commonName ?? '',
        'status': isPlantHealthy ? 'Healthy' : 'Needs Attention',
        'diseases': diseaseDetails,
        'imageUrl': _identificationResult?.plantImageUrl ?? '',
        'analysisDate': Timestamp.now(),
        'saveToGarden': _saveToGarden,
        'isHealthy': isPlantHealthy,
        'note': _plantNote,
        'improvementPercentage': _improvementPercentage,
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plantAnalysisHistory')
          .add(analysisData);

      if (widget.onAnalysisComplete != null) {
        widget.onAnalysisComplete!();
      }

    } catch (e) {
      print('❌ Error saving to Firebase: $e');
    }
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return kIsWeb
        ? Image.network(_selectedImage!.path, height: 200, width: 200, fit: BoxFit.cover)
        : Image.file(File(_selectedImage!.path), height: 200, width: 200, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Plant Analysis',
          style: TextStyle(
            color: AppColors.textBlack,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textBlack),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_analysisResult != null)
            IconButton(
              icon: const Icon(Iconsax.refresh, color: AppColors.textBlack),
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _identificationResult = null;
                  _analysisResult = null;
                  _errorMessage = null;
                });
              },
            ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_analysisResult != null) {
      return _buildAnalysisResult();
    } else if (_identificationResult != null) {
      return _buildIdentificationResult();
    } else if (_selectedImage != null && _isLoading) {
      return _buildLoadingState();
    } else {
      return _buildUploadSection();
    }
  }

  Widget _buildUploadSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Text(
            'Plant Health Analysis',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a photo to identify your plant and detect diseases',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Scan Card
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.camera,
                    size: 48,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to Scan Plant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take a photo or choose from gallery',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Features Grid
          const Text(
            'What you can do:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildFeatureItem(
                icon: Iconsax.health,
                title: 'Disease Detection',
                subtitle: 'Identify plant diseases',
              ),
              _buildFeatureItem(
                icon: Iconsax.info_circle,
                title: 'Plant Identification',
                subtitle: 'Recognize plant species',
              ),
              _buildFeatureItem(
                icon: Iconsax.lamp_charge,
                title: 'Care Tips',
                subtitle: 'Get expert advice',
              ),
              _buildFeatureItem(
                icon: Iconsax.save_2,
                title: 'Save to Garden',
                subtitle: 'Track your plants',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: AppColors.primaryGreen),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  strokeWidth: 3,
                ),
                Icon(
                  Icons.energy_savings_leaf,
                  size: 32,
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your plant...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: TextStyle(
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentificationResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plant Image
          Container(
            height: 250,
            width: double.infinity, // Add this
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Show the uploaded image - Center it
                if (_selectedImage != null)
                  Center(
                    child: kIsWeb
                        ? Image.network(_selectedImage!.path, fit: BoxFit.contain)
                        : Image.file(File(_selectedImage!.path), fit: BoxFit.contain),
                  ),
                // Show the identified plant image as an overlay if available
                if (_identificationResult != null &&
                    _identificationResult!.plantImageUrl.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _identificationResult!.plantImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Plant Name
          Text(
            _identificationResult!.plantName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 8),

          // Scientific Name
          if (_identificationResult!.scientificName.isNotEmpty &&
              _identificationResult!.scientificName != _identificationResult!.plantName)
            Text(
              _identificationResult!.scientificName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 24),

          // Plant Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _identificationResult!.plantDetails,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGrey,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Health Check Button
          ElevatedButton(
            onPressed: () {
              if (_matchingGardenPlants.isNotEmpty && !_isNewPlant && !_saveToGarden) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Please choose whether to add as new plant or sync with existing"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              _detectDiseases();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.health, size: 20),
                SizedBox(width: 8),
                Text(
                  'Diagnose Plant Health',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Save to Garden Option
          if (_matchingGardenPlants.isEmpty)
            Row(
              children: [
                Checkbox(
                  value: _saveToGarden,
                  onChanged: (value) {
                    setState(() {
                      _saveToGarden = value ?? false;
                    });
                  },
                  activeColor: AppColors.primaryGreen,
                ),
                const Text('Save to my garden'),
              ],
            ),

          // Already in Garden Options
          if (_matchingGardenPlants.isNotEmpty)
            Column(
              children: [
                Text(
                  'This plant is already in your garden',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isNewPlant = true;
                            _matchingGardenPlants = [];
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: BorderSide(color: AppColors.primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add as New Plant'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isNewPlant = false;
                            _saveToGarden = true;
                          });
                          _detectDiseases();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Update Existing'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 15),

          // Note Input Field (Add this before health check)
          TextFormField(
            controller: _noteController,
            onChanged: (value) {
              setState(() {
                _plantNote = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Add a note about this plant',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(Iconsax.note, color: AppColors.primaryGreen),
            ),
            maxLines: 1,
          ),

          const SizedBox(height: 125),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plant Image - Show the uploaded image
          Container(
            height: 250,
            width: double.infinity, // Add this
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Show the uploaded image - Center it
                if (_selectedImage != null)
                  Center(
                    child: kIsWeb
                        ? Image.network(_selectedImage!.path, fit: BoxFit.contain)
                        : Image.file(File(_selectedImage!.path), fit: BoxFit.contain),
                  ),
                // Show the identified plant image as an overlay if available
                if (_identificationResult != null &&
                    _identificationResult!.plantImageUrl.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _identificationResult!.plantImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Plant Name
          Text(
            _analysisResult!.plantName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 8),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: _analysisResult!.isHealthy
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _analysisResult!.isHealthy ? 'HEALTHY' : 'NEEDS ATTENTION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _analysisResult!.isHealthy
                    ? AppColors.primaryGreen
                    : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Result Message
          Text(
            _analysisResult!.isHealthy
                ? 'Your plant is healthy! No diseases detected. Keep up the good care!'
                : 'We detected some issues with your plant:',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Disease List
          if (!_analysisResult!.isHealthy)
            ..._analysisResult!.diseases.map((disease) => _buildDiseaseCard(disease)),

        ],
      ),
    );
  }

  Widget _buildDiseaseCard(DiseaseInfo disease) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.warning_2, size: 20, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  disease.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ),
              Chip(
                label: Text(
                  '${(disease.probability * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.orange[700],
              ),
            ],
          ),
          if (disease.description != null && disease.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                disease.description!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          if (disease.treatment != null && disease.treatment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Treatment: ${disease.treatment!}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Iconsax.camera, color: AppColors.primaryGreen),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.gallery, color: AppColors.primaryGreen),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class PlantIdentificationResult {
  final String plantName;
  final String plantDetails;
  final String wikiUrl;
  final String plantImageUrl;
  final String scientificName;
  final String commonName;

  PlantIdentificationResult({
    required this.plantName,
    required this.plantDetails,
    required this.wikiUrl,
    required this.plantImageUrl,
    this.scientificName = '',
    this.commonName = '',
  });
}

class PlantAnalysisResult {
  final bool isHealthy;
  final String plantName;
  final List<DiseaseInfo> diseases;

  PlantAnalysisResult({
    required this.isHealthy,
    required this.plantName,
    required this.diseases,
  });
}

class DiseaseInfo {
  final String name;
  final double probability;
  final String? description;
  final String? treatment;

  DiseaseInfo({
    required this.name,
    required this.probability,
    this.description,
    this.treatment,
  });
}