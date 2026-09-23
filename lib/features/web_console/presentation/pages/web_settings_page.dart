import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_event.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/auth/data/models/user_storage_model.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_identity.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Appearance and account, which is the whole of what the console can
/// settle on its own — everything else about a farm lives on its own page.
class WebSettingsPage extends StatefulWidget {
  const WebSettingsPage({super.key});

  @override
  State<WebSettingsPage> createState() => _WebSettingsPageState();
}

class _WebSettingsPageState extends State<WebSettingsPage> {
  late final Future<UserStorageModel?> _user = UserStorageService.getUserData();

  @override
  Widget build(BuildContext context) {
    final console = context.console;

    return ConsolePage(
      title: 'Settings',
      subtitle: 'How the console looks, and who you are signed in as.',
      rail: ConsoleRail(
        children: [
          ConsoleCard(
            kicker: 'On your phone',
            color: console.surfaceLow,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone_android, size: 20, color: console.onSurface2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The Android app logs work offline and syncs when there '
                    'is signal. The console is the place to read back what '
                    'was logged.',
                    style: AppTypography.bodyDense.copyWith(
                      color: console.onSurface2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsoleCard(
            title: 'Appearance',
            child: BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, state) {
                return _ThemeChoice(
                  selected: state.themeMode,
                  onChanged: (mode) =>
                      context.read<ThemeBloc>().add(SetThemeModeEvent(mode)),
                );
              },
            ),
          ),
          const SizedBox(height: ConsoleMetrics.gridGap),
          ConsoleCard(
            title: 'Account',
            child: FutureBuilder<UserStorageModel?>(
              future: _user,
              builder: (context, snapshot) {
                final user = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        InitialsAvatar(user?.name ?? '?', size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user?.name.isNotEmpty ?? false
                                    ? user!.name
                                    : 'Signed in',
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (user?.email.isNotEmpty ?? false)
                                Text(
                                  user!.email,
                                  style: AppTypography.bodyDense.copyWith(
                                    color: console.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ConsoleButton.outlined(
                          label: 'Sign out',
                          icon: Icons.logout,
                          onPressed: () =>
                              context.read<AuthBloc>().add(LogoutEvent()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Shamba+ console · version ${AppConfig.appVersion}',
                      style: AppTypography.meta.copyWith(color: console.muted),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (ThemeMode.light, 'Light', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
      (ThemeMode.system, 'Match device', Icons.contrast),
    ];

    return Row(
      children: [
        for (final (mode, label, icon) in options) ...[
          Expanded(
            child: _ThemeOption(
              label: label,
              icon: icon,
              selected: mode == selected,
              onTap: () => onChanged(mode),
            ),
          ),
          if (mode != options.last.$1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;
    final foreground = selected ? scheme.onPrimaryContainer : console.onSurface2;

    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ConsoleMetrics.radiusTile),
            border: Border.all(
              color: selected ? Colors.transparent : console.outline,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 7),
              Text(
                label,
                style: AppTypography.bodyDense.copyWith(
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
