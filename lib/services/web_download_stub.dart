import 'dart:typed_data';

// No-op stub for non-web platforms. The kIsWeb guard in ExportService means
// this function is never actually called outside a web build.
void triggerBrowserDownload(Uint8List bytes, String filename) {
  throw UnsupportedError('Not a web platform');
}
