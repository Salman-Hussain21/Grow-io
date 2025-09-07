// services/plant_reminder_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/notification_model.dart';
import './notification_service.dart';

class PlantReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Send random plant care notifications
  Future<void> sendRandomPlantReminders() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get user's plants
    final plantsSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('garden')
        .get();

    if (plantsSnapshot.docs.isNotEmpty) {
      final randomPlant = plantsSnapshot.docs[DateTime.now().second % plantsSnapshot.docs.length];
      final plantData = randomPlant.data();

      final messages = [
        'Did you water your ${plantData['name']} today? 💧',
        'How\'s your ${plantData['name']} doing? 🌿',
        'Time to check on ${plantData['name']}! 🌱',
        'Your ${plantData['name']} might need some attention today! 🌸',
        'Don\'t forget to care for ${plantData['name']}! 🍃',
      ];

      final randomMessage = messages[DateTime.now().minute % messages.length];

      await _notificationService.sendNotification(
        userId: user.uid,
        type: NotificationType.plantReminder,
        title: 'Plant Reminder',
        message: randomMessage,
        data: {
          'plantId': randomPlant.id,
          'plantName': plantData['name'],
        },
      );
    }
  }

  // Send care tips
  Future<void> sendCareTips() async {
    final user = _auth.currentUser;
    if (user == null) return;

    const careTips = [
      'Pro tip: Most plants prefer morning watering! ☀️',
      'Did you know? Talking to plants helps them grow! 🗣️',
      'Tip: Rotate your plants regularly for even growth! 🔄',
      'Remember: Overwatering is worse than underwatering! 💦',
      'Pro tip: Use room temperature water for your plants! 🌡️',
    ];

    final randomTip = careTips[DateTime.now().hour % careTips.length];

    await _notificationService.sendNotification(
      userId: user.uid,
      type: NotificationType.careTip,
      title: 'Plant Care Tip',
      message: randomTip,
      data: {'tipType': 'general'},
    );
  }
}