// lib/core/di/service_locator.dart
//
// The app's single global GetIt instance, split out of
// injection_container.dart (web-console Task 15.6) so a consumer that only
// needs `sl<T>()` calls doesn't have to import injection_container.dart's
// own registrations, several of which (app_database.dart, sync_engine.dart)
// are fatal to a web compile target. Zero behavior change:
// injection_container.dart re-exports this file, so every existing
// `import 'injection_container.dart'` consumer keeps resolving `sl`
// exactly as before, and it is still the SAME GetIt.instance singleton
// this file's own registrations populate.
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;
