import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../utils/app_colors.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                CircleAvatar(
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
                  child: const Icon(Iconsax.calendar, color: AppColors.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Event Categories
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildEventCategory('All', true),
                  _buildEventCategory('Workshops', false),
                  _buildEventCategory('Tours', false),
                  _buildEventCategory('Webinars', false),
                  _buildEventCategory('Community', false),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Events List
            _buildEventItem(
              'Plant Propagation Workshop',
              'Learn how to propagate your favorite plants at home',
              'May 15, 2023 • 10:00 AM',
              'Botanical Gardens',
              'assets/images/event1.png', // Add these images to assets/images
            ),
            const SizedBox(height: 16),
            _buildEventItem(
              'Urban Gardening Tour',
              'Visit the best urban gardens in the city',
              'May 22, 2023 • 2:00 PM',
              'Downtown Community Center',
              'assets/images/event2.png',
            ),
            const SizedBox(height: 16),
            _buildEventItem(
              'Indoor Plant Care Webinar',
              'Expert tips for keeping your indoor plants healthy',
              'May 30, 2023 • 6:30 PM',
              'Online Event',
              'assets/images/event3.png',
            ),
            const SizedBox(height: 16),
            _buildEventItem(
              'Community Planting Day',
              'Help plant trees in your local community',
              'June 5, 2023 • 9:00 AM',
              'City Park',
              'assets/images/event4.png',
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAppBar(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Events',
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Iconsax.search_normal, color: AppColors.textBlack),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Iconsax.filter, color: AppColors.textBlack),
          onPressed: () {},
        ),
      ],
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
              Navigator.pop(context);
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
            _buildNavItem(Iconsax.calendar, 'Events', false, () {
              Navigator.pushNamed(context, '/events');
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

  Widget _buildEventCategory(String title, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryGreen : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textBlack,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEventItem(String title, String description, String date, String location, String imagePath) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Event Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textBlack.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Iconsax.calendar, size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textBlack.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Iconsax.location, size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textBlack.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Bookmark Button
          IconButton(
            icon: const Icon(Iconsax.heart, color: AppColors.primaryGreen),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}