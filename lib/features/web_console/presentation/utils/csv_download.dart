// lib/features/web_console/presentation/utils/csv_download.dart
//
// Browser file-download helper for the web console (Task 15). Only ever
// imported from web-only pages (e.g. WebReportsPage), but the mobile build's
// `flutter analyze` still parses every file under lib/ (only web/** is
// excluded — see analysis_options.yaml), so this must stay analyzer-clean on
// every platform, not just web.
//
// API choice — verified empirically, not assumed (spec Task 15 Step 2):
// `dart:html`'s `AnchorElement`-based download trigger reports as deprecated
// under this SDK (`flutter analyze` flags `deprecated_member_use` +
// `avoid_web_libraries_in_flutter`, the latter a very_good_analysis lint
// specifically warning against web-only libraries in a Flutter app). The
// supported replacement is `package:web` + `dart:js_interop`
// (`web.Blob`, `web.URL.createObjectURL`, `web.HTMLAnchorElement`), which
// analyzes with zero issues — see csv_download_web.dart.
//
// Conditional export, not a plain import — a second, harder constraint than
// the analyzer lint: `dart:js_interop` (and so `package:web`) is not
// available to the VM compile target at all. `flutter test`'s default
// platform compiles via the VM, and the CFE hard-errors
// ("Dart library 'dart:js_interop' is not available on this platform") the
// instant any file it compiles transitively imports it — a `kIsWeb` runtime
// guard cannot help here since the failure is a compile-time one, before any
// code runs. Exporting conditionally on `dart.library.js_interop` (true only
// for real web compile targets: dart2js/dartdevc/dart2wasm) makes
// `flutter test`, `flutter analyze` (mobile), and `flutter build web` each
// resolve `downloadCsv` to the right implementation.
export 'csv_download_stub.dart'
    if (dart.library.js_interop) 'csv_download_web.dart';
