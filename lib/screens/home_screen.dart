import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vision2025/screens/community_screen.dart';
import 'package:vision2025/screens/settings.dart';
import '../../services/auth_service.dart';
import 'care_scheduler.dart';
import 'chat_screen.dart';
import 'my_garden.dart';
import 'notifications_screen.dart';
import 'plant_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // App colors
  final Color primaryColor = const Color(0xFF4CAF50);
  final Color secondaryColor = const Color(0xFF8BC34A);
  final Color backgroundColor = const Color(0xFFF9FBE7);
  final Color textColor = const Color(0xFF33691E);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.getCurrentUser();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Growio', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              Navigator.pushReplacementNamed(context, '/welcome');
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Screens for different navigation items
  final List<Widget> _screens = [
    const HomeContent(),
    const PlantAnalysisScreen(),
    const MyGardenScreen(),
    const CommunityScreen()
  ];

  Widget _buildDrawer(BuildContext context, user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Text(
                    user?.displayName?.substring(0, 1) ?? 'U',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: primaryColor),
            title: const Text('Home'),
            onTap: () {
              setState(() => _currentIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.local_florist, color: primaryColor),
            title: const Text('Plant Library'),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.calendar_today, color: primaryColor),
            title: const Text('Care Schedule'),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.auto_graph, color: primaryColor),
            title: const Text('Growth Tracker'),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: primaryColor),
            title: const Text('Plant FAQs'),
            onTap: () {
              Navigator.pop(context);
              _showFAQsBottomSheet(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.settings, color: primaryColor),
            title: const Text('Settings'),
            onTap: () {
              // Close the drawer first
              Navigator.pop(context);

              // Navigate to SettingsScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );

              // OR if you're using named routes:
              // Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.help, color: primaryColor),
            title: const Text('Help & Support'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showFAQsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FAQsSection(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'Diagnose',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.eco),
          label: 'My Garden',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Community',
        ),
      ],
    );
  }
}

// Home Content Widget
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Color primaryColor = const Color(0xFF4CAF50);
  final Color secondaryColor = const Color(0xFF8BC34A);
  final Color textColor = const Color(0xFF33691E);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.getCurrentUser();
    final userName = user?.displayName ?? 'Plant Lover';
    final greeting = _getGreeting();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Greeting section
          _buildGreetingSection(userName, greeting),
          const SizedBox(height: 20),

          // Plant Health Overview
          _buildHealthOverviewSection(),
          const SizedBox(height: 20),

          // Quick Tools Section
          _buildQuickToolsSection(),
          const SizedBox(height: 20),

          // Read Our Insights Section
          _buildInsightsSection(),
          const SizedBox(height: 20),

          // FAQs Preview Section
          _buildFAQsPreviewSection(context),
        ],
      ),
    );
  }

  Widget _buildGreetingSection(String userName, String greeting) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $userName!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to check on your green friends today? 🌿',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.emoji_nature, color: secondaryColor, size: 40),
        ],
      ),
    );
  }

  Widget _buildHealthOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plant Health Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _auth.currentUser != null
              ? _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('garden')
              .snapshots()
              : Stream<QuerySnapshot>.empty(),
          builder: (context, snapshot) {
            int healthy = 0;
            int needsAttention = 0;
            int total = 0;

            if (snapshot.hasData && !snapshot.hasError) {
              total = snapshot.data!.docs.length;
              healthy = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final healthStatus = data['healthStatus']?.toString().toLowerCase();
                final isHealthy = data['isHealthy'] == true;
                return healthStatus == 'healthy' || isHealthy;
              }).length;
              needsAttention = total - healthy;
            }

            if (_auth.currentUser == null) {
              return _buildLoginPrompt();
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorCard(snapshot.error.toString());
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusCard('Healthy Plants', '$healthy', Icons.check_circle, Colors.green),
                  const SizedBox(width: 12),
                  _buildStatusCard('Needs Attention', '$needsAttention', Icons.warning, Colors.orange),
                  const SizedBox(width: 12),
                  _buildStatusCard('Total Plants', '$total', Icons.eco, primaryColor),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Tools',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildToolCard(
              icon: Icons.camera_alt,
              title: 'Plant Diagnosis',
              subtitle: 'Identify the plant and its diseases instantly',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlantAnalysisScreen()),
                );
              },
            ),

            _buildToolCard(
              icon: Icons.energy_savings_leaf,
              title: 'Green Guide',
              subtitle: 'plant’s guide to grow happy and healthy.',
              color: primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CareScheduleScreen()),
                );
              },
            ),
            _buildToolCard(
              icon: Icons.water_drop,
              title: 'Water Tracker',
              subtitle: 'Monitor hydration',
              color: Colors.blueAccent,
              onTap: () {},
            ),
            _buildToolCard(
              icon: Icons.insights,
              title: 'GrowBot',
              subtitle: 'Disscuss about plant progress',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Read Our Insights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildInsightCard(
          title: 'Seasonal Plant Care Tips',
          description: 'Learn how to prepare your plants for the changing seasons',
          image: '🌦️',
          color: Colors.orange[100]!,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          title: 'Natural Pest Control Methods',
          description: 'Eco-friendly ways to protect your plants from pests',
          image: '🐞',
          color: Colors.green[100]!,
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          title: 'Indoor Plant Lighting Guide',
          description: 'Find the perfect spot for each of your indoor plants',
          image: '💡',
          color: Colors.blue[100]!,
        ),
      ],
    );
  }

  Widget _buildFAQsPreviewSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Plant Care FAQs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton(
              onPressed: () => _showFAQsBottomSheet(context),
              child: Text('View All', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildFAQPreviewItem(
          question: 'How often should I water my plants?',
          onTap: () => _showSingleFAQ(
              context,
              'How often should I water my plants?',
              'Watering frequency depends on plant type, soil, and environment. Most houseplants need watering when the top inch of soil feels dry. Check soil moisture regularly rather than following a fixed schedule.'
          ),
        ),
        _buildFAQPreviewItem(
          question: 'What are signs of overwatering?',
          onTap: () => _showSingleFAQ(
              context,
              'What are signs of overwatering?',
              'Yellowing leaves, wilting despite wet soil, root rot, mold growth, and leaf drop are common signs. Always ensure proper drainage and let soil dry between waterings.'
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String description,
    required String image,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(image, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQPreviewItem({required String question, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        title: Text(question, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.help_outline, size: 18),
        onTap: onTap,
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
            'Login to view your garden stats',
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _navigateToDiagnose(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlantAnalysisScreen()),
    );
  }

  void _showSingleFAQ(BuildContext context, String question, String answer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question),
        content: Text(answer),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFAQsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FAQsSection(),
    );
  }
}

// Enhanced FAQs Section
class FAQsSection extends StatelessWidget {
  FAQsSection({super.key});

  final List<Map<String, String>> faqs = [
    {
      'question': 'How often should I water my plants?',
      'answer': 'Watering frequency depends on plant type, soil, and environment. Most houseplants need watering when the top inch of soil feels dry. Succulents need less water, while tropical plants may need more frequent watering. Always check soil moisture before watering.',
      'category': 'Watering'
    },
    {
      'question': 'What are common signs of plant disease?',
      'answer': 'Common signs include yellowing leaves, brown spots, wilting, stunted growth, white powdery residue, and visible pests. Early detection is key to treating plant diseases effectively. Use our diagnosis tool for accurate identification.',
      'category': 'Health'
    },
    {
      'question': 'How much sunlight do plants need?',
      'answer': 'Light requirements vary by plant. Most flowering plants need 6-8 hours of direct sunlight, while foliage plants can thrive in indirect light. Low-light plants like snake plants and pothos can survive with minimal light.',
      'category': 'Lighting'
    },
    {
      'question': 'When should I repot my plants?',
      'answer': 'Repot when roots are growing through drainage holes, the plant is top-heavy, growth has slowed, or the soil dries out quickly. Spring is generally the best time for repotting most plants.',
      'category': 'Care'
    },
    {
      'question': 'How do I choose the right fertilizer?',
      'answer': 'Choose fertilizer based on your plant type. Most houseplants benefit from balanced fertilizers (10-10-10), while flowering plants may need more phosphorus. Organic options like compost tea are great for sustainable gardening.',
      'category': 'Nutrition'
    },
    {
      'question': 'What are natural pest control methods?',
      'answer': 'Use neem oil, insecticidal soap, or homemade sprays with garlic/chili. Introduce beneficial insects like ladybugs. Maintain plant health to prevent infestations. Regularly inspect plants for early detection.',
      'category': 'Pest Control'
    },
    {
      'question': 'How do I propagate my plants?',
      'answer': 'Propagation methods vary by plant type. Many plants can be propagated through stem cuttings in water or soil. Some plants produce pups or can be divided at the roots. Research the specific method for each plant variety.',
      'category': 'Propagation'
    },
    {
      'question': 'What is the best soil for indoor plants?',
      'answer': 'Use well-draining potting mix specifically formulated for indoor plants. Most houseplants prefer a mix containing peat moss, perlite, and vermiculite. Avoid using garden soil as it may contain pests and doesn\'t drain well in containers.',
      'category': 'Soil'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plant Care FAQs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find answers to common plant care questions',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: faqs.length,
              itemBuilder: (context, index) {
                return _buildFAQItem(
                  question: faqs[index]['question']!,
                  answer: faqs[index]['answer']!,
                  category: faqs[index]['category']!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer, required String category}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _getCategoryColor(category),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            category[0],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Watering': Colors.blue,
      'Health': Colors.green,
      'Lighting': Colors.orange,
      'Care': Colors.purple,
      'Nutrition': Colors.red,
      'Pest Control': Colors.brown,
      'Propagation': Colors.teal,
      'Soil': Colors.blueGrey,
    };
    return colors[category] ?? Colors.grey;
  }
}

// Placeholder Widget for other screens
class PlaceholderWidget extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderWidget({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature is coming soon!',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}