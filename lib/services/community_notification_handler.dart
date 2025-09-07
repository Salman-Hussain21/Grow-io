// services/community_notification_handler.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/notification_model.dart';
import './notification_service.dart';
import '../model/community_post.dart';
import '../model/community_comment.dart';

class CommunityNotificationHandler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Listen for post upvotes and send notifications
  void setupPostUpvoteListener() {
    _firestore.collection('community_posts').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final post = CommunityPost.fromMap(change.doc.data() as Map<String, dynamic>, change.doc.id);
          final oldPost = change.doc.data()?.isNotEmpty == true
              ? CommunityPost.fromMap(change.doc.data() as Map<String, dynamic>, change.doc.id)
              : null;

          if (oldPost != null && post.upvotes > oldPost.upvotes) {
            _sendPostUpvoteNotification(post, post.upvotes - oldPost.upvotes);
          }
        }
      }
    });
  }

  Future<void> _sendPostUpvoteNotification(CommunityPost post, int upvoteCount) async {
    if (post.userId == FirebaseAuth.instance.currentUser?.uid) return;

    await _notificationService.sendNotification(
      userId: post.userId,
      type: NotificationType.postUpvote,
      title: 'Your post got upvoted!',
      message: upvoteCount > 1
          ? '$upvoteCount people upvoted your post: "${_truncateText(post.content)}"'
          : 'Someone upvoted your post: "${_truncateText(post.content)}"',
      data: {
        'postId': post.id,
        'upvoteCount': upvoteCount,
      },
    );
  }

  // Listen for new comments and send notifications
  void setupCommentListeners() {
    _firestore.collectionGroup('comments').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final comment = CommunityComment.fromMap(change.doc.data() as Map<String, dynamic>, change.doc.id);
          _handleNewComment(comment);
        }
      }
    });
  }

  Future<void> _handleNewComment(CommunityComment comment) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || comment.userId == currentUser.uid) return;

    // Get the post to notify the post owner
    final postDoc = await _firestore.collection('community_posts').doc(comment.postId).get();
    if (postDoc.exists) {
      final post = CommunityPost.fromMap(postDoc.data() as Map<String, dynamic>, postDoc.id);

      if (comment.parentCommentId == null) {
        // This is a comment on a post
        await _sendPostCommentNotification(post, comment);
      } else {
        // This is a reply to a comment
        await _sendCommentReplyNotification(comment);
      }
    }
  }

  Future<void> _sendPostCommentNotification(CommunityPost post, CommunityComment comment) async {
    await _notificationService.sendNotification(
      userId: post.userId,
      type: NotificationType.postComment,
      title: 'New comment on your post',
      message: '${comment.userName} commented on your post: "${_truncateText(comment.content)}"',
      data: {
        'postId': post.id,
        'commentId': comment.id,
        'commenterName': comment.userName,
      },
    );
  }

  Future<void> _sendCommentReplyNotification(CommunityComment comment) async {
    // Get the parent comment to notify its owner
    final parentCommentDoc = await _firestore
        .collection('community_posts')
        .doc(comment.postId)
        .collection('comments')
        .doc(comment.parentCommentId)
        .get();

    if (parentCommentDoc.exists) {
      final parentComment = CommunityComment.fromMap(
          parentCommentDoc.data() as Map<String, dynamic>,
          parentCommentDoc.id
      );

      await _notificationService.sendNotification(
        userId: parentComment.userId,
        type: NotificationType.commentReply,
        title: 'New reply to your comment',
        message: '${comment.userName} replied to your comment: "${_truncateText(comment.content)}"',
        data: {
          'postId': comment.postId,
          'commentId': comment.id,
          'parentCommentId': comment.parentCommentId,
          'replierName': comment.userName,
        },
      );
    }
  }

  String _truncateText(String text, {int maxLength = 50}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}