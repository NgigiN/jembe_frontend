// lib/features/auth/presentation/widgets/google_sign_in_button.dart
//
// GIS requires its OWN rendered button widget for web sign-in (confirmed:
// authenticate() unconditionally throws UnimplementedError on web — see
// package:google_sign_in_web's own source/README). That plugin internally
// imports dart:js_interop/package:web, unavailable to flutter test's VM
// target and to mobile's flutter analyze parse pass — same class of
// problem Task 15's csv_download.dart already solved. Conditional export,
// same pattern.
export 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart';
