import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityComment {
  final String id;
  final String postId;
  final String? parentCommentId;
  final String userId;
  final String userEmail;
  final String userName;
  final String? userAvatar;
  final String content;
  final int upvotes;
  final int downvotes;
  final int replyCount;
  final DateTime createdAt;
  final List<String> taggedUsers;

  CommunityComment({
    required this.id,
    required this.postId,
    this.parentCommentId,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.upvotes = 0,
    this.downvotes = 0,
    this.replyCount = 0,
    required this.createdAt,
    this.taggedUsers = const [],
  });

  factory CommunityComment.fromMap(Map<String, dynamic> data, String id) {
    return CommunityComment(
      id: id,
      postId: data['postId'] ?? '',
      parentCommentId: data['parentCommentId'],
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      content: data['content'] ?? '',
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      replyCount: data['replyCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      taggedUsers: List<String>.from(data['taggedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'parentCommentId': parentCommentId,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'replyCount': replyCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'taggedUsers': taggedUsers,
    };
  }

  int get netVotes => upvotes - downvotes;
  bool get isReply => parentCommentId != null;
}