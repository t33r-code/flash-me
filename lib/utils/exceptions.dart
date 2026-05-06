// Unified exception type for all app-level errors.
// Wraps Firebase/service errors into a consistent shape for the UI.
class AppException implements Exception {
  final String message;
  final String? code; // optional error code, e.g. 'not-found', 'permission-denied'

  const AppException(this.message, {this.code});

  @override
  String toString() => code != null ? '[$code] $message' : message;
}
