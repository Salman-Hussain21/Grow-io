import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/community_post.dart';
import '../model/community_comment.dart';
import '../model/vote_type.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _postsCollection => _firestore.collection('community_posts');

  CollectionReference _postCommentsCollection(String postId) =>
      _postsCollection.doc(postId).collection('comments');

  CollectionReference _userPostVotesCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('post_votes');

  CollectionReference _userCommentVotesCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('comment_votes');

  // Post Methods
  Future<CommunityPost> createPost({
    required String content,
    List<String> tags = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postRef = _postsCollection.doc();
    final now = DateTime.now();

    final post = CommunityPost(
      id: postRef.id,
      userId: user.uid,
      userEmail: user.email ?? '',
      userName: user.displayName ?? 'Anonymous',
      userAvatar: user.photoURL,
      content: content,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );

    await postRef.set(post.toMap());

    // Update tag counts
    for (final tag in tags) {
      await _firestore.collection('community_tags').doc(tag).set({
        'count': FieldValue.increment(1),
        'lastUsed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return post;
  }

  Stream<List<CommunityPost>> getPosts({int limit = 20}) {
    return _postsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CommunityPost.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Stream<List<CommunityPost>> getPostsByTag(String tag, {int limit = 20}) {
    if (tag == 'all') {
      return getPosts(limit: limit);
    }

    return _postsCollection
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CommunityPost.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postDoc = await _postsCollection.doc(postId).get();
    if (!postDoc.exists) throw Exception('Post not found');

    final postData = postDoc.data() as Map<String, dynamic>;
    if (postData['userId'] != user.uid) {
      throw Exception('You can only delete your own posts');
    }

    // Delete all comments first
    final commentsSnapshot = await _postCommentsCollection(postId).get();
    for (var doc in commentsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete post
    await _postsCollection.doc(postId).delete();
  }

  Future<void> updatePost(String postId, String content, List<String> tags) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postDoc = await _postsCollection.doc(postId).get();
    if (!postDoc.exists) throw Exception('Post not found');

    final postData = postDoc.data() as Map<String, dynamic>;
    if (postData['userId'] != user.uid) {
      throw Exception('You can only edit your own posts');
    }

    await _postsCollection.doc(postId).update({
      'content': content,
      'tags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

// In community_service.dart - Update votePost method
  Future<void> votePost(String postId, VoteType voteType) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final postDoc = await _postsCollection.doc(postId).get();
    if (!postDoc.exists) throw Exception('Post not found');

    final postData = postDoc.data() as Map<String, dynamic>;
    if (postData['userId'] == user.uid) {
      throw Exception('You cannot vote on your own post');
    }

    final userVoteRef = _userPostVotesCollection(user.uid).doc(postId);
    final userVoteDoc = await userVoteRef.get();
    final  currentVote;
    if (userVoteDoc.exists) {
      currentVote = userVoteDoc.data() != null?['vote'] : null;
    } else {
      currentVote = null;
    }

    await _firestore.runTransaction((transaction) async {
      // Get fresh data
      final freshPostDoc = await transaction.get(_postsCollection.doc(postId));
      final freshPostData = freshPostDoc.data() as Map<String, dynamic>;

      int newUpvotes = freshPostData['upvotes'] ?? 0;
      int newDownvotes = freshPostData['downvotes'] ?? 0;

      if (currentVote == 'upvote') newUpvotes--;
      if (currentVote == 'downvote') newDownvotes--;

      if (voteType == VoteType.upvote) newUpvotes++;
      if (voteType == VoteType.downvote) newDownvotes++;

      transaction.update(_postsCollection.doc(postId), {
        'upvotes': newUpvotes,
        'downvotes': newDownvotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (voteType == VoteType.none) {
        transaction.delete(userVoteRef);
      } else {
        transaction.set(userVoteRef, {
          'vote': voteType == VoteType.upvote ? 'upvote' : 'downvote',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<VoteType> getPostVote(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return VoteType.none;

    final voteDoc = await _userPostVotesCollection(user.uid).doc(postId).get();
    if (!voteDoc.exists) return VoteType.none;

    final vote = voteDoc.data()?['vote'];
    return vote == 'upvote' ? VoteType.upvote : VoteType.downvote;
  }

  // Comment Methods
  Future<CommunityComment> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
    List<String> taggedUsers = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final commentRef = _postCommentsCollection(postId).doc();
    final comment = CommunityComment(
      id: commentRef.id,
      postId: postId,
      parentCommentId: parentCommentId,
      userId: user.uid,
      userEmail: user.email ?? '',
      userName: user.displayName ?? 'Anonymous',
      userAvatar: user.photoURL,
      content: content,
      createdAt: DateTime.now(),
      taggedUsers: taggedUsers,
    );

    await _firestore.runTransaction((transaction) async {
      transaction.set(commentRef, comment.toMap());

      if (parentCommentId == null) {
        transaction.update(_postsCollection.doc(postId), {
          'commentCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(_postCommentsCollection(postId).doc(parentCommentId), {
          'replyCount': FieldValue.increment(1),
        });
      }
    });

    return comment;
  }

  Stream<List<CommunityComment>> getComments(String postId, {String? parentCommentId}) {
    return _postCommentsCollection(postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final allComments = snapshot.docs
          .map((doc) => CommunityComment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Filter locally instead of using Firestore query
      if (parentCommentId == null) {
        return allComments.where((comment) => comment.parentCommentId == null).toList();
      } else {
        return allComments.where((comment) => comment.parentCommentId == parentCommentId).toList();
      }
    });
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final commentDoc = await _postCommentsCollection(postId).doc(commentId).get();
    if (!commentDoc.exists) throw Exception('Comment not found');

    final commentData = commentDoc.data() as Map<String, dynamic>;
    if (commentData['userId'] != user.uid) {
      throw Exception('You can only delete your own comments');
    }

    await _firestore.runTransaction((transaction) async {
      transaction.delete(_postCommentsCollection(postId).doc(commentId));

      if (commentData['parentCommentId'] == null) {
        transaction.update(_postsCollection.doc(postId), {
          'commentCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(_postCommentsCollection(postId).doc(commentData['parentCommentId']), {
          'replyCount': FieldValue.increment(-1),
        });
      }
    });
  }

  Future<void> voteComment(String postId, String commentId, VoteType voteType) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final commentDoc = await _postCommentsCollection(postId).doc(commentId).get();
    if (!commentDoc.exists) throw Exception('Comment not found');

    final commentData = commentDoc.data() as Map<String, dynamic>;
    if (commentData['userId'] == user.uid) {
      throw Exception('You cannot vote on your own comment');
    }

    final userVoteRef = _userCommentVotesCollection(user.uid).doc(commentId);
    final userVoteDoc = await userVoteRef.get();
    final  currentVote;
    if (userVoteDoc.exists) {
      currentVote = userVoteDoc.data() != null?['vote'] : null;
    } else {
      currentVote = null;
    }

    await _firestore.runTransaction((transaction) async {
      int newUpvotes = commentData['upvotes'] ?? 0;
      int newDownvotes = commentData['downvotes'] ?? 0;

      if (currentVote == 'upvote') newUpvotes--;
      if (currentVote == 'downvote') newDownvotes--;

      if (voteType == VoteType.upvote) newUpvotes++;
      if (voteType == VoteType.downvote) newDownvotes++;

      transaction.update(_postCommentsCollection(postId).doc(commentId), {
        'upvotes': newUpvotes,
        'downvotes': newDownvotes,
      });

      if (voteType == VoteType.none) {
        transaction.delete(userVoteRef);
      } else {
        transaction.set(userVoteRef, {
          'vote': voteType == VoteType.upvote ? 'upvote' : 'downvote',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<VoteType> getCommentVote(String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return VoteType.none;

    final voteDoc = await _userCommentVotesCollection(user.uid).doc(commentId).get();
    if (!voteDoc.exists) return VoteType.none;

    final vote = voteDoc.data()?['vote'];
    return vote == 'upvote' ? VoteType.upvote : VoteType.downvote;
  }

  Future<List<String>> getPopularTags({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('community_tags')
        .orderBy('count', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }
}

extension on Object? {
  operator [](String other) {}
}