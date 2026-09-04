/// Compares two dotted numeric version strings.
///
/// Build metadata after a `+` (e.g. the `+6` in `1.0.0+6`) is dropped before
/// comparison, and each of the three numeric parts is compared in
/// major/minor/patch order. Missing or non-numeric parts are treated as `0`.
///
/// Returns `-1` when [a] is older than [b], `0` when equal, `1` when newer.
int compareSemver(String a, String b) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

/// Whether [current] is strictly below [min] (i.e. an upgrade is required).
bool isBelow(String current, String min) => compareSemver(current, min) < 0;

/// What kind of upgrade prompt (if any) a `/meta` response calls for.
enum UpgradeRequirement {
  /// The client is current enough; show nothing.
  none,

  /// A newer version exists but the client still works; advisory prompt.
  optional,

  /// The client is below the minimum supported version; blocking prompt.
  forced,
}

/// Decides, from a parsed `/meta` payload, whether to prompt for an upgrade.
///
/// [meta] is the decoded JSON body (expected to be a `Map` with
/// `min_supported_version` / `latest_version` string fields) and [current] is
/// the running app version. Anything malformed - a non-map, a missing field,
/// an empty/unparseable version - degrades to [UpgradeRequirement.none] so a
/// garbage response never surprises the user with a dialog.
UpgradeRequirement decideUpgrade(dynamic meta, String current) {
  if (meta is! Map) return UpgradeRequirement.none;
  final min = meta['min_supported_version']?.toString() ?? '';
  final latest = meta['latest_version']?.toString() ?? '';
  if (min.isNotEmpty && isBelow(current, min)) {
    return UpgradeRequirement.forced;
  }
  if (latest.isNotEmpty && isBelow(current, latest)) {
    return UpgradeRequirement.optional;
  }
  return UpgradeRequirement.none;
}
