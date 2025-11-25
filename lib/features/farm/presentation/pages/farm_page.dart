import 'package:flutter/material.dart';
import 'land_page.dart';
import 'plant_page.dart';
import 'season_page.dart';
import 'input_page.dart';
import 'activity_page.dart';
import 'herd_page.dart';
import 'animal_type_page.dart';

class FarmPage extends StatefulWidget {
  const FarmPage({super.key});

  @override
  State<FarmPage> createState() => _FarmPageState();
}

class _FarmPageState extends State<FarmPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabAlignment: TabAlignment.center,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.eco), text: 'Plants'),
            Tab(icon: Icon(Icons.pets), text: 'Animals'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [_buildPlantsTab(context), _buildAnimalsTab(context)],
        ),
      ),
    );
  }

  Widget _buildPlantsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plant Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your crops, seasons, and plant-related activities',
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
                    MaterialPageRoute(builder: (context) => const LandPage()),
                  ),
                ),
                _buildCard(
                  context,
                  'Add Plant',
                  Icons.eco,
                  Colors.green.shade100,
                  Colors.green.shade700,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlantPage()),
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
                    MaterialPageRoute(builder: (context) => const SeasonPage()),
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
                      builder: (context) =>
                          const InputPage(sourceType: 'plant'),
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
                      builder: (context) =>
                          const ActivityPage(sourceType: 'plant'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalsTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Animal Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your herds, animals, and animal-related activities',
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
                  'Animal Types',
                  Icons.category,
                  Colors.blue.shade100,
                  Colors.blue.shade700,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnimalTypePage(),
                    ),
                  ),
                ),
                _buildCard(
                  context,
                  'Register Herd',
                  Icons.pets,
                  Colors.orange.shade100,
                  Colors.orange.shade700,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HerdPage()),
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
                      builder: (context) =>
                          const InputPage(sourceType: 'animal'),
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
                      builder: (context) =>
                          const ActivityPage(sourceType: 'animal'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              colors: [backgroundColor, backgroundColor.withValues(alpha: 0.7)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
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
}
