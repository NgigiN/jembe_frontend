import 'dart:async';

import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Prompts the user to update the app from the Play Store.
///
/// When `forced` is true the dialog is non-dismissible: the barrier is inert,
/// there is no "Later" action, and a system back gesture cannot pop it (the
/// client is below the backend's minimum supported version). When `forced` is
/// false it is an advisory "update available" prompt the user can dismiss.
class UpgradeDialog {
  UpgradeDialog._();

  // Android package id for the Play Store deep-link.
  static const _packageId = 'com.samtama.shamba';
  static final Uri _marketUri = Uri.parse('market://details?id=$_packageId');
  static final Uri _webUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$_packageId',
  );

  static Future<void> show(BuildContext context, {required bool forced}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !forced,
      builder: (_) => _UpgradeDialog(forced: forced),
    );
  }

  /// Opens the Play Store. Tries the native `market://` scheme first and falls
  /// back to the https store URL. Needs no BuildContext, so it is safe to call
  /// across an async gap. Best-effort: any failure is swallowed and logged.
  static Future<void> launchStore() async {
    try {
      if (await canLaunchUrl(_marketUri)) {
        await launchUrl(_marketUri);
        return;
      }
    } catch (_) {
      // Fall through to the web URL below.
    }
    try {
      await launchUrl(_webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      appLogger.warning(
        LogCategory.general,
        'Could not open the Play Store for an app upgrade: $e',
      );
    }
  }
}

class _UpgradeDialog extends StatelessWidget {
  const _UpgradeDialog({required this.forced});

  final bool forced;

  @override
  Widget build(BuildContext context) {
    // canPop:false also blocks the system back gesture when the update is
    // forced, so the prompt cannot be escaped without updating.
    return PopScope(
      canPop: !forced,
      child: AlertDialog(
        title: Text(forced ? 'Update required' : 'Update available'),
        content: Text(
          forced
              ? 'This version of Shamba+ is no longer supported. Please update '
                    'to continue.'
              : 'A newer version of Shamba+ is available with the latest '
                    'improvements.',
        ),
        actions: [
          if (!forced)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: forced
                ? UpgradeDialog.launchStore
                : () {
                    // Optional prompt only: dismiss on tap so the user
                    // doesn't return from the Play Store to a still-open
                    // advisory. The forced dialog must stay non-dismissible,
                    // so this pop is intentionally scoped to !forced.
                    unawaited(UpgradeDialog.launchStore());
                    Navigator.of(context).pop();
                  },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
