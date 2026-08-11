import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _pageTransitionDuration = Duration(milliseconds: 300);
  static const _pageTransitionCurve = Curves.easeInOut;

  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _locationController = TextEditingController();
  int _currentPage = 0;
  String? _selectedPath;

  @override
  void dispose() {
    _pageController.dispose();
    _farmNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: _pageTransitionDuration,
      curve: _pageTransitionCurve,
    );
  }

  void _goToWelcomeStep() {
    _pageController.animateToPage(
      0,
      duration: _pageTransitionDuration,
      curve: _pageTransitionCurve,
    );
  }

  void _continueFromWelcome() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      _nextPage();
    }
  }

  void _selectPathAndContinue(String path) {
    setState(() => _selectedPath = path);
    _nextPage();
  }

  void _submit() {
    final farmName = sanitizeText(_farmNameController.text);
    final location = sanitizeText(_locationController.text);
    if (farmName.isNotEmpty && location.isNotEmpty) {
      context.read<ProfileBloc>().add(
            UpdateProfileEvent(
              firstName: '',
              lastName: '',
              fiscalYearStartMonth: 1,
              farmName: farmName,
              location: location,
            ),
          );
    } else {
      _goToWelcomeStep();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in your farm name and location'),
        ),
      );
    }
  }

  Widget _buildStep({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileOperationSuccess) {
            context.go(AppRoutePath.home);
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Column(
              children: [
                if (_currentPage > 0)
                  LinearProgressIndicator(
                    value: (_currentPage + 1) / 3,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    children: [
                      _buildWelcomeStep(),
                      _buildPathStep(),
                      _buildCompletionStep(state),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return _buildStep(
      children: [
        Icon(
          Icons.agriculture,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to Neema Farm!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "Let's set up your farm in just a few steps.",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Form(
          key: _formKey,
          child: Column(
            children: [
              ValidatedNameField(
                controller: _farmNameController,
                labelText: 'Farm Name',
                hintText: 'e.g., Green Valley Farm',
                prefixIcon: const Icon(Icons.agriculture),
                validator: (value) =>
                    requiredName(value, fieldLabel: 'Farm name'),
              ),
              const SizedBox(height: 16),
              ValidatedLocationField(
                controller: _locationController,
                labelText: 'Location',
                hintText: 'e.g., Nairobi, Kenya',
                prefixIcon: const Icon(Icons.location_on),
                validator: (value) => requiredLocation(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _continueFromWelcome,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPathStep() {
    return _buildStep(
      children: [
        Text(
          'What would you like to start with?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'You can always add the other later.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildPathCard(
          icon: Icons.eco,
          title: 'Start with Plants',
          subtitle: 'Add land, crops, and manage planting seasons',
          color: Colors.green,
          isSelected: _selectedPath == 'plants',
          onTap: () => _selectPathAndContinue('plants'),
        ),
        const SizedBox(height: 16),
        _buildPathCard(
          icon: Icons.pets,
          title: 'Start with Animals',
          subtitle: 'Register animal types, herds, and track activities',
          color: Colors.orange,
          isSelected: _selectedPath == 'animals',
          onTap: () => _selectPathAndContinue('animals'),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _selectPathAndContinue('none'),
          icon: const Icon(Icons.explore),
          label: const Text("I'll explore on my own"),
        ),
      ],
    );
  }

  Widget _buildPathCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionStep(ProfileState state) {
    return _buildStep(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "You're all set!",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _selectedPath == 'plants'
              ? 'Head to the Plants tab to add your first land and start planting.'
              : _selectedPath == 'animals'
                  ? 'Head to the Animals tab to add animal types and register your herd.'
                  : 'Explore the tabs below to get started with your farm.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your farm "${_farmNameController.text}" in ${_locationController.text} is ready.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: state is ProfileLoading ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: state is ProfileLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  "Let's Go!",
                  style: TextStyle(fontSize: 18),
                ),
        ),
      ],
    );
  }
}
