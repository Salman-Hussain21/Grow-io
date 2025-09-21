// screens/community_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';
import '../model/community_post.dart';
import '../services/community_service.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_dialog.dart';
import '../utils/app_colors.dart';

class CommunityScreen extends StatefulWidget {
  final int currentTabIndex;

  const CommunityScreen({super.key, required this.currentTabIndex});

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
      ),
      floatingActionButton: user != null
          ? FloatingActionButton(
        onPressed: () => _showCreatePostDialog(context),
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Iconsax.add, color: AppColors.white),
      )
          : null,
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
                    padding: const EdgeInsets.all(16),
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
      bottomNavigationBar: _buildBottomAppBar(context, widget.currentTabIndex),
    );
  }

  Widget _buildTagFilter() {
    if (_isLoadingTags) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _popularTags.length,
          itemBuilder: (context, index) {
            final tag = _popularTags[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(tag == 'all' ? 'All' : '#$tag'),
                selected: _selectedTag == tag,
                onSelected: (selected) {
                  setState(() {
                    _selectedTag = selected ? tag : 'all';
                  });
                },
                selectedColor: AppColors.primaryGreen,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _selectedTag == tag ? Colors.white : AppColors.textBlack,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          },
        ),
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

  Widget _buildBottomAppBar(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.white,
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Iconsax.home, 'Home', currentIndex == 0, () {
              if (currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            }),
            _buildNavItem(Iconsax.tree, 'Garden', currentIndex == 1, () {
              if (currentIndex != 1) {
                Navigator.pushReplacementNamed(context, '/my_garden');
              }
            }),
            // Diagnose Button (Center)
            Container(
              margin: const EdgeInsets.only(bottom: 25),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/scan_result');
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryGreen,
                        Color(0xFF2E8B57),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Iconsax.scan_barcode,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            _buildNavItem(Iconsax.people, 'Community', currentIndex == 2, () {
              if (currentIndex != 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CommunityScreen(currentTabIndex: 0,)),
                );
              }
            }),
            _buildNavItem(Iconsax.calendar, 'Events', currentIndex == 3, () {
              if (currentIndex != 3) {
                Navigator.pushNamed(context, '/events');
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primaryGreen : AppColors.textBlack.withOpacity(0.5),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.primaryGreen : AppColors.textBlack.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}