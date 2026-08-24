import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/features/profile/presentation/widgets/typed_delete_account_dialog.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
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
  int _fiscalYearStartMonth = 1;

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
    _fiscalYearStartMonth = state.user.fiscalYearStartMonth;
  }

  void _onSaveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProfileBloc>().add(
        UpdateProfileEvent(
          firstName: _firstName,
          lastName: _lastName,
          fiscalYearStartMonth: _fiscalYearStartMonth,
          farmName: sanitizeText(_farmNameController.text),
          location: sanitizeText(_locationController.text),
        ),
      );
    }
  }

  void _onLogout() {
    context.read<AuthBloc>().add(LogoutEvent());
  }

  Future<void> _onDeleteAccount() async {
    final confirmed = await TypedDeleteAccountDialog.show(
      context: context,
      title: 'Delete Account',
      message:
          'This permanently deletes your account and all farm data '
          '(harvests, land, animals, revenue, costs). This cannot be undone.',
    );
    if (confirmed ?? false) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(DeleteAccountEvent());
    }
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
              AppSnackBar.success(state.message),
            );
            context.read<ProfileBloc>().add(FetchProfileEvent());
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          } else if (state is AccountDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success('Account deleted'),
            );
            context.read<AuthBloc>().add(LogoutEvent());
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
                                key: ValueKey('email_$_email'),
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
                                      key: ValueKey('first_name_$_firstName'),
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
                                      key: ValueKey('last_name_$_lastName'),
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
                              ValidatedNameField(
                                controller: _farmNameController,
                                labelText: 'Farm Name',
                                validator: (value) =>
                                    requiredName(value, fieldLabel: 'Farm name'),
                              ),
                              const SizedBox(height: 16),
                              ValidatedLocationField(
                                controller: _locationController,
                                labelText: 'Location',
                                validator: (value) => requiredLocation(value),
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
                    const SizedBox(height: 24),
                    _buildSettingsCard(
                      context,
                      title: 'Farm Year',
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<int>(
                          initialValue: _fiscalYearStartMonth,
                          decoration: const InputDecoration(
                            labelText: 'Our farm year starts in',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('January')),
                            DropdownMenuItem(value: 2, child: Text('February')),
                            DropdownMenuItem(value: 3, child: Text('March')),
                            DropdownMenuItem(value: 4, child: Text('April')),
                            DropdownMenuItem(value: 5, child: Text('May')),
                            DropdownMenuItem(value: 6, child: Text('June')),
                            DropdownMenuItem(value: 7, child: Text('July')),
                            DropdownMenuItem(value: 8, child: Text('August')),
                            DropdownMenuItem(value: 9, child: Text('September')),
                            DropdownMenuItem(value: 10, child: Text('October')),
                            DropdownMenuItem(value: 11, child: Text('November')),
                            DropdownMenuItem(value: 12, child: Text('December')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _fiscalYearStartMonth = value);
                            context.read<ProfileBloc>().add(
                              UpdateProfileEvent(
                                firstName: _firstName,
                                lastName: _lastName,
                                fiscalYearStartMonth: value,
                                farmName: sanitizeText(_farmNameController.text),
                                location: sanitizeText(_locationController.text),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsCard(
                      context,
                      title: 'Resources',
                      child: ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text('Browse Farming Tips'),
                        subtitle: const Text(
                          'Guides for your crops and animals',
                        ),
                        onTap: () => context.push(AppRoutePath.contentTips),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsCard(
                      context,
                      title: 'Help',
                      child: ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('Ask Us a Question'),
                        subtitle: const Text(
                          'Get help directly from the Jembe team',
                        ),
                        onTap: () => context.push(AppRoutePath.askQuestion),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsCard(
                      context,
                      title: 'Danger Zone',
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(color: Colors.red),
                        ),
                        subtitle: const Text(
                          'Permanently delete your account and all farm data',
                        ),
                        onTap: profileState is ProfileLoading
                            ? null
                            : _onDeleteAccount,
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
