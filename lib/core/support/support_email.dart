import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where support mail goes. Not configurable: a wrong-but-plausible address
/// here loses a user's report silently, so it is pinned in one place and
/// asserted by a test.
const String supportEmailAddress = 'support@shambaplus.samtama.lol';

/// Builds the `mailto:` link behind Settings -> Contact Support.
///
/// The build number is the point of the prefill. A report that says "the list
/// is empty" is unanswerable without knowing which binary is on the phone —
/// the offline mirror, the author-name attachment and the client_uuid backfill
/// all changed what the same screen shows, so the first question a reply has
/// to ask is "which build?". Putting it in the subject means it is visible in
/// the inbox list without opening the mail.
///
/// Pure, and kept out of the widget so the encoding is unit-testable: query
/// parameters are percent-encoded by hand rather than via [Uri.queryParameters],
/// which spells a space `+` and leaves mail clients showing literal pluses in
/// the body.
Uri supportMailtoUri({
  required String version,
  required String buildNumber,
  required String platform,
}) {
  final subject = 'Shamba+ support - $version ($buildNumber)';
  final body =
      'Tell us what happened:\n'
      '\n'
      '\n'
      '---\n'
      'App $version (build $buildNumber) - $platform\n'
      'Please keep the line above; it tells us which build you are on.';
  return Uri.parse(
    'mailto:$supportEmailAddress'
    '?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}

/// Opens the device mail app at [supportMailtoUri] for the running build.
///
/// Returns false when no mail app could be opened, so the caller can surface
/// the address instead of leaving a tap that appears to do nothing — a phone
/// with no mail client configured is the common case here, not an edge one.
Future<bool> launchSupportEmail() async {
  final uri = supportMailtoUri(
    version: AppConfig.appVersion,
    buildNumber: AppConfig.appBuildNumber,
    platform: defaultTargetPlatform.name,
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    appLogger.warning(
      LogCategory.general,
      'Could not open a mail app for a support request: $e',
    );
    return false;
  }
}
