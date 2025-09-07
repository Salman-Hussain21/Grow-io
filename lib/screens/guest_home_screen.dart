import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vision2025/screens/plant_analysis_screen.dart';
import 'package:vision2025/screens/welcome_screen.dart';
import '../services/firestore_service.dart';
import 'auth/login_screen.dart';
import 'disease_detection_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final String guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
  int analysisCount = 0;
  int maxGuestAnalyses = 3;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGuestData();
    });
  }

  Future<void> _loadGuestData() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final count = await firestoreService.getGuestAnalysisCount(guestId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your internet connection.');
        },
      );

      setState(() {
        analysisCount = count;
        isLoading = false;
      });
    } on TimeoutException catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.message ?? 'Request timed out';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _incrementAnalysisCount() async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final newCount = analysisCount + 1;

      await firestoreService.updateGuestAnalysisCount(guestId, newCount);

      setState(() {
        analysisCount = newCount;
      });
    } catch (e) {
      // Silently fail - user can still use the app
      print('Failed to update analysis count: $e');
    }
  }

  void _navigateToPlantAnalysis() {
    if (analysisCount >= maxGuestAnalyses) {
      _showUpgradePrompt();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantAnalysisScreen(
          onAnalysisComplete: _incrementAnalysisCount,
        ),
      ),
    );
  }

  void _navigateToDiseaseDetection() {
    if (analysisCount >= maxGuestAnalyses) {
      _showUpgradePrompt();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiseaseDetectionScreen(
          onDetectionComplete: _incrementAnalysisCount,
        ),
      ),
    );
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limit Reached'),
          content: Text(
            'You\'ve used all $maxGuestAnalyses free analyses. Sign up for unlimited access!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Sign Up'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Growio Guest Mode'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              );
            },
            tooltip: 'Sign In',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading guest data...'),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Loading Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadGuestData,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    hasError = false;
                    isLoading = false;
                  });
                },
                child: const Text('Continue with limited functionality'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guest Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You have ${maxGuestAnalyses - analysisCount} free analyses remaining. Sign up for unlimited access.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Plant Health Features',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildFeatureCard(
                  icon: Icons.eco,
                  title: 'Plant Analysis',
                  subtitle: 'Identify plants & get details',
                  available: analysisCount < maxGuestAnalyses,
                  onTap: _navigateToPlantAnalysis,
                ),
                _buildFeatureCard(
                  icon: Icons.health_and_safety,
                  title: 'Disease Detection',
                  subtitle: 'Detect plant diseases',
                  available: analysisCount < maxGuestAnalyses,
                  onTap: _navigateToDiseaseDetection,
                ),
                _buildFeatureCard(
                  icon: Icons.history,
                  title: 'History',
                  subtitle: 'View your past analyses',
                  available: false,
                  onTap: () {},
                ),
                _buildFeatureCard(
                  icon: Icons.favorite,
                  title: 'Save Plants',
                  subtitle: 'Save your favorite plants',
                  available: false,
                  onTap: () {},
                ),
                _buildFeatureCard(
                  icon: Icons.auto_graph,
                  title: 'Advanced Analytics',
                  subtitle: 'Detailed plant health insights',
                  available: false,
                  onTap: () {},
                ),
                _buildFeatureCard(
                  icon: Icons.cloud_download,
                  title: 'Export Data',
                  subtitle: 'Export your plant data',
                  available: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Sign Up for Full Access'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool available,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 40,
                    color: available ? Colors.teal.shade700 : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: available ? Colors.black : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: available ? Colors.grey : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (!available)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign Up\nTo Access',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}