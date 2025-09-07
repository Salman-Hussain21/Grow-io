import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add plant analysis to user's history
  Future<void> addPlantAnalysis(Map<String, dynamic> analysisData) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add({
        ...analysisData,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'plant_analysis',
      });
    } catch (e) {
      print("Error adding plant analysis: $e");
    }
  }

  // Add disease detection to user's history
  Future<void> addDiseaseDetection(Map<String, dynamic> detectionData) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add({
        ...detectionData,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'disease_detection',
      });
    } catch (e) {
      print("Error adding disease detection: $e");
    }
  }

  // Get user's history
  Stream<QuerySnapshot> getUserHistory() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get guest analysis count
  Future<int> getGuestAnalysisCount(String guestId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('guest_usage')
          .doc(guestId)
          .get();

      if (doc.exists) {
        return doc['analysis_count'] ?? 0;
      } else {
        await _firestore
            .collection('guest_usage')
            .doc(guestId)
            .set({'analysis_count': 0});
        return 0;
      }
    } catch (e) {
      print("Error getting guest analysis count: $e");
      return 0;
    }
  }

  // Update guest analysis count
  Future<void> updateGuestAnalysisCount(String guestId, int count) async {
    try {
      await _firestore
          .collection('guest_usage')
          .doc(guestId)
          .update({'analysis_count': count});
    } catch (e) {
      print("Error updating guest analysis count: $e");
    }
  }
}