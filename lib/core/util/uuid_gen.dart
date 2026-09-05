import 'package:uuid/uuid.dart';

/// Thin, injectable wrapper around [Uuid] so callers needing a fresh
/// client-side identifier (e.g. `LandModel.create`) can be given a
/// deterministic fake in tests instead of a real random UUID.
class UuidGen {
  const UuidGen();

  /// Generates a new random (v4) UUID string.
  String v4() => const Uuid().v4();
}
