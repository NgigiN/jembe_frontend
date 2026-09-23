import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:flutter/material.dart';

/// Which weight the button carries in the header row.
enum LogButton { tonal, filled }

/// A "Log …" header action.
///
/// The mockups put three of these on the Dashboard, and the console has no
/// entry forms — logging happens in the Android app, offline, in the field,
/// which is the whole reason the app exists. Rather than drop the buttons
/// (and the header's shape with them) or leave them dead, each one opens a
/// short note saying where logging lives. If console-side forms arrive
/// later, this is the one place that changes.
class LogOnAndroidButton extends StatelessWidget {
  const LogOnAndroidButton({
    required this.label,
    this.variant = LogButton.tonal,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final LogButton variant;
  final IconData? icon;

  /// The empty state dims these until the farm has a plot to log against
  /// (DESIGN_SPEC §6).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    void onPressed() => showLogOnAndroidDialog(context);

    final button = switch (variant) {
      LogButton.tonal => ConsoleButton.tonal(
        label: label,
        icon: icon,
        onPressed: enabled ? onPressed : null,
      ),
      LogButton.filled => ConsoleButton.filled(
        label: label,
        icon: icon,
        onPressed: enabled ? onPressed : null,
      ),
    };

    return Opacity(opacity: enabled ? 1 : 0.45, child: button);
  }
}

/// Opens the note on its own, for the worker rail's quick-log tiles.
Future<void> showLogOnAndroidDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _LogOnAndroidDialog(),
  );
}

class _LogOnAndroidDialog extends StatelessWidget {
  const _LogOnAndroidDialog();

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return AlertDialog(
      icon: Icon(Icons.phone_android, color: console.onSurface2),
      title: const Text('Logging happens on Android'),
      titleTextStyle: AppTypography.cardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      content: Text(
        'Activities, inputs, harvests and sales are logged in the Shamba+ '
        'app, so they can be recorded in the field with no signal. They '
        'appear here as soon as the phone syncs.',
        style: AppTypography.bodyDense.copyWith(
          color: console.onSurface2,
          height: 1.5,
        ),
      ),
      actions: [
        ConsoleButton.filled(
          label: 'Got it',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
