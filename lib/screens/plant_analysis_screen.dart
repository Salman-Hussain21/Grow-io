import 'package:flutter/material.dart';
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
  final apiKey = "rkgDlTzrfd8zQjxsHZtpAYQltrnQ0JRBrClvXwdTVRywDBC74c";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  XFile? _selectedImage;
  bool _isLoading = false;
  bool _saveToGarden = false;
  PlantIdentificationResult? _identificationResult;
  PlantAnalysisResult? _analysisResult;
  String? _errorMessage;

  // App colors
  final Color primaryColor = const Color(0xFF4CAF50);
  final Color secondaryColor = const Color(0xFF8BC34A);
  final Color accentColor = const Color(0xFF689F38);
  final Color backgroundColor = const Color(0xFFF9FBE7);
  final Color textColor = const Color(0xFF33691E);

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
          "Api-Key": apiKey,
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
          "Api-Key": apiKey,
        },
        body: jsonEncode({
          "images": [base64Image],
          "latitude": 49.207,
          "longitude": 16.608,
          "similar_images": true,
          "health": "only", // Health assessment only
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
            "Api-Key": apiKey,
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
            "Api-Key": apiKey,
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
              _errorMessage = "Health assessment failed. Please try again.";
              _isLoading = false;
            });
            return;
          } else if (details['status'] == 'processing') {
            // Still processing, continue waiting
            continue;
          }
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

      String plantName = 'Unknown Plant';
      String plantDetails = 'No details available';
      String wikiUrl = '';
      String plantImageUrl = '';

      if (result['result']['classification'] != null &&
          result['result']['classification']['suggestions'] != null &&
          result['result']['classification']['suggestions'].isNotEmpty) {
        final suggestion = result['result']['classification']['suggestions'][0];
        plantName = suggestion['name'] ?? 'Unknown Plant';

        // Improved description extraction
        if (suggestion['details'] != null) {
          final details = suggestion['details'];

          // Try multiple possible description fields
          if (details['common_names'] != null && (details['common_names'] as List).isNotEmpty) {
            plantDetails = "Common names: ${(details['common_names'] as List).join(', ')}";
          } else if (details['description'] != null) {
            plantDetails = details['description']['value'] ?? 'No details available';
          } else if (details['taxonomy'] != null) {
            plantDetails = "Taxonomy: ${details['taxonomy']['class'] ?? 'Unknown'}";
          }
        }

        if (suggestion['similar_images'] != null &&
            suggestion['similar_images'].isNotEmpty) {
          plantImageUrl = suggestion['similar_images'][0]['url'] ?? '';
        }
      }

      _identificationResult = PlantIdentificationResult(
        plantName: plantName,
        plantDetails: plantDetails,
        wikiUrl: wikiUrl,
        plantImageUrl: plantImageUrl,
      );
    });
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
        'status': isPlantHealthy ? 'Healthy' : 'Needs Attention',
        'diseases': diseaseDetails, // This will be empty array for healthy plants
        'imageUrl': _identificationResult?.plantImageUrl ?? '',
        'analysisDate': Timestamp.now(),
        'saveToGarden': _saveToGarden,
        'isHealthy': isPlantHealthy, // ✅ CRITICAL: Add this field
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plantAnalysisHistory')
          .add(analysisData);

      // ✅ If user wants to save to garden
      if (_saveToGarden && _identificationResult != null) {
        final gardenData = {
          'plantName': _identificationResult!.plantName,
          'plantDetails': _identificationResult!.plantDetails,
          'imageUrl': _identificationResult!.plantImageUrl,
          'addedDate': Timestamp.now(),
          'healthStatus': isPlantHealthy ? 'Healthy' : 'Needs Attention',
          'lastAnalysisDate': Timestamp.now(),
          'diseases': diseaseDetails, // ✅ This will be empty for healthy plants
          'isHealthy': isPlantHealthy, // ✅ CRITICAL: This field must be added
        };

        print('💾 Saving to garden - isHealthy: $isPlantHealthy');
        print('💾 Diseases count: ${diseaseDetails.length}');

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('garden')
            .add(gardenData);
      }

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

              // Save to Garden Checkbox (shown only when we have identification but before analysis)
// Save to Garden Checkbox and Identification Result
              if (_identificationResult != null && _analysisResult == null)
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
                    const SizedBox(height: 16), // Add some spacing
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                  'Analysis saved to your history',
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
                  'Analysis saved to your history',
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

  PlantIdentificationResult({
    required this.plantName,
    required this.plantDetails,
    required this.wikiUrl,
    required this.plantImageUrl,
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