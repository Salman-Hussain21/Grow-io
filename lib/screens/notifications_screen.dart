// screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';
import '../services/notification_service.dart';
import '../model/notification_model.dart';
import '../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textBlack,
        elevation: 0,
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Iconsax.tick_circle),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          if (user != null)
            IconButton(
              icon: const Icon(Iconsax.trash),
              onPressed: _deleteAllNotifications,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: user == null
          ? _buildNotSignedIn()
          : StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return NotificationTile(
                notification: notifications[index],
                onTap: () => _handleNotificationTap(notifications[index]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotSignedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.notification, size: 64, color: AppColors.textGrey),
          const SizedBox(height: 16),
          const Text(
            'Sign in to see notifications',
            style: TextStyle(fontSize: 18, color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Navigate to login screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.notification, size: 64, color: AppColors.textGrey),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(fontSize: 18, color: AppColors.textGrey),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'You\'ll get notified about upvotes, comments, and plant reminders',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }

    // Handle notification tap based on type
    switch (notification.type) {
      case NotificationType.postUpvote:
      case NotificationType.postComment:
      // Navigate to post
        break;
      case NotificationType.commentUpvote:
      case NotificationType.commentReply:
      // Navigate to comment
        break;
      case NotificationType.plantReminder:
      // Navigate to plant
        break;
      case NotificationType.careTip:
      case NotificationType.communityUpdate:
      // Show dialog or do nothing
        break;
    }
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead();
  }

  void _deleteAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notificationService.deleteAllNotifications();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: notification.isRead ? AppColors.white : AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead ? Colors.transparent : AppColors.primaryGreen.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(notification.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    return switch (type) {
      NotificationType.postUpvote => Iconsax.like_1,
      NotificationType.postComment => Iconsax.message_text,
      NotificationType.commentUpvote => Iconsax.like_1,
      NotificationType.commentReply => Iconsax.message,
      NotificationType.plantReminder => Iconsax.calendar,
      NotificationType.careTip => Iconsax.lamp_charge,
      NotificationType.communityUpdate => Iconsax.people,
    };
  }

  Color _getNotificationColor(NotificationType type) {
    return switch (type) {
      NotificationType.postUpvote => Colors.blue,
      NotificationType.postComment => AppColors.primaryGreen,
      NotificationType.commentUpvote => Colors.blue,
      NotificationType.commentReply => Colors.orange,
      NotificationType.plantReminder => AppColors.primaryGreen,
      NotificationType.careTip => Colors.amber,
      NotificationType.communityUpdate => Colors.purple,
    };
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}