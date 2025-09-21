import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class TermsServicePage extends StatelessWidget {
  const TermsServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF4CAF50);
    final Color backgroundColor = Colors.white;
    final Color textBlack = const Color(0xFF1D1D1D);
    final Color textGrey = const Color(0xFF7A7A7A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
              '1. Acceptance of Terms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'By accessing or using our plant care application, you agree to be bound by these Terms of Service.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
            const SizedBox(height: 24),
            Text(
              '2. User Accounts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'You are responsible for maintaining the confidentiality of your account and password.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
            const SizedBox(height: 24),
            Text(
              '3. User Content',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'You retain all rights to any content you submit, post or display on or through the service.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
            const SizedBox(height: 24),
            Text(
              '4. Termination',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textBlack),
            ),
            const SizedBox(height: 8),
            Text(
              'We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever.',
              style: TextStyle(fontSize: 16, color: textBlack),
            ),
          ],
        ),
      ),
    );
  }
}