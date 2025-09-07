// screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../model/notification_model.dart';

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
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          if (user != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
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
          const Icon(Icons.notifications_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Sign in to see notifications',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Navigate to login screen
            },
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
          const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll get notified about upvotes, comments, and plant reminders',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
    return ListTile(
      leading: _getNotificationIcon(),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(notification.message),
      trailing: Text(
        _formatTime(notification.createdAt),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      onTap: onTap,
      tileColor: notification.isRead ? null : Colors.green[50],
    );
  }

  Widget _getNotificationIcon() {
    final icon = switch (notification.type) {
      NotificationType.postUpvote => Icons.thumb_up,
      NotificationType.postComment => Icons.comment,
      NotificationType.commentUpvote => Icons.thumb_up,
      NotificationType.commentReply => Icons.reply,
      NotificationType.plantReminder => Icons.local_florist,
      NotificationType.careTip => Icons.lightbulb_outline,
      NotificationType.communityUpdate => Icons.people,
    };

    final color = switch (notification.type) {
      NotificationType.postUpvote => Colors.blue,
      NotificationType.postComment => Colors.green,
      NotificationType.commentUpvote => Colors.blue,
      NotificationType.commentReply => Colors.orange,
      NotificationType.plantReminder => Colors.green[700],
      NotificationType.careTip => Colors.amber,
      NotificationType.communityUpdate => Colors.purple,
    };

    return CircleAvatar(
      backgroundColor: color?.withOpacity(0.2),
      child: Icon(icon, color: color, size: 20),
    );
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