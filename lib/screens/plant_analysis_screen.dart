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
  // Multiple API keys for rotation
  final List<String> apiKeys = [
    // "rkgDlTzrfd8zQjxsHZtpAYQltrnQ0JRBrClvXwdTVRywDBC74c",
    // "SQutC5nRxs4Srjh4l8eiHRsxLBogHQ6lnRy841LbeIO5kTeJ8n",
    "claCuW52gD5y7DMHDHsbsXjSzNzr71CferpKbNdh7JxMfF5wF9",
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

  // App colors
  final Color primaryColor = const Color(0xFF4CAF50);
  final Color secondaryColor = const Color(0xFF8BC34A);
  final Color accentColor = const Color(0xFF689F38);
  final Color backgroundColor = const Color(0xFFF9FBE7);
  final Color textColor = const Color(0xFF33691E);

  @override
  void initState() {
    super.initState();
    // Load plant names from your text file
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
        setState(() {
          _errorMessage = "Image is too large. Please select a smaller image.";
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
      final name = suggestion['name'] ?? '';

      // If probability is too low or name suggests non-plant content
      if (probability < 0.3) return false;

      // Check for common non-plant labels
      final List<String> nonPlantKeywords = [
        'animal', 'human', 'person', 'face', 'car', 'vehicle', 'building',
        'house', 'food', 'fruit', 'vegetable', 'object', 'machine', 'device',
        'electronic', 'furniture', 'cloth', 'fabric', 'sky', 'cloud', 'water',
        'ocean', 'sea', 'river', 'lake', 'mountain', 'rock', 'stone'
      ];

      final lowerCaseName = name.toLowerCase();
      for (var keyword in nonPlantKeywords) {
        if (lowerCaseName.contains(keyword)) {
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
      setState(() {
        _isLoading = false;
        _errorMessage = "Kindly upload a valid plant image. The uploaded image doesn't appear to contain a plant.";
        _selectedImage = null; // Clear the selected image
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundColor.withOpacity(0.3), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // API Key Indicator (optional)
              // if (apiKeys.length > 1)
              //   Container(
              //     padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              //     decoration: BoxDecoration(
              //       color: Colors.grey[200],
              //       borderRadius: BorderRadius.circular(8),
              //     ),
              //     child: Text(
              //       'Using API Key ${_currentApiKeyIndex + 1} of ${apiKeys.length}',
              //       style: const TextStyle(fontSize: 12, color: Colors.grey),
              //     ),
              //   ),
              //
              // const SizedBox(height: 8),

              // Upload Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor.withOpacity(0.1), secondaryColor.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.eco, size: 50, color: Color(0xFF4CAF50)),
                        const SizedBox(height: 16),
                        const Text(
                          'Plant Health Analysis',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload a photo to identify your plant and detect diseases',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              icon: Icons.camera_alt,
                              label: 'Take Photo',
                              onPressed: _takePhoto,
                              color: primaryColor,
                            ),
                            _buildActionButton(
                              icon: Icons.photo_library,
                              label: 'From Gallery',
                              onPressed: _pickImage,
                              color: secondaryColor,
                            ),
                          ],
                        ),
                        if (_selectedImage != null) ...[
                          const SizedBox(height: 20),
                          _buildImagePreview(),
                          const SizedBox(height: 10),
                          Text(
                            'Selected: ${_selectedImage!.name}',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Plant Note Input (shown when plant is identified)
              if (_identificationResult != null && _analysisResult == null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add a note about this plant (optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Indoor plant, Living room, Backyard, etc.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _plantNote = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Loading Indicator
              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      _analysisResult == null ? 'Identifying plant...' : 'Analyzing health...',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

              // Checking Garden Indicator
              if (_isCheckingGarden)
                Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    const Text(
                      'Checking if plant exists in your garden...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),

              // Error Message
              if (_errorMessage != null)
                Card(
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Garden Update Notification
              if (_showGardenUpdateNotification)
                Card(
                  color: Colors.green[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Plant information updated in your garden! ${_improvementPercentage != 0 ? 'Improvement: ${_improvementPercentage.toStringAsFixed(1)}%' : ''}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Plant already in garden notification
              if (_matchingGardenPlants.isNotEmpty && _identificationResult != null && _analysisResult == null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Plant Already in Your Garden',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'This plant appears to already exist in your garden. What would you like to do?',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        SizedBox(height: 16),
                        Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // Sync with existing plant
                                setState(() {
                                  _saveToGarden = true;
                                  _isNewPlant = false;
                                });
                                _detectDiseases();
                              },
                              icon: Icon(Icons.sync),
                              label: Text('Proceed & Sync with existing plant'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 50),
                              ),
                            ),
                            SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                // Add as new plant
                                setState(() {
                                  _matchingGardenPlants = [];
                                  _saveToGarden = true;
                                  _isNewPlant = true;
                                });
                                _detectDiseases();
                              },
                              icon: Icon(Icons.add),
                              label: Text('Add as new plant'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor),
                                minimumSize: Size(double.infinity, 50),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Save to Garden Checkbox (shown only when we have identification but before analysis and plant is NOT in garden)
              if (_identificationResult != null && _analysisResult == null && _matchingGardenPlants.isEmpty)
                Column(
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _saveToGarden,
                              onChanged: (value) {
                                setState(() {
                                  _saveToGarden = value ?? false;
                                });
                              },
                              activeColor: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Save this plant to my garden',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildIdentificationCard(),
                  ],
                ),

// Analysis Result
              if (_analysisResult != null)
                _buildAnalysisResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildIdentificationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Plant Identified',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Changed from Row to Column to prevent overflow
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_identificationResult!.plantImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _identificationResult!.plantImageUrl,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _identificationResult!.plantName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Show scientific name if different from common name
                    if (_identificationResult!.scientificName.isNotEmpty &&
                        _identificationResult!.scientificName != _identificationResult!.plantName)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _identificationResult!.scientificName,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _identificationResult!.plantDetails,
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _detectDiseases,
                icon: const Icon(Icons.health_and_safety),
                label: const Text('Check Plant Health'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResultCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _analysisResult!.isHealthy
                    ? [Colors.green.shade600, Colors.green.shade400]
                    : [Colors.orange.shade600, Colors.orange.shade400],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    _analysisResult!.isHealthy ? Icons.check_circle : Icons.warning,
                    color: _analysisResult!.isHealthy ? Colors.green : Colors.orange,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _analysisResult!.plantName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Show scientific name if different from common name
                      if (_identificationResult != null &&
                          _identificationResult!.scientificName.isNotEmpty &&
                          _identificationResult!.scientificName != _analysisResult!.plantName)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _identificationResult!.scientificName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _analysisResult!.isHealthy ? 'HEALTHY' : 'NEEDS ATTENTION',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      if (_plantNote.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: $_plantNote',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _analysisResult!.isHealthy
                ? Column(
              children: [
                Icon(Icons.emoji_emotions, size: 60, color: primaryColor),
                const SizedBox(height: 16),
                const Text(
                  'Your plant is healthy!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No diseases detected. Keep up the good care!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  _matchingGardenPlants.isNotEmpty && !_isNewPlant
                      ? 'Plant information updated in your garden! ${_improvementPercentage != 0 ? 'Improvement: ${_improvementPercentage.toStringAsFixed(1)}%' : ''}'
                      : _saveToGarden
                      ? 'Plant added to your garden successfully!'
                      : 'Analysis saved to your history',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Issues',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._analysisResult!.diseases.map((disease) => _buildDiseaseInfo(disease)),
                const SizedBox(height: 16),
                Text(
                  _matchingGardenPlants.isNotEmpty && !_isNewPlant
                      ? 'Plant information updated in your garden! ${_improvementPercentage != 0 ? 'Improvement: ${_improvementPercentage.toStringAsFixed(1)}%' : ''}'
                      : _saveToGarden
                      ? 'Plant added to your garden successfully!'
                      : 'Analysis saved to your history',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseInfo(DiseaseInfo disease) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Disease Header
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  disease.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ),
              Chip(
                label: Text(
                  '${(disease.probability * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: Colors.orange[700],
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description Section
          if (disease.description != null && disease.description!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  disease.description!,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
              ],
            ),

          // Treatment Section
          if (disease.treatment != null && disease.treatment!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Treatment & Prevention:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[100]!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    disease.treatment!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),

          // Fallback message if no information is available
          if ((disease.description == null || disease.description!.isEmpty) &&
              (disease.treatment == null || disease.treatment!.isEmpty))
            Text(
              'No detailed information available for this disease.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
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