import 'package:cloud_firestore/cloud_firestore.dart';

class GardenPlant {
  final String id;
  final String plantName;
  final String plantDetails;
  final String imageUrl;
  final String healthStatus;
  final Timestamp addedDate;
  final Timestamp lastAnalysisDate;
  final List<Map<String, dynamic>> diseases;
  final bool isHealthy; // Add this

  GardenPlant({
    required this.id,
    required this.plantName,
    required this.plantDetails,
    required this.imageUrl,
    required this.healthStatus,
    required this.addedDate,
    required this.lastAnalysisDate,
    required this.diseases,
    required this.isHealthy, // Add this
  });

  factory GardenPlant.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // ✅ Handle missing isHealthy field by checking healthStatus
    bool isHealthy;
    if (data['isHealthy'] != null) {
      isHealthy = data['isHealthy'];
    } else {
      // Fallback: if isHealthy field is missing, check healthStatus string
      isHealthy = (data['healthStatus']?.toString().toLowerCase() == 'healthy');
    }

    return GardenPlant(
      id: doc.id,
      plantName: data['plantName'] ?? 'Unknown Plant',
      plantDetails: data['plantDetails'] ?? 'No details available',
      imageUrl: data['imageUrl'] ?? '',
      healthStatus: data['healthStatus'] ?? 'Unknown',
      addedDate: data['addedDate'] ?? Timestamp.now(),
      lastAnalysisDate: data['lastAnalysisDate'] ?? Timestamp.now(),
      diseases: (data['diseases'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      isHealthy: isHealthy, // ✅ Use the calculated value
    );
  }
}