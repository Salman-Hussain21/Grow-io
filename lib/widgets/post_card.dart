import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/community_post.dart';
import '../model/vote_type.dart';
import '../model/community_post.dart';
import '../services/community_service.dart';
import '../model/vote_type.dart';
import 'comment_section.dart';
import 'edit_post_dialog.dart';

class PostCard extends StatefulWidget {
  final CommunityPost post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final CommunityService _communityService = CommunityService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  VoteType _userVote = VoteType.none;
  bool _showComments = false;
  bool _isOwnPost = false;

  @override
  void initState() {
    super.initState();
    _loadUserVote();
    _checkOwnership();
  }

  void _checkOwnership() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _isOwnPost = user.uid == widget.post.userId;
      });
    }
  }

  Future<void> _loadUserVote() async {
    final vote = await _communityService.getPostVote(widget.post.id);
    setState(() {
      _userVote = vote;
    });
  }

  Future<void> _handleVote(VoteType voteType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _communityService.votePost(widget.post.id, voteType);
      setState(() {
        _userVote = voteType;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _communityService.deletePost(widget.post.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting post: $e')),
        );
      }
    }
  }

  Future<void> _editPost() async {
    await showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        communityService: _communityService,
        post: widget.post,
        onPostUpdated: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post updated successfully')),
          );
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final canVote = user != null && user.uid != widget.post.userId;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info with menu options
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.post.userAvatar != null
                      ? NetworkImage(widget.post.userAvatar!)
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.post.userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(widget.post.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (_isOwnPost)
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Post'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Post', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') _editPost();
                      if (value == 'delete') _deletePost();
                    },
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            Text(
              widget.post.content,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 12),

            // Tags
            if (widget.post.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: widget.post.tags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    backgroundColor: Colors.green[50],
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

            // Voting and comments
            Row(
              children: [
                // Upvote
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    color: !canVote ? Colors.grey :
                    _userVote == VoteType.upvote ? Colors.green : Colors.grey,
                  ),
                  onPressed: !canVote ? null : () => _handleVote(
                    _userVote == VoteType.upvote ? VoteType.none : VoteType.upvote,
                  ),
                ),
                Text('${widget.post.netVotes}'),

                // Downvote
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    color: !canVote ? Colors.grey :
                    _userVote == VoteType.downvote ? Colors.red : Colors.grey,
                  ),
                  onPressed: !canVote ? null : () => _handleVote(
                    _userVote == VoteType.downvote ? VoteType.none : VoteType.downvote,
                  ),
                ),

                const Spacer(),

                // Comments
                IconButton(
                  icon: Icon(
                    Icons.comment,
                    color: _showComments ? Colors.green : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showComments = !_showComments;
                    });
                  },
                ),
                Text('${widget.post.commentCount}'),
              ],
            ),

            // Comment section
            if (_showComments)
              CommentSection(postId: widget.post.id),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}