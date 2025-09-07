import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class DiseaseDetectionScreen extends StatefulWidget {
  final VoidCallback onDetectionComplete;

  const DiseaseDetectionScreen({
    super.key,
    required this.onDetectionComplete,
  });

  @override
  State<DiseaseDetectionScreen> createState() => _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> {
  final apiKey = "C0DefI5R2wrQ8rcjp8B4i4iiyz37UWorlRsqBGuGKibECjNdzx";
  XFile? _selectedImage;
  bool _isLoading = false;
  PlantAnalysisResult? _analysisResult;
  String? _errorMessage;

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
          _analysisResult = null;
          _errorMessage = null;
        });
        await _detectDiseases();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick image: ${e.toString()}";
      });
    }
  }

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

      // Make the API call for disease detection
      final response = await http.post(
        Uri.parse("https://plant.id/api/v3/health_assessment"),
        headers: {
          "Content-Type": "application/json",
          "Api-Key": apiKey,
        },
        body: jsonEncode({
          "images": [base64Image],
          "latitude": 49.207,
          "longitude": 16.608,
          "classification_level": "all",
          "similar_images": true
        }),
      );

      debugPrint("Health API Response Status: ${response.statusCode}");
      debugPrint("Health API Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        debugPrint("Health Result: $result");

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
          _errorMessage = "API Error: ${response.statusCode}\n${response.body}";
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = "Error: ${error.toString()}";
        _isLoading = false;
      });
      debugPrint("API Error: $error");
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

        final detailsResponse = await http.get(
          Uri.parse("https://api.plant.id/v3/health_assessment/$identificationId"),
          headers: {
            "Api-Key": apiKey,
          },
        );

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
          }
        } else {
          setState(() {
            _errorMessage = "Failed to get results: ${detailsResponse.statusCode}";
            _isLoading = false;
          });
          return;
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

  void _processHealthResult(dynamic result) {
    setState(() {
      _isLoading = false;

      if (result['result'] == null) {
        _errorMessage = "No health results found. Please try with a clearer image.";
        return;
      }

      // Extract plant name
      String plantName = 'Unknown Plant';

      // Extract health status
      bool isHealthy = result['result']['is_healthy'] != null ?
      result['result']['is_healthy']['binary'] ?? false : false;

      // Extract disease information
      List<DiseaseInfo> diseases = [];
      if (result['result']['disease'] != null &&
          result['result']['disease']['suggestions'] != null) {
        diseases = (result['result']['disease']['suggestions'] as List)
            .map<DiseaseInfo>((d) => DiseaseInfo(
          name: d['name'] ?? 'Unknown Disease',
          probability: d['probability']?.toDouble() ?? 0.0,
          description: d['details'] != null ?
          d['details']['description']?.value ?? d['details']['description'] : null,
          treatment: d['details'] != null && d['details']['treatment'] != null ?
          d['details']['treatment']['prevention']?.join('\n') : null,
        ))
            .toList();
      }

      _analysisResult = PlantAnalysisResult(
        isHealthy: isHealthy,
        plantName: plantName,
        diseases: diseases,
      );

      // Call the completion callback
      widget.onDetectionComplete();
    });
  }

  // Platform-specific image widget
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
        title: const Text('🌿 Disease Detection'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'Upload a photo to detect plant diseases',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose Plant Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                      if (_selectedImage != null) ...[
                        const SizedBox(height: 20),
                        _buildImagePreview(),
                        const SizedBox(height: 10),
                        Text(
                          'Selected: ${_selectedImage!.name}',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                Column(
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Detecting diseases...',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              if (_errorMessage != null)
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              if (_analysisResult != null) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: kIsWeb
                      ? NetworkImage(_selectedImage!.path) as ImageProvider
                      : FileImage(File(_selectedImage!.path)),
                  backgroundColor: Colors.teal.shade200,
                ),
                const SizedBox(width: 16),
                Column(
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
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _analysisResult!.isHealthy
                            ? Colors.green[400]
                            : Colors.red[400],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _analysisResult!.isHealthy ? 'Healthy' : 'Diseased',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _analysisResult!.isHealthy
                ? Column(
              children: [
                Text(
                  'Your plant appears to be healthy! 🌱',
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No diseases detected.',
                  textAlign: TextAlign.center,
                ),
              ],
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_analysisResult!.diseases.isEmpty)
                  const Text('No specific diseases detected.'),
                if (_analysisResult!.diseases.isNotEmpty) ...[
                  Text(
                    'Detected Diseases',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._analysisResult!.diseases
                      .map((disease) => _buildDiseaseInfo(disease)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseInfo(DiseaseInfo disease) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            disease.name,
            style: TextStyle(
              color: Colors.teal.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.yellow[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Probability: ${(disease.probability * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          if (disease.description != null && disease.description!.isNotEmpty) ...[
            Text(
              'Description:',
              style: TextStyle(
                color: Colors.teal.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(disease.description!),
            const SizedBox(height: 10),
          ],
          if (disease.treatment != null && disease.treatment!.isNotEmpty) ...[
            Text(
              'Treatment & Prevention:',
              style: TextStyle(
                color: Colors.teal.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(disease.treatment!),
          ],
          const Divider(),
        ],
      ),
    );
  }
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