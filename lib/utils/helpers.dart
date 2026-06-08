import 'package:flutter/material.dart';

class AppLogger {
  static void info(String message) {
    debugPrint('ℹ️ INFO: $message');
  }

  static void debug(String message) {
    debugPrint('🐛 DEBUG: $message');
  }

  static void warning(String message) {
    debugPrint('⚠️ WARNING: $message');
  }

  static void error(String message, [StackTrace? stackTrace]) {
    debugPrint('❌ ERROR: $message');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void success(String message) {
    debugPrint('✅ SUCCESS: $message');
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
