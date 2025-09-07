// screens/care_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/garden_model.dart';
import '../services/perenual_service.dart';
import '../model/garden_model.dart';

class CareScheduleScreen extends StatefulWidget {
  const CareScheduleScreen({super.key});

  @override
  State<CareScheduleScreen> createState() => _CareScheduleScreenState();
}

class _CareScheduleScreenState extends State<CareScheduleScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = const Color(0xFF4CAF50);

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
      appBar: AppBar(
        title: const Text(
            'Green Guide', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
    );
  }

  // ... (Keep all the UI builder methods exactly the same as before)
  // _buildErrorState(), _buildEmptyState(), _buildCareScheduleList(),
  // _buildPlantScheduleCard(), _buildScheduleItem() all remain unchanged

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
          const Icon(Icons.eco, size: 64, color: Colors.grey),
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
            'Plant’s guide to grow happy and healthy',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plantName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Watering Schedule - WITH NULL SAFETY
            _buildScheduleItem(
              icon: Icons.water_drop,
              title: 'Watering',
              subtitle: 'Every ${schedule['watering']?['frequency_days']
                  ?.toString() ?? '7'} days',
              description: schedule['watering']?['description']?.toString() ??
                  'Water when soil is dry',
            ),

            // Light Requirements - WITH NULL SAFETY
            _buildScheduleItem(
              icon: Icons.light_mode,
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
              icon: Icons.eco,
              title: 'Fertilizing',
              subtitle: schedule['fertilizing']?['frequency']?.toString() ??
                  'Every 4-6 weeks',
              description: 'Type: ${schedule['fertilizing']?['type']
                  ?.toString() ?? 'Balanced fertilizer'}',
            ),

            // Pruning - WITH NULL SAFETY
            if (schedule['pruning'] != null)
              _buildScheduleItem(
                icon: Icons.content_cut,
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
          Icon(icon, size: 24, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}