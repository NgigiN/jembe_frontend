import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:farm_tracker/core/theme/bloc/theme_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _locationController = TextEditingController();
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _pictureUrl = '';

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(FetchProfileEvent());
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _populateFields(ProfileLoaded state) {
    if (_farmNameController.text != state.user.farmName) {
      _farmNameController.text = state.user.farmName;
    }
    if (_locationController.text != state.user.location) {
      _locationController.text = state.user.location;
    }
    _firstName = state.user.firstName;
    _lastName = state.user.lastName;
    _email = state.user.email;
    _pictureUrl = state.user.pictureUrl;
  }

  void _onSaveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProfileBloc>().add(
        UpdateProfileEvent(
          firstName: _firstName,
          lastName: _lastName,
          farmName: _farmNameController.text,
          location: _locationController.text,
        ),
      );
    }
  }

  void _onLogout() {
    context.read<AuthBloc>().add(LogoutEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _onLogout,
          ),
        ],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            context.read<ProfileBloc>().add(FetchProfileEvent());
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, profileState) {
          if (profileState is ProfileLoaded) {
            _populateFields(profileState);
          }

          return BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3),
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_pictureUrl.isNotEmpty) ...[
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(_pictureUrl),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            _firstName.isNotEmpty ? _firstName[0] : 'U',
                            style: TextStyle(
                              fontSize: 40,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildSettingsCard(
                      context,
                      title: 'Appearance',
                      child: ListTile(
                        leading: Icon(
                          themeState.isDarkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          'Dark Mode',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          'Toggle application brightness',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Switch(
                          value: themeState.isDarkMode,
                          onChanged: (value) {
                            context.read<ThemeBloc>().add(ToggleThemeEvent());
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsCard(
                      context,
                      title: 'Profile Information',
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                initialValue: _email,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  filled: true,
                                ),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _firstName,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'First Name',
                                        filled: true,
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _lastName,
                                      readOnly: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Last Name',
                                        filled: true,
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _farmNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Farm Name',
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Required'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Required'
                                        : null,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: profileState is ProfileLoading
                                    ? null
                                    : _onSaveProfile,
                                icon: profileState is ProfileLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                  profileState is ProfileLoading
                                      ? 'Saving...'
                                      : 'Save Profile',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(elevation: 2, clipBehavior: Clip.antiAlias, child: child),
      ],
    );
  }
}
