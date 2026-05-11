import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// Triggers a browser file-save by creating a temporary object URL and
// clicking a hidden anchor element with the download attribute.
void triggerBrowserDownload(Uint8List bytes, String filename) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
