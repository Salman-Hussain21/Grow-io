import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/community_comment.dart';
import '../model/vote_type.dart';
import '../services/community_service.dart';
import '../model/community_comment.dart';
import '../model/vote_type.dart';

class CommentSection extends StatefulWidget {
  final String postId;
  final String? parentCommentId;

  const CommentSection({
    super.key,
    required this.postId,
    this.parentCommentId,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _commentController = TextEditingController();
  final Map<String, bool> _showReplies = {};

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        if (user != null && widget.parentCommentId == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),

        StreamBuilder<List<CommunityComment>>(
          stream: _communityService.getComments(widget.postId, parentCommentId: widget.parentCommentId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            final comments = snapshot.data ?? [];

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return CommentTile(
                  comment: comment,
                  onReply: () => _showReplyDialog(comment),
                  onToggleReplies: () => _toggleReplies(comment.id),
                  showReplies: _showReplies[comment.id] ?? false,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      await _communityService.addComment(
        postId: widget.postId,
        content: content,
        parentCommentId: widget.parentCommentId,
      );
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    }
  }

  void _showReplyDialog(CommunityComment comment) {
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${comment.userName}'),
        content: TextField(
          controller: replyController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write your reply...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = replyController.text.trim();
              if (content.isEmpty) return;

              try {
                await _communityService.addComment(
                  postId: widget.postId,
                  content: content,
                  parentCommentId: comment.id,
                  taggedUsers: [comment.userName],
                );
                Navigator.pop(context);
                setState(() {
                  _showReplies[comment.id] = true;
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding reply: $e')),
                );
              }
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  void _toggleReplies(String commentId) {
    setState(() {
      _showReplies[commentId] = !(_showReplies[commentId] ?? false);
    });
  }
}

class CommentTile extends StatefulWidget {
  final CommunityComment comment;
  final VoidCallback onReply;
  final VoidCallback onToggleReplies;
  final bool showReplies;

  const CommentTile({
    super.key,
    required this.comment,
    required this.onReply,
    required this.onToggleReplies,
    required this.showReplies,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  final CommunityService _communityService = CommunityService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  VoteType _userVote = VoteType.none;
  bool _isOwnComment = false;

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
        _isOwnComment = user.uid == widget.comment.userId;
      });
    }
  }

  Future<void> _loadUserVote() async {
    final vote = await _communityService.getCommentVote(widget.comment.id);
    setState(() {
      _userVote = vote;
    });
  }

  Future<void> _handleVote(VoteType voteType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _communityService.voteComment(
        widget.comment.postId,
        widget.comment.id,
        voteType,
      );
      setState(() {
        _userVote = voteType;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error voting: $e')),
      );
    }
  }

  Future<void> _deleteComment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
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
        await _communityService.deleteComment(widget.comment.postId, widget.comment.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final canVote = user != null && user.uid != widget.comment.userId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.comment.userAvatar != null
                      ? NetworkImage(widget.comment.userAvatar!)
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.comment.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (_isOwnComment)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16),
                    onPressed: _deleteComment,
                    color: Colors.red,
                  ),
                Text(
                  _formatDate(widget.comment.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Content
            Text(widget.comment.content),

            const SizedBox(height: 8),

            // Tagged users
            if (widget.comment.taggedUsers.isNotEmpty)
              Wrap(
                children: [
                  const Text('Replying to: ', style: TextStyle(fontSize: 12)),
                  ...widget.comment.taggedUsers.map((user) => Text(
                    '@$user ',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  )),
                ],
              ),

            const SizedBox(height: 8),

            // Voting and actions
            Row(
              children: [
                // Upvote
                IconButton(
                  icon: Icon(
                    Icons.arrow_upward,
                    size: 18,
                    color: !canVote ? Colors.grey :
                    _userVote == VoteType.upvote ? Colors.green : Colors.grey,
                  ),
                  onPressed: !canVote ? null : () => _handleVote(
                    _userVote == VoteType.upvote ? VoteType.none : VoteType.upvote,
                  ),
                ),
                Text('${widget.comment.netVotes}', style: const TextStyle(fontSize: 12)),

                // Downvote
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    size: 18,
                    color: !canVote ? Colors.grey :
                    _userVote == VoteType.downvote ? Colors.red : Colors.grey,
                  ),
                  onPressed: !canVote ? null : () => _handleVote(
                    _userVote == VoteType.downvote ? VoteType.none : VoteType.downvote,
                  ),
                ),

                if (!widget.comment.isReply)
                  TextButton(
                    onPressed: widget.onReply,
                    child: const Text('Reply', style: TextStyle(fontSize: 12)),
                  ),

                if (!widget.comment.isReply && widget.comment.replyCount > 0)
                  TextButton(
                    onPressed: widget.onToggleReplies,
                    child: Text(
                      '${widget.showReplies ? 'Hide' : 'Show'} ${widget.comment.replyCount} ${widget.comment.replyCount == 1 ? 'reply' : 'replies'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),

            // Replies
            if (widget.showReplies && !widget.comment.isReply)
              CommentSection(
                postId: widget.comment.postId,
                parentCommentId: widget.comment.id,
              ),
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