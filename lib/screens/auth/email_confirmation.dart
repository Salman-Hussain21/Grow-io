import 'package:flutter/material.dart';
import '/utils/app_colors.dart';
import '/widgets/app_button.dart';

class ConfirmEmailScreen extends StatelessWidget {
  final String email;

  const ConfirmEmailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.email_outlined,
                size: 50,
                color: AppColors.primaryGreen,
              ),
            ),

            const SizedBox(height: 30),

            // Title
            const Text(
              'Confirm Your Email',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Message
            Text(
              'We\'ve sent a confirmation email to:',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGrey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Email address
            Text(
              email,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Instructions
            Text(
              'Please check your inbox and spam folder. Click the verification link in the email to activate your account.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGrey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Resend button
            AppButton(
              text: 'Resend Email',
              onPressed: () {
                // Add resend email functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Confirmation email resent!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Back to login button
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text(
                'Back to Login',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}