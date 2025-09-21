import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../utils/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'plant_analysis_screen.dart' hide AppColors;
import 'my_garden.dart';
import 'community_screen.dart';
import 'settings.dart';
import 'notifications_screen.dart';
import 'chat_screen.dart';
import 'care_scheduler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.getCurrentUser();
    final userName = user?.displayName ?? 'Plant Lover';

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hello, $userName',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                CircleAvatar(
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
                  child: const Icon(Iconsax.user, color: AppColors.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scan Plant Card
            _buildScanCard(context),
            const SizedBox(height: 24),

            // Feature Grid
            _buildFeatureGrid(context),
            const SizedBox(height: 24),

            // Recent Scans
// Quick Tips Section
            const Text(
              'Quick Plant Care Tips',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickTipsSection(),
            const SizedBox(height: 24),

            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ),
            const SizedBox(height: 16),
            _buildFAQSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAppBar(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Growio',
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Iconsax.setting, color: AppColors.textBlack),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Iconsax.notification, color: AppColors.textBlack),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomAppBar(BuildContext context) {
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
            _buildNavItem(Iconsax.home, 'Home', _currentIndex == 0, () {
              setState(() => _currentIndex = 0);
            }),
            _buildNavItem(Iconsax.tree, 'Garden', _currentIndex == 2, () {
              setState(() => _currentIndex = 2);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyGardenScreen()),
              );
            }),
            // Diagnose Button (Center)
            Container(
              margin: const EdgeInsets.only(bottom: 25),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlantAnalysisScreen()),
                  );
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
            _buildNavItem(Iconsax.people, 'Community', _currentIndex == 3, () {
              setState(() => _currentIndex = 3);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CommunityScreen(currentTabIndex: 0,)),
              );
            }),
            _buildNavItem(Iconsax.calendar, 'Events', false, () {
              Navigator.pushNamed(context, '/events');
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

  Widget _buildFAQSection() {
    final List<Map<String, String>> faqs = [
      {
        'question': 'How often should I water my plants?',
        'answer': 'It depends on the plant type, but most plants prefer when the top inch of soil is dry before watering.'
      },
      {
        'question': 'What is the best lighting for indoor plants?',
        'answer': 'Most plants thrive in bright, indirect sunlight. South or east-facing windows are usually ideal.'
      },
      {
        'question': 'How do I identify plant diseases?',
        'answer': 'Look for signs like yellowing leaves, spots, or wilting. Use our diagnose feature to get more accurate identification.'
      },
      {
        'question': 'Can I grow vegetables indoors?',
        'answer': 'Yes! Many vegetables like herbs, lettuce, and peppers can be grown indoors with proper lighting and care.'
      },
    ];

    return Column(
      children: faqs.map((faq) {
        return _buildFAQItem(faq['question']!, faq['answer']!);
      }).toList(),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textBlack,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textBlack.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlantAnalysisScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: const Column(
          children: [
            Icon(Iconsax.camera, size: 48, color: AppColors.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Scan Plant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildFeatureCard(
          context,
          icon: Iconsax.tree,
          label: 'My Garden',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyGardenScreen()),
            );
          },
        ),
        _buildFeatureCard(
          context,
          icon: Iconsax.message_text,
          label: 'Community',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CommunityScreen(currentTabIndex: 0,)),
            );
          },
        ),
        _buildFeatureCard(
          context,
          icon: Icons.energy_savings_leaf_outlined,
          label: 'Green guide',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GreenGuidePage()),
            );
          },
        ),
        _buildFeatureCard(
          context,
          icon: Iconsax.message_question,
          label: 'Chatbot',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.primaryGreen),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTipsSection() {
    final List<Map<String, dynamic>> quickTips = [
      {
        'icon': Iconsax.drop,
        'title': 'Watering Tip',
        'tip': 'Water plants in the morning to prevent fungal diseases',
        'color': Colors.blue.shade100,
      },
      {
        'icon': Iconsax.sun_1,
        'title': 'Light Tip',
        'tip': 'Rotate plants weekly for even light exposure',
        'color': Colors.orange.shade100,
      },
      {
        'icon': Icons.energy_savings_leaf_outlined,
        'title': 'Fertilizing Tip',
        'tip': 'Fertilize during growing season (spring/summer)',
        'color': Colors.green.shade100,
      },
      {
        'icon': Iconsax.wind,
        'title': 'Humidity Tip',
        'tip': 'Group plants together to increase humidity',
        'color': Colors.purple.shade100,
      },
      {
        'icon': Iconsax.health,
        'title': 'Health Tip',
        'tip': 'Check leaves regularly for pests and diseases',
        'color': Colors.red.shade100,
      },
      {
        'icon': Iconsax.calendar,
        'title': 'Seasonal Tip',
        'tip': 'Reduce watering in winter when plants are dormant',
        'color': Colors.teal.shade100,
      },
    ];

    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: quickTips.map((tip) {
          return _buildQuickTipCard(
            tip['icon'] as IconData,
            tip['title'] as String,
            tip['tip'] as String,
            tip['color'] as Color,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickTipCard(IconData icon, String title, String tip, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppColors.primaryGreen),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tip,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textBlack.withOpacity(0.7),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  Widget _buildLoginPrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.person, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Login to view your scan history',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}