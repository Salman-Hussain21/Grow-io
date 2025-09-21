import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';

// Import your other pages
import 'account_management_page.dart';
import 'privacy_policy_page.dart';
import 'terms_service_page.dart';
import 'contact_support_page.dart';
import 'report_bug_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color primaryColor = const Color(0xFF4CAF50);
  final Color backgroundColor = Colors.white;
  final Color textBlack = const Color(0xFF1D1D1D);
  final Color textGrey = const Color(0xFF7A7A7A);
  final Color errorColor = const Color(0xFFD32F2F);

  bool _darkMode = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: textBlack,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Section
          _buildProfileSection(),
          const SizedBox(height: 24),

          // Account Settings
          _buildSectionTitle('Account'),
          _buildSettingsItem(
            icon: Iconsax.user,
            title: 'Profile Information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountManagementPage()),
              );
            },
          ),
          _buildSettingsItem(
            icon: Iconsax.shield,
            title: 'Privacy & Security',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          _buildSettingsItem(
            icon: Iconsax.notification,
            title: 'Notifications',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // App Settings
          _buildSectionTitle('App'),
          _buildSettingsItem(
            icon: Iconsax.language_circle,
            title: 'Language',
            trailing: const Text('English'),
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Iconsax.moon,
            title: 'Dark Mode',
            trailing: Switch(
              value: _darkMode,
              activeColor: primaryColor,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
              },
            ),
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Iconsax.data,
            title: 'Data Usage',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // Support
          _buildSectionTitle('Support'),
          _buildSettingsItem(
            icon: Iconsax.message_question,
            title: 'Help Center',
            onTap: () => _openHelpCenter(context),
          ),
          _buildSettingsItem(
            icon: Iconsax.info_circle,
            title: 'About Growio',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Iconsax.document,
            title: 'Terms of Service',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsServicePage()),
              );
            },
          ),
          _buildSettingsItem(
            icon: Iconsax.lock,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          const SizedBox(height: 24),

          // Actions
          _buildSectionTitle('Actions'),
          _buildSettingsItem(
            icon: Iconsax.export,
            title: 'Export Data',
            onTap: () => _exportPlantData(context),
          ),
          _buildSettingsItem(
            icon: Iconsax.logout,
            title: 'Log Out',
            titleColor: errorColor,
            onTap: () => _logout(context),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAppBar(context),
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
            _buildNavItem(Iconsax.home, 'Home', false, () {
              Navigator.pushNamed(context, '/home');
            }),
            _buildNavItem(Iconsax.tree, 'Garden', false, () {
              Navigator.pushNamed(context, '/my_garden');
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
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor,
                        const Color(0xFF2E8B57),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
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
            _buildNavItem(Iconsax.people, 'Community', false, () {
              Navigator.pushNamed(context, '/community');
            }),
            _buildNavItem(Iconsax.setting_2, 'Settings', true, () {
              Navigator.pushNamed(context, '/settings');
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
            color: isActive ? primaryColor : textBlack.withOpacity(0.5),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? primaryColor : textBlack.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? 'User Name';
    final email = user?.email ?? 'user@example.com';

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundImage: const AssetImage('assets/images/user_avatar.png'),
          backgroundColor: Colors.grey[300],
          child: user?.photoURL != null
              ? ClipOval(
            child: Image.network(
              user!.photoURL!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(
                  fontSize: 14,
                  color: textBlack.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Iconsax.edit_2, color: primaryColor),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountManagementPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textGrey,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color titleColor = Colors.black,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: primaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: titleColor,
        ),
      ),
      trailing: trailing ?? Icon(Iconsax.arrow_right_3, size: 20, color: textGrey),
      onTap: onTap,
    );
  }

  // Fixed Plant Data Export Function
  Future<void> _exportPlantData(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to export data')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Plant Data'),
          content: const Text('Choose your preferred format for exporting your plant data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _generateCSVExport(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('CSV', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _generatePDFExport(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('PDF', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateCSVExport(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user's plants from Firestore
      final plantsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .get();

      if (plantsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No plant data to export')),
        );
        return;
      }

      // Generate CSV content
      String csvContent = 'Name,Type,Watering Schedule,Last Watered,Health Status\n';

      for (var doc in plantsSnapshot.docs) {
        final plant = doc.data();
        csvContent += '"${plant['name'] ?? 'Unknown'}",'
            '"${plant['type'] ?? 'Unknown'}",'
            '"${plant['wateringSchedule'] ?? 'Unknown'}",'
            '"${plant['lastWatered'] ?? 'Never'}",'
            '"${plant['healthStatus'] ?? 'Unknown'}",\n';
      }

      // In a real app, you would save this to a file and share it
      // For now, we'll just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV export ready with ${plantsSnapshot.docs.length} plants'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );

      // Here you would typically use a package like share_plus to share the file
      // But since we removed it, we'll just show a dialog with the data
      _showExportDataDialog(context, csvContent, 'CSV');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting data: $e')),
      );
    }
  }

  Future<void> _generatePDFExport(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user's plants from Firestore
      final plantsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .get();

      if (plantsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No plant data to export')),
        );
        return;
      }

      // Generate simple text content (in a real app, you'd use a PDF generation library)
      String pdfContent = 'Plant Care Report\n\n';
      pdfContent += 'Generated on: ${DateTime.now().toString()}\n\n';

      for (var doc in plantsSnapshot.docs) {
        final plant = doc.data();
        pdfContent += 'Plant: ${plant['name'] ?? 'Unknown'}\n';
        pdfContent += 'Type: ${plant['type'] ?? 'Unknown'}\n';
        pdfContent += 'Watering: ${plant['wateringSchedule'] ?? 'Unknown'}\n';
        pdfContent += 'Last Watered: ${plant['lastWatered'] ?? 'Never'}\n';
        pdfContent += 'Health: ${plant['healthStatus'] ?? 'Unknown'}\n\n';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export ready with ${plantsSnapshot.docs.length} plants'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );

      // Show the exported data
      _showExportDataDialog(context, pdfContent, 'PDF');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting data: $e')),
      );
    }
  }

  void _showExportDataDialog(BuildContext context, String data, String format) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$format Export Data'),
          content: SingleChildScrollView(
            child: Text(data),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openHelpCenter(BuildContext context) {
    // In a real app, this would open a webview or external URL
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('FAQs & Help Center'),
          content: const SingleChildScrollView(
            child: Text(
              'Frequently Asked Questions:\n\n'
                  '1. How often should I water my plants?\n'
                  '   - It depends on the plant type and environment.\n\n'
                  '2. Why are my plant\'s leaves turning yellow?\n'
                  '   - This could be due to overwatering or nutrient deficiency.\n\n'
                  '3. How do I add a new plant?\n'
                  '   - Go to the Plants tab and tap the + button.\n\n'
                  'For more help, please contact support.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      // Navigate to login screen or home screen as needed
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}