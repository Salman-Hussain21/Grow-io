// services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference _userNotificationsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  // Send notification to a user
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final notificationRef = _userNotificationsCollection(userId).doc();
      final notification = AppNotification(
        id: notificationRef.id,
        userId: userId,
        type: type,
        title: title,
        message: message,
        data: data,
        createdAt: DateTime.now(),
      );

      await notificationRef.set(notification.toMap());
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Get user notifications
  Stream<List<AppNotification>> getUserNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _userNotificationsCollection(user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AppNotification.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _userNotificationsCollection(user.uid)
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final notifications = await _userNotificationsCollection(user.uid).get();
    final batch = _firestore.batch();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Get unread count
  Stream<int> getUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _userNotificationsCollection(user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _userNotificationsCollection(user.uid).doc(notificationId).delete();
  }

  // Delete all notifications
  Future<void> deleteAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final notifications = await _userNotificationsCollection(user.uid).get();
    final batch = _firestore.batch();

    for (var doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}