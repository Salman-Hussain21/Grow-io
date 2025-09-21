import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'guest_home_screen.dart';
import 'home_screen.dart';
import '../utils/app_colors.dart';
import '../widgets/app_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();

    // Check if user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.getCurrentUser();
      setState(() {
        _isLoggedIn = user != null;
      });
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              ScaleTransition(
                scale: _animation,
                child: Column(
                  children: [
                    // Using the plant icon from the original code
                    Icon(
                      Icons.local_florist,
                      size: 100,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Know Your Plant,\nGrow Your Plant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins', // Added Poppins font
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(_controller),
                  child: Column(
                    children: [
                      if (_isLoggedIn) ...[
                        // Show "Go to Home" button if user is logged in
                        AppButton(
                          text: 'Continue to the app',
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          },
                          isPrimary: true,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              final authService = Provider.of<AuthService>(context, listen: false);
                              await authService.signOut();
                              setState(() {
                                _isLoggedIn = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textGrey,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: AppColors.textGrey.withOpacity(0.5)),
                            ),
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(
                                fontFamily: 'Poppins', // Added Poppins font
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Show sign up/sign in buttons if user is not logged in
                        AppButton(
                          text: 'Login',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          isPrimary: true,
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          text: 'Sign up',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupScreen()),
                            );
                          },
                          isPrimary: false,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          },
                          child: const Text(
                            'Continue as Guest',
                            style: TextStyle(
                              fontFamily: 'Poppins', // Added Poppins font
                              color: AppColors.textGrey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  // Update the login status when the screen is resumed
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context);
    final user = authService.getCurrentUser();
    setState(() {
      _isLoggedIn = user != null;
    });
  }
}