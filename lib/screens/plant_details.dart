import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/garden_model.dart';

class PlantDetailScreen extends StatelessWidget {
  final GardenPlant plant;

  const PlantDetailScreen({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(context),
            tooltip: 'Remove from Garden',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FBE7), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Swipe Note
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.swipe, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Swipe right on the plant card in My Garden to remove it',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),

              // Plant Image
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getStatusColor(plant.healthStatus),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: plant.imageUrl.isNotEmpty
                      ? Image.network(
                    plant.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Image loading error: $error');
                      return _buildDetailPlaceholder();
                    },
                  )
                      : _buildDetailPlaceholder(),
                ),
              ),
              const SizedBox(height: 24),

              // Plant Name
              Text(
                plant.plantName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF33691E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Health Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(plant.healthStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(plant.healthStatus)),
                ),
                child: Text(
                  plant.healthStatus.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(plant.healthStatus),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Plant Details Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plant Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF33691E),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Added to garden', _formatDate(plant.addedDate)),
                      _buildInfoRow('Last analysis', _formatDate(plant.lastAnalysisDate)),
                      const SizedBox(height: 12),
                      Text(
                        plant.plantDetails,
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Diseases & Treatment Section - Only show if plant is not healthy AND has diseases
              if (plant.diseases.isNotEmpty && !plant.isHealthy)
                _buildDiseasesSection(),

              // Healthy Plant Message - Show if plant is healthy
              if (plant.isHealthy)
                _buildHealthyPlantMessage(),



              // Inconsistent data case: If plant has diseases but marked as healthy
              if (plant.diseases.isNotEmpty && plant.isHealthy)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          'Previous issues resolved',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Plant is now healthy (last checked: ${_formatDate(plant.lastAnalysisDate)})',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthyPlantMessage() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 50, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Plant is Healthy!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No diseases detected. Your plant is in good condition.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Last checked: ${_formatDate(plant.lastAnalysisDate)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseasesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected Issues',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF33691E),
              ),
            ),
            const SizedBox(height: 16),
            ...plant.diseases.map((disease) => _buildDiseaseInfo(disease)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseInfo(Map<String, dynamic> disease) {
    final name = disease['name'] ?? 'Unknown Disease';
    final probability = disease['probability']?.toDouble() ?? 0.0;
    final description = disease['description'] ?? 'No description available';
    final treatment = disease['treatment'] ?? 'No treatment information available';

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
              const Icon(Icons.warning, size: 20, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  '${(probability * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (description != 'No description available') ...[
            Text(
              'Description: $description',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],
          if (treatment != 'No treatment information available') ...[
            const Text(
              'Treatment:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(treatment),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildDetailPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.eco, size: 50, color: Colors.grey),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'needs attention':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Plant'),
          content: const Text('Are you sure you want to remove this plant from your garden?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _removePlantFromGarden(context);
                Navigator.of(context).pop();
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _removePlantFromGarden(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('garden')
          .doc(plant.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plant removed from garden'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back after a short delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        Navigator.of(context).pop();
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing plant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}