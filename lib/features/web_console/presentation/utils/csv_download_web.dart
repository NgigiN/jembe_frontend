// lib/features/web_console/presentation/utils/csv_download_web.dart
//
// Real browser-download implementation, selected by csv_download.dart's
// conditional export whenever `dart:js_interop` is available (i.e. compiling
// for a real web target: dart2js/dartdevc/dart2wasm). Never imported
// directly — always go through csv_download.dart.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [csvContent] as a file named [filename].
void downloadCsv(String filename, String csvContent) {
  final blob = web.Blob(
    <web.BlobPart>[csvContent.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}
