import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/utils/responsive_utils.dart';

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
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.surface
            ],
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
      padding: EdgeInsets.all(context.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plant Management',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your crops, seasons, and plant-related activities',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: context.paddingLarge),
          Expanded(
            child: GridView.count(
              crossAxisCount: context.screenWidth > 600 ? 3 : 2,
              crossAxisSpacing: context.paddingMedium,
              mainAxisSpacing: context.paddingMedium,
              children: [
                _buildCard(
                  context,
                  'Add Land',
                  Icons.landscape,
                  Colors.blue.shade100,
                  Colors.blue.shade700,
                  () => context.push(AppRoutePath.lands),
                ),
                _buildCard(
                  context,
                  'Add Plant',
                  Icons.eco,
                  Colors.green.shade100,
                  Colors.green.shade700,
                  () => context.push(AppRoutePath.plants),
                ),
                _buildCard(
                  context,
                  'Add Season',
                  Icons.calendar_today,
                  Colors.orange.shade100,
                  Colors.orange.shade700,
                  () => context.push(AppRoutePath.seasons),
                ),
                _buildCard(
                  context,
                  'Add Inputs',
                  Icons.input,
                  Colors.purple.shade100,
                  Colors.purple.shade700,
                  () => context.push(AppRoutePath.inputsFor('plant')),
                ),
                _buildCard(
                  context,
                  'Add Activities',
                  Icons.work,
                  Colors.red.shade100,
                  Colors.red.shade700,
                  () => context.push(AppRoutePath.activitiesFor('plant')),
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
      padding: EdgeInsets.all(context.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Animal Management',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your herds, animals, and animal-related activities',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: context.paddingLarge),
          Expanded(
            child: GridView.count(
              crossAxisCount: context.screenWidth > 600 ? 3 : 2,
              crossAxisSpacing: context.paddingMedium,
              mainAxisSpacing: context.paddingMedium,
              children: [
                _buildCard(
                  context,
                  'Animal Types',
                  Icons.category,
                  Colors.blue.shade100,
                  Colors.blue.shade700,
                  () => context.push(AppRoutePath.animalTypes),
                ),
                _buildCard(
                  context,
                  'Register Herd',
                  Icons.pets,
                  Colors.orange.shade100,
                  Colors.orange.shade700,
                  () => context.push(AppRoutePath.herds),
                ),
                _buildCard(
                  context,
                  'Add Inputs',
                  Icons.input,
                  Colors.purple.shade100,
                  Colors.purple.shade700,
                  () => context.push(AppRoutePath.inputsFor('animal')),
                ),
                _buildCard(
                  context,
                  'Add Activities',
                  Icons.work,
                  Colors.red.shade100,
                  Colors.red.shade700,
                  () => context.push(AppRoutePath.activitiesFor('animal')),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(context.paddingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgroundColor.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 1.0),
                backgroundColor.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.7),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(context.paddingSmall),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: context.fontSize(32), color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
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
