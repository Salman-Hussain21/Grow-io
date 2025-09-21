import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';
import '../model/garden_model.dart';
import '../services/perenual_service.dart';
import '../utils/app_colors.dart';

class GreenGuidePage extends StatefulWidget {
  const GreenGuidePage({super.key});

  @override
  State<GreenGuidePage> createState() => _GreenGuidePageState();
}

class _GreenGuidePageState extends State<GreenGuidePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = AppColors.primaryGreen;

  Map<String, Map<String, dynamic>> _careSchedules = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGardenAndSchedules();
  }

  Future<void> _loadGardenAndSchedules() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not logged in';
      });
      return;
    }

    try {
      print('Loading garden for user: ${user.uid}');

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('garden')
          .get();

      print('Found ${snapshot.docs.length} plants in garden');

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      for (var doc in snapshot.docs) {
        try {
          final plant = GardenPlant.fromFirestore(doc);
          print('Processing plant: ${plant.plantName}');

          Map<String, dynamic> schedule;

          // Try Perenual API first
          try {
            final careInfo = await PerenualService.getPlantCareInfo(
                plant.plantName);
            if (careInfo.isNotEmpty) {
              schedule = PerenualService.extractCareSchedule(careInfo);
              print('Added Perenual schedule for: ${plant.plantName}');
            } else {
              throw Exception('No data from API');
            }
          } catch (e) {
            print('API failed for ${plant.plantName}: $e');
            // Fallback to basic template
            schedule = PerenualService.getBasicCareTemplate(plant.plantName);
            print('Added basic schedule for: ${plant.plantName}');
          }

          _careSchedules[plant.plantName] = schedule;
        } catch (e) {
          print('Error processing plant ${doc.id}: $e');
          // Ultimate fallback
          final schedule = PerenualService.getBasicCareTemplate('tropical');
          _careSchedules[doc.id] = schedule;
        }
      }
    } catch (e) {
      print('Error loading garden: $e');
      setState(() {
        _errorMessage = 'Error loading garden: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Green Guide', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh, color: AppColors.primaryGreen),
            onPressed: _loadGardenAndSchedules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _careSchedules.isEmpty
          ? _buildEmptyState()
          : _buildCareScheduleList(),
      bottomNavigationBar: _buildBottomAppBar(context),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error Loading Garden',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadGardenAndSchedules,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.tree, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Plants in Garden',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add plants to your garden to see their care schedules',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Plants to Garden'),
          ),
        ],
      ),
    );
  }

  Widget _buildCareScheduleList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Plant\'s guide to grow happy and healthy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _careSchedules.entries.map((entry) {
              return _buildPlantScheduleCard(entry.key, entry.value);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlantScheduleCard(String plantName,
      Map<String, dynamic> schedule) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plantName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Watering Schedule - WITH NULL SAFETY
            _buildScheduleItem(
              icon: Iconsax.drop,
              title: 'Watering',
              subtitle: 'Every ${schedule['watering']?['frequency_days']
                  ?.toString() ?? '7'} days',
              description: schedule['watering']?['description']?.toString() ??
                  'Water when soil is dry',
            ),

            // Light Requirements - WITH NULL SAFETY
            _buildScheduleItem(
              icon: Iconsax.sun_1,
              title: 'Light',
              subtitle: schedule['light']?['requirement']?.toString() ??
                  'Bright indirect light',
              description: 'Best: ${schedule['light']?['best_location']
                  ?.toString() ?? 'East or West window'}',
            ),

            // Temperature - WITH NULL SAFETY
            _buildScheduleItem(
              icon: Icons.thermostat,
              title: 'Temperature',
              subtitle: schedule['temperature']?['ideal_range']?.toString() ??
                  '18-27°C',
              description: schedule['temperature']?['protection_required']
                  ?.toString() ?? 'Generally hardy',
            ),

            // Fertilizing - WITH NULL SAFETY
            _buildScheduleItem(
              icon: Icons.thermostat,
              title: 'Fertilizing',
              subtitle: schedule['fertilizing']?['frequency']?.toString() ??
                  'Every 4-6 weeks',
              description: 'Type: ${schedule['fertilizing']?['type']
                  ?.toString() ?? 'Balanced fertilizer'}',
            ),

            // Pruning - WITH NULL SAFETY
            if (schedule['pruning'] != null)
              _buildScheduleItem(
                icon: Iconsax.scissor,
                title: 'Pruning',
                subtitle: schedule['pruning']?['frequency']?.toString() ??
                    'As needed',
                description: 'Best time: ${schedule['pruning']?['best_time']
                    ?.toString() ?? 'Spring'}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textGrey),
                ),
                Text(
                  description,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
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
            _buildNavItem(Iconsax.people, 'Community', false, () {
              Navigator.pushNamed(context, '/community');
            }),
            _buildNavItem(Iconsax.book, 'Guide', true, () {}),
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