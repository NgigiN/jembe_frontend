/// Runtime dark-ship / rollback switch for the offline-first (local-first +
/// outbox) data path.
///
/// A plain mutable static is intentional for this pilot: it lets the app —
/// or a test — flip the flag at runtime with no DI plumbing. While
/// [enabled] is `false` (the default), every repository wired to this flag
/// MUST behave byte-for-byte like the pre-offline live-HTTP implementation
/// (rule zero for this rollout). Flip it to `true` only once the offline
/// pipeline (local datasource, outbox, sync engine) is trusted in
/// production; flip it back to `false` to roll back instantly.
///
/// Tests that flip this flag on must reset it to `false` in `tearDown` so
/// the flag never leaks between tests.
class OfflineConfig {
  OfflineConfig._();

  static bool enabled = false;
}
