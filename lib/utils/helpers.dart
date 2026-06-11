import 'package:flutter/material.dart';

// Ring buffer of the last 150 log lines; populated by AppLogger.
// The feedback dialog reads this when the user checks "Include app logs".
class LogBuffer {
  static final LogBuffer _instance = LogBuffer._internal();
  factory LogBuffer() => _instance;
  LogBuffer._internal();

  static const _maxLines = 150;
  final _lines = <String>[];

  void add(String line) {
    _lines.add(line);
    if (_lines.length > _maxLines) _lines.removeAt(0);
  }

  // Returns all buffered lines joined by newlines.
  String dump() => _lines.join('\n');
}

class AppLogger {
  static final _buffer = LogBuffer();

  static void info(String message) {
    const prefix = 'ℹ️ INFO';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }

  static void debug(String message) {
    const prefix = '🐛 DEBUG';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }

  static void warning(String message) {
    const prefix = '⚠️ WARNING';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }

  static void error(String message, [StackTrace? stackTrace]) {
    const prefix = '❌ ERROR';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void success(String message) {
    const prefix = '✅ SUCCESS';
    debugPrint('$prefix: $message');
    _buffer.add('$prefix: $message');
  }
}

class AppHelpers {
  // Normalise a raw tag string to its canonical Firestore document ID form:
  // trim whitespace, lowercase, collapse runs of whitespace to a single hyphen.
  // Returns an empty string if the result is empty (caller should discard it).
  static String normalizeTag(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  }

  // Diff two tag lists and return which tags were added and which removed.
  // Both sides are normalised before comparison so casing differences are
  // treated as the same tag.  Returns (toUpsert, toDecrement) where:
  //   toUpsert   — normalised names present in [newTags] but not [oldTags]
  //   toDecrement — normalised names present in [oldTags] but not [newTags]
  static (List<String>, List<String>) diffTags(
      List<String> oldTags, List<String> newTags) {
    final oldNorm =
        oldTags.map(normalizeTag).where((t) => t.isNotEmpty).toSet();
    final newNorm =
        newTags.map(normalizeTag).where((t) => t.isNotEmpty).toSet();
    return (
      newNorm.difference(oldNorm).toList(),
      oldNorm.difference(newNorm).toList(),
    );
  }

  // Log a non-fatal tag write failure. Called from fire-and-forget upsert/
  // decrement paths where the error must not propagate to the caller.
  static void logTagError(String operation, String tag, Object error) {
    AppLogger.warning('Tag $operation failed for "$tag": $error');
  }
}

class AppValidators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Name is required';
    }
    if (name.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }
}
