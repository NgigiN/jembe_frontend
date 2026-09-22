// lib/features/web_console/presentation/utils/csv_download_stub.dart
//
// No-op stand-in selected by csv_download.dart's conditional export whenever
// `dart:js_interop` is NOT available — the mobile app build/analyze (which
// parses every file under lib/, not just web/**), and critically `flutter
// test`'s default VM platform, which cannot compile `dart:js_interop` /
// `package:web` at all (confirmed empirically: the CFE errors with
// "Dart library 'dart:js_interop' is not available on this platform" when a
// widget test transitively imports the real implementation). WebReportsPage
// is only ever reached from lib/main_web.dart (the web entry point), so this
// stub's body never runs outside a VM test — it exists purely so non-web
// compile targets can resolve the `downloadCsv` symbol.
void downloadCsv(String filename, String csvContent) {}
