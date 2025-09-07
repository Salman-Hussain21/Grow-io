// screens/community_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/community_post.dart';
import '../services/community_service.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_dialog.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _communityService = CommunityService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedTag = 'all';
  List<String> _popularTags = ['all', 'plants', 'gardening', 'tips', 'help', 'showcase'];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadPopularTags();
  }

  Future<void> _loadPopularTags() async {
    try {
      final tags = await _communityService.getPopularTags(limit: 10);
      setState(() {
        _popularTags = ['all', ...tags];
        _isLoadingTags = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTags = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreatePostDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTagFilter(),
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: _selectedTag == 'all'
                  ? _communityService.getPosts()
                  : _communityService.getPostsByTag(_selectedTag),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.forum, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _selectedTag == 'all'
                              ? 'No posts yet. Be the first to post!'
                              : 'No posts found for #$_selectedTag',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(post: posts[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilter() {
    if (_isLoadingTags) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _popularTags.length,
        itemBuilder: (context, index) {
          final tag = _popularTags[index];
          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: ChoiceChip(
              label: Text(tag == 'all' ? 'All' : '#$tag'),
              selected: _selectedTag == tag,
              onSelected: (selected) {
                setState(() {
                  _selectedTag = selected ? tag : 'all';
                });
              },
              selectedColor: Colors.green[700],
              labelStyle: TextStyle(
                color: _selectedTag == tag ? Colors.white : Colors.black,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreatePostDialog(
        communityService: _communityService,
        onPostCreated: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully!')),
          );
        },
      ),
    );
  }
}