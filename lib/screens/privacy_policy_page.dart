import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF4CAF50);
    final Color backgroundColor = Colors.white;
    final Color textBlack = const Color(0xFF1D1D1D);
    final Color textGrey = const Color(0xFF7A7A7A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: textBlack,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: January 2024',
              style: TextStyle(fontSize: 14, color: textGrey),
            ),
            const SizedBox(height: 24),
            Text(
              '1. Information We Collect',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'We collect information you provide directly to us, such as when you create an account or add plant data.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
            const SizedBox(height: 24),
            Text(
              '2. How We Use Your Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'We use your information to provide and improve our services, and to communicate with you.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
            const SizedBox(height: 24),
            Text(
              '3. Information Sharing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'We do not sell, trade, or otherwise transfer your personally identifiable information to outside parties.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
            const SizedBox(height: 24),
            Text(
              '4. Data Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'We implement a variety of security measures to maintain the safety of your personal information.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
          ],
        ),
      ),
    );
  }
}