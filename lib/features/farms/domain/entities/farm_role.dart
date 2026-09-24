import 'package:farm_tracker/core/logging/app_logger.dart';

/// Mirrors the backend's three fixed roles
/// (`internal/models/farms/farm_member.go:10-12`).
enum FarmRole {
  owner,
  manager,
  worker;

  /// Parses the backend's wire string. Falls back to [FarmRole.worker]
  /// (least privilege) on anything unrecognized, rather than throwing —
  /// a malformed/future role string must never crash the app; it should
  /// just gate the UI down to the safest role.
  static FarmRole fromWire(String value) {
    switch (value) {
      case 'owner':
        return FarmRole.owner;
      case 'manager':
        return FarmRole.manager;
      case 'worker':
        return FarmRole.worker;
      default:
        appLogger.warning(
          LogCategory.general,
          'Unrecognized farm role "$value" from the server; defaulting to worker',
        );
        return FarmRole.worker;
    }
  }

  /// The wire string for this role — used by request bodies (invite,
  /// member-role-change) that send a role back to the server.
  String get wireValue => switch (this) {
    FarmRole.owner => 'owner',
    FarmRole.manager => 'manager',
    FarmRole.worker => 'worker',
  };

  bool get isStaff => this == FarmRole.owner || this == FarmRole.manager;
}
