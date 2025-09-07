import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String? userAvatar;
  final String content;
  final List<String> tags;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommunityPost({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.tags = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityPost.fromMap(Map<String, dynamic> data, String id) {
    return CommunityPost(
      id: id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      userAvatar: data['userAvatar'],
      content: data['content'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'tags': tags,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  int get netVotes => upvotes - downvotes;
}