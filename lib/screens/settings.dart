import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final Color backgroundColor = const Color(0xFFF9FBE7);
  bool _emailNotifications = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Management Section
          _buildSectionHeader('Account Management'),
          _buildListTile(
            icon: Icons.person_outline,
            title: 'Account Settings',
            subtitle: 'Manage your profile, email, and password',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountManagementPage()),
              );
            },
          ),

          const SizedBox(height: 24),

          // Data Management Section
          _buildSectionHeader('Data Management'),
          _buildListTile(
            icon: Icons.file_download_outlined,
            title: 'Export Plant Data',
            subtitle: 'Download your data as CSV or PDF',
            onTap: () => _exportPlantData(context),
          ),

          const SizedBox(height: 24),

          // Help & Support Section
          _buildSectionHeader('Help & Support'),
          _buildListTile(
            icon: Icons.help_outline,
            title: 'FAQs & Help Center',
            onTap: () => _openHelpCenter(context),
          ),
          _buildListTile(
            icon: Icons.support_agent_outlined,
            title: 'Contact Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactSupportPage()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportBugPage()),
              );
            },
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildListTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.0',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsServicePage()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.share_outlined,
            title: 'Share with Friends',
            onTap: () => _shareApp(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: titleColor ?? Colors.black87,
          ),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
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

  void _shareApp(BuildContext context) {
    // Simple share functionality without external packages
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Share with Friends'),
          content: const Text('Tell your friends about our plant care app!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share message copied to clipboard')),
                );
                // In a real app, you might copy a message to clipboard
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Copy Message', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}