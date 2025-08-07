import 'package:flutter/material.dart';
import 'land_page.dart';
import 'crop_page.dart';
import 'season_page.dart';
import 'input_page.dart';
import 'activity_page.dart';

class FarmPage extends StatelessWidget {
  const FarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Tracker'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Your Farm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your farm activities and track your progress',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildCard(
                      context,
                      'Add Land',
                      Icons.landscape,
                      Colors.blue.shade100,
                      Colors.blue.shade700,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LandPage(),
                        ),
                      ),
                    ),
                    _buildCard(
                      context,
                      'Add Crop',
                      Icons.eco,
                      Colors.green.shade100,
                      Colors.green.shade700,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CropPage(),
                        ),
                      ),
                    ),
                    _buildCard(
                      context,
                      'Add Season',
                      Icons.calendar_today,
                      Colors.orange.shade100,
                      Colors.orange.shade700,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SeasonPage(),
                        ),
                      ),
                    ),
                    _buildCard(
                      context,
                      'Add Inputs',
                      Icons.input,
                      Colors.purple.shade100,
                      Colors.purple.shade700,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InputPage(),
                        ),
                      ),
                    ),
                    _buildCard(
                      context,
                      'Add Activities',
                      Icons.work,
                      Colors.red.shade100,
                      Colors.red.shade700,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ActivityPage(),
                        ),
                      ),
                    ),
                    _buildCard(
                      context,
                      'View All',
                      Icons.list,
                      Colors.grey.shade100,
                      Colors.grey.shade700,
                      () => _showComingSoon(context, 'View All'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundColor, backgroundColor.withOpacity(0.7)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
