// models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  postUpvote,
  postComment,
  commentUpvote,
  commentReply,
  plantReminder,
  careTip,
  communityUpdate,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      userId: data['userId'] ?? '',
      type: _parseNotificationType(data['type']),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': _typeToString(type),
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type) {
      case 'postUpvote': return NotificationType.postUpvote;
      case 'postComment': return NotificationType.postComment;
      case 'commentUpvote': return NotificationType.commentUpvote;
      case 'commentReply': return NotificationType.commentReply;
      case 'plantReminder': return NotificationType.plantReminder;
      case 'careTip': return NotificationType.careTip;
      case 'communityUpdate': return NotificationType.communityUpdate;
      default: return NotificationType.communityUpdate;
    }
  }

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.postUpvote: return 'postUpvote';
      case NotificationType.postComment: return 'postComment';
      case NotificationType.commentUpvote: return 'commentUpvote';
      case NotificationType.commentReply: return 'commentReply';
      case NotificationType.plantReminder: return 'plantReminder';
      case NotificationType.careTip: return 'careTip';
      case NotificationType.communityUpdate: return 'communityUpdate';
    }
  }
}