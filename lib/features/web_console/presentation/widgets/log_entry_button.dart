import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/log_entry_dialog.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_log_scope.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:flutter/material.dart';

/// Which weight the button carries in the header row.
enum LogButton { tonal, filled, outlined }

/// Opens the form for [kind] and reports the result.
///
/// Where a [ConsoleLogScope] is installed — which is everywhere inside the
/// shell — this writes straight to the server. Without one (the preview
/// harness, widget tests) it falls back to the note about the Android app,
/// so the same widget renders in both places.
Future<void> logEntry(BuildContext context, LogEntryKind kind) async {
  final scope = ConsoleLogScope.of(context);
  if (scope == null) {
    await showLogOnAndroidDialog(context);
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final created = await showLogEntryDialog(
    context,
    kind: kind,
    service: scope.service,
  );
  if (created ?? false) {
    scope.onLogged();
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(AppSnackBar.success(context, _confirmation(kind)));
  }
}

String _confirmation(LogEntryKind kind) => switch (kind) {
  LogEntryKind.activity => 'Activity logged.',
  LogEntryKind.input => 'Input logged.',
  LogEntryKind.revenue => 'Sale logged.',
  LogEntryKind.harvest => 'Harvest logged.',
  LogEntryKind.herdActivity => 'Herd event logged.',
};

/// A "Log …" header action.
class LogEntryButton extends StatelessWidget {
  const LogEntryButton({
    required this.label,
    required this.kind,
    this.variant = LogButton.tonal,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final LogEntryKind kind;
  final LogButton variant;
  final IconData? icon;

  /// The first-run screen dims these until the farm has something to log
  /// against (DESIGN_SPEC §6).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    void onPressed() => logEntry(context, kind);

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
      LogButton.outlined => ConsoleButton.outlined(
        label: label,
        icon: icon,
        onPressed: enabled ? onPressed : null,
      ),
    };

    return Opacity(opacity: enabled ? 1 : 0.45, child: button);
  }
}

/// The fallback when there is no write path in scope — and the honest
/// answer for anything the console still cannot create.
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
      title: const Text('Log this on Android'),
      titleTextStyle: AppTypography.cardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      content: Text(
        'This one is logged in the Shamba+ app, so it can be recorded in '
        'the field with no signal. It appears here as soon as the phone '
        'syncs.',
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
